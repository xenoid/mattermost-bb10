# Mattermost for BlackBerry 10

<p>
<img src="icon.png" width="96" alt="App icon">
</p>

An unofficial [Mattermost](https://mattermost.com) client for the BlackBerry Classic (BlackBerry 10). It is written in C++ with Qt 4.8 and Cascades, and it talks to any Mattermost server over HTTPS with API v4.

Not affiliated with Mattermost, Inc. or BlackBerry.

- **Package:** `com.hollweck.mattermost`, shown on the phone as **Mattermost**
- **Version:** 1.0.0, build 133
- **Source:** [github.com/xenoid/mattermost-bb10](https://github.com/xenoid/mattermost-bb10)

## Status

The app is usable for daily work: sign in, read, send, reply in threads, search, attach files, and get hub alerts. It works offline for sending, which queues messages until the phone is back online.

The goal is the feature set of the official Android app, minus voice and video calls. [PARITY.md](PARITY.md) lists every feature and its state. At the time of writing, 28 of 93 tracked features are done, 16 are partly done, and 49 are open.

## Features

- Sign in with server URL, username or email, and password, including MFA codes
- Keep the session; log out from Settings
- Team picker and channel list with public, private, direct, unread, and mention filters
- Read posts with paging in both directions, and open a permalink or search hit
- Send, reply in threads, edit and delete your own posts, pin and save posts
- Slash command suggestions while typing `/`
- Typing indicator over a websocket
- Emoji panel with the server's custom emoji
- Upload files under their original names; open images and other files
- Offline outbox that sends queued posts when the connection returns
- Hub: a background process that refreshes every six minutes and raises alerts
- Settings: refresh, team, preview, 24-hour clock, images, hub alerts, mentions only, protocol log
- English and German interface

## Requirements

- BlackBerry Classic (720 × 720) on BlackBerry 10 OS 10.3
- A Mattermost server with API v4, reachable over HTTPS
- To install an unsigned package, a rooted device (see [Install](#install))
- To build from source, the BlackBerry NDK 10.3.1

## Install

BlackBerry no longer signs third-party applications, so the package is unsigned.

- **Rooted device:** install the BAR with `sud_install_package_2`.
- **Developer access:** the package can also be pushed over SSH and installed as root. The helper script for this is not part of the repository. The device password, if your setup needs one, belongs in an environment variable and never in a script.
- **Unrooted device without developer mode:** the installer stops with error 881. This project does not offer a way around that.

## Build from source

Build with the NDK 10.3.1 environment. The compiler is the one in that NDK: C++03, Qt 4.8, Cascades. Do not use `auto`, lambdas, or `QJsonDocument`.

```sh
source /path/to/bbndk/bbndk-env_10_3_1_995.sh
qmake -spec blackberry-armv7le-qcc Mattermost.pro
make
blackberry-nativepackager -package -configuration Device-Release Mattermost-release.bar bar-descriptor.xml
```

`QNX_TARGET` must be set before `make`, because the hub binary links against it. The environment script sets it.

### TLS shim

Qt 4.8 asks for `SSLv23_client_method`, and the servers this client targets require TLS 1.2. The tree ships a shim: `lib/libssl.so.2` forwards to `lib/libsslmm.so` and changes only that one call. To rebuild it from the device's own `libssl.so.2`, run:

```sh
tools/ssl-shim.sh /path/to/device/libssl.so.2
```

The script needs `qcc` from the NDK on the path.

## Project layout

| Path | Role |
| --- | --- |
| `src/MmClient.*` | REST client and app state. Its 40 `Q_INVOKABLE` methods are the API the QML pages call. |
| `src/MmSocket.*` | Websocket for the typing indicator |
| `src/LocalStore.*` | Local cache and the offline outbox |
| `src/ImageStore.*` | Image and file cache. It also paints a few icons. |
| `src/Markdown.*` | Converts Markdown to the tags the Cascades text reader understands |
| `src/Emoji.*` | Emoji catalog for the panel |
| `src/main.cpp` | Entry point for the app |
| `assets/*.qml` | Pages: main (channels), thread, search, settings, attachments, image viewer |
| `translations/` | `Mattermost_en.ts` and `Mattermost_de.ts`, compiled to `.qm` and packed into the BAR |
| `o.le-v7/`, `*.bar`, `Makefile` | Build output and generated files. Not in git. |

The hub, `MattermostHub`, is a second executable built from the same objects. The system starts it on a timer.

## Design

The Classic screen is 720 by 720 at 294 dpi. Colours:

| Use | Colour |
| --- | --- |
| Accent | `#1c58d9` (pressed `#1544a8`) |
| Secondary text | `#6b747d` |
| Private channels | `#b9822a` |
| Mentions | `#d6322e` |

The chat page hides the action bar. Back is a swipe from the left edge. Settings are the last row of the channel list.

## Known limitations

- **Markdown** shows bold, italic, code, quotes, and links. Lists, tables, and headings are plain text. Strikethrough keeps the words and drops the tildes.
- **Emoji** come from the phone font, which has no flags, skin tones, or ZWJ sequences. Server emoji are shown as pictures.
- **Reactions** work through a swipe, but the swipe has not been confirmed on the device since build 123.
- **Notifications** come from a poll every six minutes, not from push. BlackBerry 10 has no push service for this app.
- **Accounts:** one account and one server at a time.
- **Calls** are not built and are not planned.
- **Tests:** there are no automated tests yet. Changes are checked on a device.

## Contributing

1. Pick an open item in [PARITY.md](PARITY.md), or open an issue first for anything larger.
2. Keep the diff small, and follow the C++03 and Qt 4.8 limits above.
3. Test on a device, and say in the pull request what you tested.
4. Keep secrets out of commits. The `.gitignore` covers `*.conf`, `id_rsa*`, and `*.age`, but check `git status` before you commit. Do not paste tokens or session files into issues.

### Adding a language

Copy the English catalog, translate it, and compile it:

```sh
lupdate -codecfortr UTF-8 src/*.cpp src/*.hpp assets/*.qml -ts translations/Mattermost_fr.ts
# translate translations/Mattermost_fr.ts
lrelease translations/Mattermost_fr.ts
```

The `translations` asset in `bar-descriptor.xml` already packs every `Mattermost_*.qm`. The app picks the catalog from the phone locale, so `fr_FR` loads `Mattermost_fr`. English is the fallback.

## Security

- The server certificate is checked against the Mozilla CA bundle in `assets/cacert.pem`. Client certificates are not supported.
- The session token is stored in `QSettings` inside the app's sandbox.
- Report a security problem privately to the maintainer, not in a public issue.

## License

No license file yet. Until one is added, the usual open-source permissions do not apply. Building the app for your own Classic is what this tree is for.

## Support

The app is free. If it keeps a Classic in use, a tip helps:

[PayPal: paypal.me/lhollweck](https://www.paypal.com/paypalme/lhollweck)
