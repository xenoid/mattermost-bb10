#include "MmClient.hpp"

#include <bb/cascades/Application>
#include <bb/cascades/QmlDocument>
#include <bb/cascades/AbstractPane>
#include <bb/cascades/Page>
#include <bb/cascades/Label>
#include <bb/cascades/Container>

#include <bb/Application>
#include <QDebug>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <process.h>
#include <sys/slog2.h>
#include <QTimer>
#include <QtDeclarative/qdeclarative.h>
#include <QDeclarativeError>
#include <QLocale>
#include <QTextCodec>
#include <QTranslator>

using namespace bb::cascades;

static void bootNote(const char *text)
{
    fprintf(stderr, "%s\n", text);
    fflush(stderr);
    slog2_buffer_set_config_t cfg;
    slog2_buffer_t buf = 0;
    memset(&cfg, 0, sizeof(cfg));
    cfg.num_buffers = 1;
    cfg.buffer_set_name = "mmboot";
    cfg.verbosity_level = SLOG2_INFO;
    cfg.buffer_config[0].buffer_name = "boot";
    cfg.buffer_config[0].num_pages = 1;
    if (slog2_register(&cfg, &buf, 0) == 0)
        slog2c(buf, 0, SLOG2_INFO, text);
}

static bool hubBinary(int argc, char **argv)
{
    char cmd[128];
    char exe[160];
    char proc[48];
    int fd;
    memset(cmd, 0, sizeof(cmd));
    memset(exe, 0, sizeof(exe));
    _cmdname(cmd);
    fd = open("/proc/self/exefile", O_RDONLY);
    if (fd < 0) {
        snprintf(proc, sizeof(proc), "/proc/%d/exefile", getpid());
        fd = open(proc, O_RDONLY);
    }
    if (fd >= 0) {
        read(fd, exe, sizeof(exe) - 1);
        close(fd);
    }
    char line[300];
    snprintf(line, sizeof(line), "mm-boot cmd=%s exe=%s", cmd, exe);
    bootNote(line);
    if (strstr(cmd, "MattermostHub") || strstr(exe, "MattermostHub"))
        return true;
    for (int i = 0; i < argc; ++i) {
        if (argv && argv[i] && strstr(argv[i], "MattermostHub"))
            return true;
    }
    return false;
}

Q_DECL_EXPORT int main(int argc, char **argv)
{
    QTextCodec *utf8 = QTextCodec::codecForName("UTF-8");
    QTextCodec::setCodecForLocale(utf8);
    QTextCodec::setCodecForCStrings(utf8);
    QTextCodec::setCodecForTr(utf8);

    // Der Hub-Eintritt ist Qnx/Elf. bb::Application integriert Qt ohne Fenster.
    if (hubBinary(argc, argv)) {
        bb::Application app(argc, argv);
        MmClient::deferUntilLoop();
        MmClient *client = new MmClient(&app);
        QTimer::singleShot(0, client, SLOT(bootHeadless()));
        return app.exec();
    }

    Application app(argc, argv);

    QTranslator translator;
    const QString locale = QLocale().name();
    if (translator.load("Mattermost_" + locale, "app/native/qm"))
        app.installTranslator(&translator);

    qmlRegisterType<QTimer>("bb", 1, 0, "QTimer");

    MmClient *client = new MmClient(&app);

    QmlDocument *qml = QmlDocument::create("asset:///main.qml").parent(&app);
    if (qml->hasErrors()) {
        const QList<QDeclarativeError> errors = qml->errors();
        QString text;
        for (int i = 0; i < errors.size(); ++i) {
            qWarning("%s", qPrintable(errors.at(i).toString()));
            text += errors.at(i).toString() + "\n";
        }
        // Statt schwarzem Bild den Fehler anzeigen.
        Label *label = Label::create(text).multiline(true);
        Application::instance()->setScene(Page::create().content(Container::create().add(label)));
    } else {
        QObject::connect(&app, SIGNAL(thumbnail()), client, SLOT(onBackground()));
        QObject::connect(&app, SIGNAL(invisible()), client, SLOT(onBackground()));
        QObject::connect(&app, SIGNAL(asleep()), client, SLOT(onBackground()));
        QObject::connect(&app, SIGNAL(fullscreen()), client, SLOT(onForeground()));
        QObject::connect(&app, SIGNAL(awake()), client, SLOT(onForeground()));
        qml->setContextProperty("_mm", client);
        AbstractPane *root = qml->createRootObject<AbstractPane>();
        if (root) {
            Application::instance()->setScene(root);
        } else {
            QString text("Oberfl\xC3\xA4che konnte nicht erzeugt werden\n");
            const QList<QDeclarativeError> errors = qml->errors();
            for (int i = 0; i < errors.size(); ++i)
                text += errors.at(i).toString() + "\n";
            Label *label = Label::create(QString::fromUtf8(text.toUtf8().constData())).multiline(true);
            Application::instance()->setScene(Page::create().content(Container::create().add(label)));
        }
    }

    return Application::exec();
}
