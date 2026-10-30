# mattermost-bb10

Nativer Mattermost-Client für BlackBerry 10, gebaut für das Classic. Auf dem Gerät heißt die App Mattermost, die Paketkennung ist `com.hollweck.mattermost`.

Die BlackBerry Signing Authority ist abgeschaltet. Das Paket bleibt unsigniert. Auf einem gerooteten Gerät geht die Installation über `sud_install_package_2`. Ohne Root scheitert das Sideload ohne Entwicklermodus an Fehler 881.

## Bau

NDK 10.3.1, die Umgebung muss `QNX_TARGET` setzen:

```sh
source /pfad/zum/ndk/bbndk/bbndk-env_10_3_1_995.sh
qmake -spec blackberry-armv7le-qcc Mattermost.pro
make
blackberry-nativepackager -package -configuration Device-Release Mattermost-release.bar bar-descriptor.xml
```

C++03, Qt 4.8, Cascades. Kein `QJsonDocument`.

## Nicht im Repo

BARs, `o.le-v7/`, das generierte `Makefile`, Sitzungsdaten, Passwörter und Tokens.
