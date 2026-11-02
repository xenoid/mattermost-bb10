#include "MmClient.hpp"

#include <bb/cascades/Application>
#include <bb/cascades/QmlDocument>
#include <bb/cascades/AbstractPane>
#include <bb/cascades/Page>
#include <bb/cascades/Label>
#include <bb/cascades/Container>
#include <bb/cascades/ThemeSupport>
#include <bb/cascades/VisualStyle>

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
#include <QCoreApplication>
#include <QLocale>
#include <QStringList>
#include <QTextCodec>
#include <QTranslator>
#include <QSettings>

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
    QString lang = locale;
    const int underscore = locale.indexOf(QLatin1Char('_'));
    if (underscore > 0)
        lang = locale.left(underscore);
    const QStringList catalogs = QStringList()
        << ("Mattermost_" + locale)
        << ("Mattermost_" + lang)
        << QLatin1String("Mattermost_en");
    const QStringList dirs = QStringList()
        << QLatin1String("app/native/qm")
        << (QCoreApplication::applicationDirPath() + "/qm")
        << QLatin1String("qm");
    bool catalogLoaded = false;
    for (int c = 0; c < catalogs.size() && !catalogLoaded; ++c) {
        for (int d = 0; d < dirs.size(); ++d) {
            if (translator.load(catalogs.at(c), dirs.at(d))) {
                app.installTranslator(&translator);
                catalogLoaded = true;
                break;
            }
        }
    }

    qmlRegisterType<QTimer>("bb", 1, 0, "QTimer");

    MmClient *client = new MmClient(&app);

    // Dunkles Design: eigene Seiten mit dunkler Palette (tools/make-dark.py), Systemelemente dunkel.
    const bool dark = QSettings("hollweck", "mattermost").value("darkTheme", false).toBool();
    if (dark)
        app.themeSupport()->setVisualStyle(VisualStyle::Dark);
    QmlDocument *qml = QmlDocument::create(dark ? "asset:///dark/main.qml" : "asset:///main.qml").parent(&app);
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
            QString text = QCoreApplication::translate(
                "main", "Could not create the interface") + "\n";
            const QList<QDeclarativeError> errors = qml->errors();
            for (int i = 0; i < errors.size(); ++i)
                text += errors.at(i).toString() + "\n";
            Label *label = Label::create(QString::fromUtf8(text.toUtf8().constData())).multiline(true);
            Application::instance()->setScene(Page::create().content(Container::create().add(label)));
        }
    }

    return Application::exec();
}
