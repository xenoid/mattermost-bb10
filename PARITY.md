# Parity with the Android app

Goal: every user-facing feature of the official Mattermost Android app, except voice and video calls (including screen share). This file is the working list. When a row changes, change its status here and in the README summary.

Reference: Mattermost Mobile for Android, changelog read up to 2.45.1 (October 2026). Rows marked *to verify* come from secondary sources or from a partly read changelog. Check them against the app before building.

## Status

| Mark | Meaning |
| --- | --- |
| 🟢 | Done on the device |
| 🟡 | Started. The Android app does more, or the part does not finish |
| 🔴 | Not built |
| ⏸ | Out of scope by decision. Calls are not built |
| ⚪ | Not planned. The platform cannot do it, or the Android app does not have it |

The percentage counts 🟢, 🟡 and 🔴 rows only. ⏸ and ⚪ are not in the total.

## Accounts and sign-in

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Email or username with password | |
| 🟢 | Keep the session | Token in `QSettings` |
| 🟢 | MFA code | |
| 🟢 | Log out | |
| 🟢 | Choose a team | |
| 🟡 | Join or leave a team | Built: join an open team and leave the current one, both from Settings, ACCOUNT. Invites to private teams are missing. Not yet tested on the device |
| 🟡 | Several accounts or servers | Built: Settings, ACCOUNT, Accounts and servers keeps several signed-in accounts and switches between them; Add account opens the login for the next. Only the active account gets Hub alerts. Not yet tested on the device |
| 🟡 | Authentication secret on server entry | Built: optional field on the login page; sent as X-Mattermost-Preauth-Secret on every request (server 10.12+ behind a proxy). A proxy rejection shows a message. The websocket does not send it yet. Not yet tested on the device |
| 🟡 | Sign in with GitLab, Google or Entra ID (OAuth) | Built: the login page opens the server's mobile OAuth login (GitLab, Google, Office 365/Entra ID, OpenID) in the browser; the mmauth:// callback brings the token back into the app. The server must allow mmauth:// (default). Not yet tested on the device |
| 🟡 | SAML (Okta, OneLogin, ADFS) | Built: same browser flow with the server's SAML mobile login. Not yet tested on the device |
| 🔴 | Magic link for guests | Server v11.3 and later |
| 🟡 | Forgot-password link | Built: opens `/reset_password` of the server in the browser. Not yet tested on the device |
| 🟡 | AD/LDAP | The password login sends login_id, which the server also accepts for AD/LDAP accounts. Not tested: no LDAP server at hand |
| ⚪ | Sign in with Microsoft under Intune | MDM, iOS only in the docs |

## Teams and channels

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Channel list: public, private, direct, unread, mentions | |
| 🟢 | Hide the channel subtitle | |
| 🟡 | Create a channel | Built: Settings, MESSAGES, New channel. Public channels only. Not yet tested on the device |
| 🟡 | Show, add and remove members | Built: show members from the long-press menu, add by username, remove by tap and confirm. Only public and private channels. Device 2026-11-02: list opens after the fixes in 1.0.0.142 and 1.0.0.149; adding and removing not yet tested |
| 🟡 | Leave, archive, edit header and purpose | Built: leave, archive, edit header and purpose from the long-press menu. Device 2026-11-02: the menu entries never fired, because list items cannot reach outer ids; fixed in 1.0.0.149, header and purpose pages now open. Saving, leave and archive not yet tested |
| 🟡 | New direct message | Built: Settings, MESSAGES, enter a username. Group messages still missing. Not yet tested on the device |
| 🟡 | Admin-managed sidebar categories | Built: the channel list follows the server's sidebar categories (favourites, custom and admin-managed ones) in their order. Collapsing and moving channels are missing. Not yet tested on the device |
| 🟡 | Channel bookmarks | Built: read-only list from the channel long-press menu, a tap opens the link. Not yet tested on the device |
| 🟡 | Channel banners | Built: the banner text shows at the top of the channel. The banner colour from the server is not used. Not tested: no channel with a banner on the test server |
| 🟡 | Guest invitations | Built: channel long-press menu, Invite guest by email for that channel. Needs guest accounts on the server. Not yet tested on the device |
| 🔴 | Shared-channel system messages | Low priority |

## Messages

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Read with paging, older and newer | |
| 🟢 | Send | |
| 🟢 | Send later when offline | `LocalStore` outbox |
| 🟢 | Reply threads | |
| 🟢 | Edit and delete own message | |
| 🟢 | Pin and save | |
| 🟢 | Open a permalink or search hit | |
| 🟢 | Slash command suggestions | |
| 🟢 | Typing indicator over websocket | |
| 🟡 | Markdown | Bold, italic, code, quote, link. Lists, tables and headings are text only |
| 🟡 | Reactions | Swipe, twelve names, chips. Swipe not confirmed on the device since build 123 |
| 🟡 | Emoji panel with server emoji | No flags, skin tones or ZWJ sequences |
| 🟡 | Date and time formats | 24-hour setting exists. Full regional formats to verify |
| 🟡 | Collapsed reply threads and global threads list | Built: Settings, MESSAGES, Threads lists followed threads with reply and unread counts; a tap opens the root post. Follow and unfollow are missing. Device 2026-11-02: the list loads |
| 🟡 | Scheduled posts | Built: + page, Send later sends the next channel message at a time (18:30) or after minutes (45). Needs server 10.3, possibly a licence. Listing and editing scheduled messages is missing. Not yet tested on the device |
| 🟡 | Drafts tab | Built: one draft per channel stays on the phone and comes back when the channel opens. Device test 2026-11-02: works. The list of all drafts is missing |
| 🟡 | Copy code block, copy email address | Built: Copy text in the post long-press menu copies the whole message. Copying only a code block or an address is missing. Not yet tested on the device |
| 🔴 | Edit or delete attachments on existing posts | Android 2.31 |
| 🟡 | Link and permalink previews | Built: the title of an Open Graph preview shows under the message. Device test 2026-11-02: no preview shows for a Reddit link. Not yet checked whether the server sends previews. Image and permalink previews are missing |
| 🟡 | Message attachments and interactive buttons | Built: bot attachments (pretext, title, text, fields) show as text under the message. Buttons and menus are missing. Not yet tested on the device |
| 🔴 | Interactive dialogs | Multiselect, dynamic search, several steps |
| 🔴 | Mattermost Blocks | Android 2.43 |
| 🟡 | Post priority | Built: shows the Urgent and Important labels; the + page sets Important or Urgent for the next channel message. Not for replies or files. Sending not yet tested on the device |
| 🟡 | Acknowledgements | Built: posts that ask for it show how many acknowledged, and the long-press menu has Acknowledge. Asking for acknowledgement when sending is missing. Not yet tested on the device |
| 🔴 | Burn on read | Enterprise Advanced. Display and send. To verify |
| 🔴 | Auto-translation of messages | Enterprise Advanced beta |
| 🔴 | AI rewrite of a draft | Only with Agents on the server |

## Files and media

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Open images | |
| 🟢 | Open other files | |
| 🟢 | Upload under the original name | |
| 🟢 | Show images, on or off | Setting |
| 🟢 | Audio playback in chat | Open attachment plays audio in the system player, not inside the chat. Device 2026-11-02: works |
| 🟢 | Video playback in chat | Open attachment plays video in the system player, not inside the chat. Device 2026-11-02: works |
| 🟢 | Voice message recording | The + page records an AAC voice message and attaches it. Device 2026-11-02: sending works |
| 🟡 | Share into the app from other apps | Built: Mattermost appears in the BlackBerry Share menu for text and files. The next channel you open gets the text in the composer and the file as attachment. Not yet tested on the device |

## Notifications and background

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Hub alert for new messages | Setting |
| 🟢 | Mentions only | Setting |
| 🟢 | Background refresh every six minutes | Hub process |
| 🔴 | Realtime in background over websocket | Hub holds the socket. Costs battery. Needs a setting |
| 🟡 | Notification settings per channel | Built: long-press a channel, then Notifications (push, desktop, mark as unread). Hub honours desktop setting. Not yet tested on the device |
| 🟢 | Test notification tool | Settings, DIAGNOSTICS, Test notification puts a local alert in the Hub. Device 2026-11-02: works |
| ⚪ | Push notifications | No FCM on BlackBerry 10 |

## Search and navigation

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Search, then open the hit | |
| 🟡 | Recent mentions | Built: Settings, MESSAGES. Runs a search for @username. Not yet tested on the device |
| 🟡 | Saved messages list | Built: Settings, MESSAGES. Shows the saved posts in the search page. Not yet tested on the device |
| 🟡 | Search filters | Typed filters from:, in:, before:, after: and on: go to the server unchanged, and the search hint names them. No filter buttons. Not yet tested on the device |

## Profile and status

| | Feature | Notes |
| --- | --- | --- |
| 🟡 | Set status: online, away, do not disturb, offline | Built: Settings, STATUS. Not yet tested on the device |
| 🟡 | Custom status with emoji and expiry | Built: text and clear, with the default emoji. No emoji picker and no expiry yet. Not yet tested on the device |
| 🟡 | View a user profile | Built: Settings, MESSAGES, Look up a user by name. Shows name, nickname, position and email. Device test 2026-11-02: works with the exact username. Opening it from a message or a member is missing |
| 🟡 | Edit own profile | Built: Settings, PROFILE. Name, nickname, position. Email and avatar missing. Not yet tested on the device |
| 🟡 | Custom profile attributes | Built: Look up a user also shows the server's custom profile fields (10.5+). Editing your own is missing. Not yet tested on the device |

## Playbooks

| | Feature | Notes |
| --- | --- | --- |
| 🟡 | View runs and tasks | Built: Settings, MESSAGES, Playbook runs lists running runs with done tasks; a tap shows the checklists. Needs the Playbooks plugin. Not yet tested on the device |
| 🟡 | Create runs, post run updates, finish runs | Built: Playbook runs page starts a run from a playbook; a run page posts status updates and finishes the run. Reminders and run settings are missing. Not yet tested on the device |
| 🟡 | Checklists, task editing, filters | Built: a tap on a task marks it done or opens it again. Editing task text and filters are missing. Not yet tested on the device |
| 🟡 | Rename runs, edit attributes and summaries | Built: a run page renames the run and edits its summary (PATCH). Custom run attributes are missing. Not yet tested on the device |

## AI Agents

| | Feature | Notes |
| --- | --- | --- |
| 🔴 | Agent chat with threads and bot selector | Android 2.40 |
| 🔴 | Streaming, citations, stop and regenerate | Android 2.36 |
| 🔴 | Tool-call approval | Android 2.36 and 2.44 |

## Settings and language

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Refresh, team, log out, preview, 24-hour clock, images, hub alerts, mentions only, protocol log | |
| 🟡 | English and German | Other languages are a catalog. See README |
| 🟡 | Dark theme | Built: Settings, DISPLAY, Dark design. tools/make-dark.py writes dark copies of the pages, and system controls switch to the Cascades dark style. Takes effect after a restart. Not yet tested on the device |
| ⚪ | Disable animations | Cascades has no switch for its page and list transitions, and the app adds no animations of its own |

## Security

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Server certificate checked against a current CA bundle | `assets/cacert.pem` |
| 🟡 | Client certificates | Built: Settings, ACCOUNT, Client certificate takes a PEM certificate and an RSA or DSA key (with passphrase) and sends them on every TLS connection. PKCS#12 import is missing, Qt 4.8 cannot read it. Not yet tested on the device |
| 🟡 | App lock | Built: Settings, ACCOUNT, App lock with a PIN (stored as salted hash). Asked at start and after the app was in the background. No biometrics on BlackBerry 10. Not yet tested on the device |
| ⚪ | Root and jailbreak blocking, screen-capture prevention | MDM |
| ⚪ | Intune app protection, Zero Persistence Mode, Offline Persistence Timer, wipe notifications | MDM |

## Diagnostics

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Protocol log | Setting |
| 🟢 | Problem report | Settings, DIAGNOSTICS, Copy problem report puts version, server and the end of debug.log on the clipboard instead of opening an email. Device 2026-11-02: works |

## Out of scope

| | Feature | Notes |
| --- | --- | --- |
| ⏸ | Voice and video calls, screen share, ringing | Decided by the maintainer |
| ⚪ | Boards | Not found in the Android app. To verify |
| ⚪ | CallKit and PushKit | iOS only |
| ⚪ | Native iOS logs | iOS only |
