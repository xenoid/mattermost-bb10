# Device test list

Everything here is built (up to 1.0.0.175) but not yet confirmed on the device. Turn on Settings, DIAGNOSTICS, Protocol log first; every tap, request and database call then lands in `debug.log`, so a failure can be traced without guessing. Mark a row in [PARITY.md](PARITY.md) 🟢 only after it works here.

## Sign-in and accounts

- [ ] Login page: Sign in with GitLab, Google, Office 365 or SAML opens the browser and comes back signed in
- [ ] Login page: Sign in with a link from an email (paste a guest invite link)
- [ ] Login page: Authentication secret (only behind a proxy that asks for it)
- [ ] Settings, ACCOUNT, Accounts and servers: Add account, then switch back and forth
- [ ] Settings, ACCOUNT, Client certificate: pick PEM certificate and key, then reload a channel
- [ ] Settings, ACCOUNT, App lock: set a PIN, put the app in the background, unlock
- [ ] Settings, ACCOUNT, Join a team: join an open team; Join with an invite link

## Channels

- [ ] Long-press a channel: Notifications, Members (add, remove), Bookmarks (open, Add link)
- [ ] Long-press a channel: Edit header, Edit purpose, then Save
- [ ] Long-press a channel: Leave channel, Archive channel (on a test channel)
- [ ] Long-press a channel: Invite guest, Auto-translation
- [ ] Channel list grouped by your sidebar categories (favourites first)
- [ ] Settings, MESSAGES: New channel (public and private), New direct message, New group message

## Messages

- [ ] Plus page: Send as important, Send as urgent, Send later (e.g. 2 minutes)
- [ ] Plus page: Record voice message (confirmed), Rewrite with AI (needs Agents)
- [ ] Long-press a post: Copy text, Copy code, Copy email address
- [ ] Long-press a post: Follow thread, Unfollow thread, Acknowledge
- [ ] Long-press your own post with a file: Remove attachments
- [ ] Bot posts: attachment text and Actions; Mattermost Blocks text and buttons
- [ ] Slash command that opens an interactive dialog, then Submit
- [ ] Burn-on-read post: Reveal, then Burn now on your own
- [ ] Share a link and a photo from another app into Mattermost
- [ ] Settings, MESSAGES: Threads, Recent mentions, Saved messages, Look up a user (custom fields)

## Agents and playbooks

- [ ] Settings, MESSAGES, Chat with an agent: pick an agent, ask something
- [ ] Agent reply: Stop generating, Regenerate, Tool calls (allow or reject)
- [ ] Settings, MESSAGES, Playbook runs: Start a run, open it, tick a task, Status, Rename, Summary, Finish

## Display and background

- [ ] Settings, DISPLAY, Dark design, then restart the app
- [ ] Settings, Realtime alerts on: a new message raises a Hub alert within seconds
- [ ] Settings, STATUS: status and custom status; Settings, PROFILE: edit name, nickname, position
