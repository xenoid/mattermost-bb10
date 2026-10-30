# mattermost-bb10

A Mattermost client for BlackBerry 10. It is built for the Classic, the square 720 screen, and a world in which BlackBerry no longer signs applications.

On the phone the app is named **Mattermost**. The package id is `com.hollweck.mattermost`. This repository is the source. Version in the tree: **1.0.0**, build **58**.

<p>
<img src="icon.png" width="96" alt="App icon">
</p>

The client talks to any Mattermost server you can reach over HTTPS, with the API v4. Posts, names, and emoji are UTF-8, in whatever language the team writes. The buttons and dialogs on the phone are German.

## Languages

The server content is shown as stored. A German team, an English team, and a mixed team all come through the same client. Emoji are drawn from the color font on the device, without flags, skin tones, or ZWJ sequences.

The interface language is German. At startup the app reads the phone locale and, if a file `app/native/qm/Mattermost_<locale>.qm` is present, installs that catalog. No catalog is shipped, and the strings in QML and C++ are written out in German rather than marked for translation. A second language is a catalog plus `qsTr`, not a switch that already exists.

## What is in the client

Three states, from a rooted Classic SQC100-1 on OS 10.3.3:

| State | Meaning |
| --- | --- |
| **Phone** | Used on that Classic with the unsigned release package. |
| **Source** | Implemented in this tree. Not yet shown end to end on the device. |
| **Absent** | Not part of this client. |

| Capability | State |
| --- | --- |
| Sign in with server, name, and password | Phone |
| Keep the session across an update | Phone |
| Ask for an MFA code when the server demands one | Source |
| Choose a team when the account has more than one | Source |
| Channel list | Phone |
| Public, private, and direct channels, with unread and mention marks | Source |
| Hide the channel subtitle | Source |
| Open a channel and read posts | Phone |
| Load older and newer posts | Source |
| Send a message | Phone |
| Keep an unsent message until the phone is online again | Source |
| Search and open the channel at the hit | Source |
| Threads and replies | Source |
| Reactions | Source |
| Bold, italic, code, quote, and links | Source |
| Emoji panel | Source |
| Images and other attachments | Source |
| Upload a file under its original name | Source |
| A row in the BlackBerry Hub per channel, without the message text | Source |
| Wake a headless process every six minutes | Phone |
| Finish that headless sync and exit | Absent on 1.0.0.56. Build 58 moves the heavy startup onto the event loop. The next timer fire is the test. |
| TLS checked against a current Mozilla CA bundle | Phone, against a normal public certificate |
| Refuse a certificate that is not in that bundle | Source |
| Settings for account, channel preview, and a protocol log | Phone |
| Another interface language | Absent |
| Edit, delete, pins, slash commands | Absent |
| Calls, screen share, boards, playbooks | Absent |
| More than one account at a time | Absent |

The headless row is the one that still fails in the way that matters. The timer is registered and the navigator starts `MattermostHub`. On 1.0.0.56 that process never connected to app control and was stopped after six seconds, so the hub did not sync. Build 58 is on the phone to change that. Until a later log shows `mm-hub start` and `mm-hub done`, the hub does not count as done.

Markdown is drawn with the small HTML subset Cascades accepts: `b`, `i`, `a`, `font color`, `br`. A `font face` makes Cascades drop the whole label, so code is a color, not a monospace face.

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

Translations start by marking the German strings and adding a catalog. The loader is already in `src/main.cpp`.

Keep the diff small, and keep secrets out of commits. A token from a test server does not belong in an issue.

## License

No license file yet. Until there is one, the usual open-source grants are not in force. Building it for your own Classic is what this tree is for.

## Support

The app is free. There is no public donation page yet, so this file does not point at a guessed PayPal, Ko-fi, or GitHub Sponsors account. When a real link exists, it replaces this paragraph.
