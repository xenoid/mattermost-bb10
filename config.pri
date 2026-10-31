BASEDIR = $$quote($$_PRO_FILE_PWD_)

INCLUDEPATH += $$BASEDIR/src

SOURCES += $$BASEDIR/src/main.cpp \
    $$BASEDIR/src/MmClient.cpp \
    $$BASEDIR/src/ImageStore.cpp \
    $$BASEDIR/src/Emoji.cpp \
    $$BASEDIR/src/LocalStore.cpp \
    $$BASEDIR/src/Markdown.cpp \
    $$BASEDIR/src/MmSocket.cpp

HEADERS += $$BASEDIR/src/MmClient.hpp \
    $$BASEDIR/src/ImageStore.hpp \
    $$BASEDIR/src/Emoji.hpp \
    $$BASEDIR/src/LocalStore.hpp \
    $$BASEDIR/src/Markdown.hpp \
    $$BASEDIR/src/MmSocket.hpp

OTHER_FILES += $$BASEDIR/bar-descriptor.xml \
    $$BASEDIR/assets/main.qml \
    $$BASEDIR/icon.png
