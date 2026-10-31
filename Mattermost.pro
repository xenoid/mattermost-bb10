APP_NAME = Mattermost

CONFIG += qt warn_on device cascades10

QT += network sql

LIBS += -lbb -lbbdata -lbbsystem -lbbplatform -lslog2 -lssl -lcrypto

# Der Hub ist ein echtes ELF-Programm. Eine .so lässt sich als Qnx/Elf nicht starten.
hub.target = o.le-v7/MattermostHub
hub.depends = \$(OBJECTS)
hub.commands = $(LINK) -lang-c++ -Wl,-rpath-link,$(QNX_TARGET)/armle-v7/usr/lib/qt4/lib -Wl,-z,relro -Wl,-z,now -o o.le-v7/MattermostHub $(OBJECTS) $(LIBS) -lQtXml && ntoarm-strip o.le-v7/MattermostHub
QMAKE_EXTRA_TARGETS += hub
POST_TARGETDEPS += o.le-v7/MattermostHub

CODECFORTR = UTF-8
TRANSLATIONS += translations/Mattermost_de.ts \
    translations/Mattermost_en.ts

include(config.pri)
INCLUDEPATH += $$[QT_INSTALL_HEADERS]/QtGui
