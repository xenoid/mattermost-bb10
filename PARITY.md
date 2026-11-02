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
| 🔴 | Several accounts or servers | `MmClient` is a singleton with fixed settings keys |
| 🔴 | Authentication secret on server entry | Optional field, server setting |
| 🔴 | Sign in with GitLab, Google or Entra ID (OAuth) | Needs an in-app browser spike first |
| 🔴 | SAML (Okta, OneLogin, ADFS) | Same spike as OAuth |
| 🔴 | Magic link for guests | Server v11.3 and later |
| 🟡 | Forgot-password link | Built: opens `/reset_password` of the server in the browser. Not yet tested on the device |
| 🔴 | AD/LDAP | Probably works through password login. To verify |
| ⚪ | Sign in with Microsoft under Intune | MDM, iOS only in the docs |

## Teams and channels

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Channel list: public, private, direct, unread, mentions | |
| 🟢 | Hide the channel subtitle | |
| 🟡 | Create a channel | Built: Settings, MESSAGES, New channel. Public channels only. Not yet tested on the device |
| 🟡 | Show, add and remove members | Built: show members from the long-press menu, add by username, remove by tap and confirm. Only public and private channels. Not yet tested on the device |
| 🟡 | Leave, archive, edit header and purpose | Built: leave, archive, edit header and purpose from the long-press menu. Not yet tested on the device |
| 🟡 | New direct message | Built: Settings, MESSAGES, enter a username. Group messages still missing. Not yet tested on the device |
| 🔴 | Admin-managed sidebar categories | Android 2.41 |
| 🔴 | Channel bookmarks | Read-only display is enough at first |
| 🔴 | Channel banners | Enterprise Advanced. Show only |
| 🔴 | Guest invitations | |
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
| 🔴 | Collapsed reply threads and global threads list | Thread page exists. List and follow logic missing. To verify |
| 🔴 | Scheduled posts | Server API |
| 🔴 | Drafts tab | Local drafts. `LocalStore` can hold them |
| 🔴 | Copy code block, copy email address | |
| 🔴 | Edit or delete attachments on existing posts | Android 2.31 |
| 🔴 | Link and permalink previews | Read `post.metadata` |
| 🔴 | Message attachments and interactive buttons | `mmaction://` links |
| 🔴 | Interactive dialogs | Multiselect, dynamic search, several steps |
| 🔴 | Mattermost Blocks | Android 2.43 |
| 🔴 | Post priority | To verify |
| 🔴 | Acknowledgements | To verify |
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
| 🔴 | Audio playback in chat | `bb::multimedia`. Android 2.27 |
| 🔴 | Video playback in chat | |
| 🔴 | Voice message recording | To verify |
| 🔴 | Share into the app from other apps | Invoke target for `bb.action.SHARE` |

## Notifications and background

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Hub alert for new messages | Setting |
| 🟢 | Mentions only | Setting |
| 🟢 | Background refresh every six minutes | Hub process |
| 🔴 | Realtime in background over websocket | Hub holds the socket. Costs battery. Needs a setting |
| 🟡 | Notification settings per channel | Built: long-press a channel, then Notifications (push, desktop, mark as unread). Hub honours desktop setting. Not yet tested on the device |
| 🔴 | Test notification tool | Low priority |
| ⚪ | Push notifications | No FCM on BlackBerry 10 |

## Search and navigation

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Search, then open the hit | |
| 🟡 | Recent mentions | Built: Settings, MESSAGES. Runs a search for @username. Not yet tested on the device |
| 🟡 | Saved messages list | Built: Settings, MESSAGES. Shows the saved posts in the search page. Not yet tested on the device |
| 🔴 | Search filters | To verify |

## Profile and status

| | Feature | Notes |
| --- | --- | --- |
| 🟡 | Set status: online, away, do not disturb, offline | Built: Settings, STATUS. Not yet tested on the device |
| 🟡 | Custom status with emoji and expiry | Built: text and clear, with the default emoji. No emoji picker and no expiry yet. Not yet tested on the device |
| 🔴 | View a user profile | |
| 🟡 | Edit own profile | Built: Settings, PROFILE. Name, nickname, position. Email and avatar missing. Not yet tested on the device |
| 🔴 | Custom profile attributes | Server feature flag |

## Playbooks

| | Feature | Notes |
| --- | --- | --- |
| 🔴 | View runs and tasks | Android 2.31 |
| 🔴 | Create runs, post run updates, finish runs | Android 2.34 |
| 🔴 | Checklists, task editing, filters | Android 2.35 to 2.45 |
| 🔴 | Rename runs, edit attributes and summaries | Android 2.37 and 2.38 |

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
| 🔴 | Dark theme | Colours into tokens first |
| 🔴 | Disable animations | Android 2.31 |

## Security

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Server certificate checked against a current CA bundle | `assets/cacert.pem` |
| 🔴 | Client certificates | `QSslConfiguration`, import screen needed |
| 🔴 | App lock | No biometric API on BlackBerry 10. An app PIN would be the substitute |
| ⚪ | Root and jailbreak blocking, screen-capture prevention | MDM |
| ⚪ | Intune app protection, Zero Persistence Mode, Offline Persistence Timer, wipe notifications | MDM |

## Diagnostics

| | Feature | Notes |
| --- | --- | --- |
| 🟢 | Protocol log | Setting |
| 🔴 | Problem report | Low priority |

## Out of scope

| | Feature | Notes |
| --- | --- | --- |
| ⏸ | Voice and video calls, screen share, ringing | Decided by the maintainer |
| ⚪ | Boards | Not found in the Android app. To verify |
| ⚪ | CallKit and PushKit | iOS only |
| ⚪ | Native iOS logs | iOS only |
