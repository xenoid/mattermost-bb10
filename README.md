# mattermost-bb10

A Mattermost client for BlackBerry 10. It is built for the Classic, the square 720 screen, and a world in which BlackBerry no longer signs applications.

On the phone the app is named **Mattermost**. The package id is `com.hollweck.mattermost`. This repository is the source: [github.com/xenoid/mattermost-bb10](https://github.com/xenoid/mattermost-bb10). Version in the tree: **1.0.0**, build **127**.

<p>
<img src="icon.png" width="96" alt="App icon">
</p>

The client talks to any Mattermost server you can reach over HTTPS, with the API v4. Posts, names, and emoji are UTF-8, in whatever language the team writes. The buttons and dialogs follow the phone language: German and English ship with the app.

## Languages

Server text is shown as stored. A German team, an English team, and a mixed team all come through the same client. Dates and file sizes use the phone locale. Emoji are drawn from the color font on the device, without flags, skin tones, or ZWJ sequences.

The interface source strings are English (`qsTr` and `tr`). At startup the app loads `app/native/qm/Mattermost_<language>.qm`. A phone set to German (`de`, `de_DE`, `de_AT`, …) gets `Mattermost_de`. Every other language gets `Mattermost_en` until a catalog for that language exists. Both catalogs are in this tree, finished, and packed into the BAR.

## Toward the Android app

This list is the Mattermost Android client, scored by what this program already does. 19 rows are done, 2 are only part way, 12 are still missing.

| | |
| --- | --- |
| 🟢 | Done. Same job as on Android. |
| 🟡 | Started. Android does more, or this part does not finish. |
| 🔴 | Not built. |

| | |
| --- | --- |
| 🟢 | Sign in with server, name, and password |
| 🟢 | Keep the session |
| 🟢 | Ask for an MFA code |
| 🟢 | Pick a team |
| 🟢 | Channel list: public, private, direct, unread, mentions |
| 🟢 | Hide the channel subtitle |
| 🟢 | Read posts, including older and newer pages |
| 🟢 | Send a message |
| 🟢 | Send later when the phone is offline |
| 🟢 | Search and open the hit |
| 🟢 | Threads and replies |
| 🟡 | Reactions: swipe opens twelve names, up to eight chips, a tap toggles that one, a server emoji is its image |
| 🟢 | Open images and other files |
| 🟢 | Upload a file under its original name |
| 🟢 | Check the server certificate against a current CA bundle |
| 🟢 | Markdown: bold, italic, code, quote, link. A heading is bold. A list, a table, and a strike are readable text |
| 🟢 | Emoji panel, including the server's own emoji. Flags and skin tones are not in the phone font |
| 🟢 | A Hub row per channel. The body is the latest message when that post has text |
| 🟢 | Background refresh every six minutes |
| 🟢 | Settings: refresh, team, log out, preview, 24-hour clock, images, hub alerts, mentions only, protocol log |
| 🟡 | English and German. Further languages are a catalog |
| 🔴 | Edit and delete a message |
| 🔴 | Pin and save a post |
| 🔴 | Slash commands |
| 🔴 | Typing indicator |
| 🔴 | SSO |
| 🔴 | Notification settings per channel |
| 🔴 | Create a channel, show its members |
| 🔴 | Custom status |
| 🔴 | Calls and screen share |
| 🔴 | Boards and playbooks |
| 🔴 | More than one account |
| 🔴 | Dark theme |

Markdown uses the tags the Cascades text reader matches: `b`, `strong`, `i`, `em`, `u`, `a`, `br`. It has no `span` and no `font`. Code is underlined. A quote is an italic line with a bar. A heading is bold. A bullet or a number stays a line of text. A table is cells separated by a dot. A strike loses the tildes and keeps the words.

A reaction is a swipe, then one of twelve names. Choosing the same name again removes it. The row shows up to eight chips. Tapping a chip toggles that emoji. A server emoji is downloaded and shown as a picture. The phone font has no flags, skin tones, or the red heart, so `heart` is the sparkling one. Build 123 called the swipe through the post row. Whether that list opens has not been seen on a finger since then.

The emoji panel lists the phone font and, after the panel opens, the server's own emoji. A font glyph is inserted as the character. A server emoji is inserted as `:name:` and shown as its picture once that picture has arrived.

A Hub entry uses the channel name as the title. The body is the latest post, shortened, for up to eight channels that have something unread. A post with no text keeps the count.

## Install in 2026

The BlackBerry Signing Authority is gone. There is no store certificate to attach.

- A **rooted** Classic can install the unsigned BAR with `sud_install_package_2`.
- A Classic that is not rooted, and not in developer mode, stops at error **881**. Developer mode is not a substitute this project claims to ship.

This tree builds the unsigned device package:

```sh
source /path/to/bbndk/bbndk-env_10_3_1_995.sh
qmake -spec blackberry-armv7le-qcc Mattermost.pro
make
blackberry-nativepackager -package -configuration Device-Release Mattermost-release.bar bar-descriptor.xml
```

The NDK is 10.3.1. The compiler is the one in that NDK: C++03, Qt 4.8, Cascades. No `auto`, no lambdas, no `QJsonDocument`. `QNX_TARGET` has to be set before `make`, because the headless binary is linked against it.

The BAR, the `o.le-v7/` build tree, and the generated Makefile stay out of git. So do passwords, tokens, and the phone's session file.

## Design

The Classic is 720 by 720 at 294 dpi. The accent is `#1c58d9`, pressed `#1544a8`, secondary text `#6b747d`, private channels `#b9822a`, mentions `#d6322e`. The chat page hides the action bar. Back is a swipe from the left edge. Settings are the last row of the channel list.

## Contributing

Another interface language is a catalog. Copy the English file, translate it, and send it:

```sh
lupdate -codecfortr UTF-8 src/*.cpp src/*.hpp assets/*.qml -ts translations/Mattermost_fr.ts
# translate translations/Mattermost_fr.ts
lrelease translations/Mattermost_fr.ts
```

Add `<asset path="translations">qm</asset>` already covers every `Mattermost_*.qm` in that folder. The loader uses the language code in the phone locale (`fr` from `fr_FR`). English stays the fallback.

Keep the diff small, and keep secrets out of commits. A token from a test server does not belong in an issue.

## License

No license file yet. Until there is one, the usual open-source grants are not in force. Building it for your own Classic is what this tree is for.

## Support

The app is free. If it keeps a Classic in use, a tip helps:

[PayPal — paypal.me/lhollweck](https://www.paypal.com/paypalme/lhollweck)
