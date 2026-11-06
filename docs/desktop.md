# Desktop

[← Back to README](../README.md)

CCA works with the Claude desktop app in two separate ways:

1. **[A Claude app copy per account](#claude-app-copy-per-account).** The CLI starts the official Claude desktop app once per account, each with its own data folder, so every account stays signed in to the app at the same time.
2. **[The Claude Accounts app](#the-claude-accounts-app).** CCA's own desktop app, which runs the CLI for you with buttons.

> The desktop features rely on undocumented behaviour of the Claude desktop app (its `--user-data-dir` option and its use of `CLAUDE_CONFIG_DIR`). They may break after a Claude app update.

## Claude app copy per account

```sh
cca app personal            # make a launcher
cca app personal purple     # with a purple icon
cca open personal           # open it from the terminal
```

On macOS, `cca app personal` makes `~/Applications/Claude Personal.app`. Drag it to the Dock. Clicking it opens that account's copy of the Claude app, or brings it to the front; it never starts a second copy on the same data. On Windows it makes a Start menu shortcut, `Claude Personal` (see [Windows notes](#windows-notes)).

Each copy runs the one installed Claude app with:

- its own data folder: `~/.claude-accounts/desktop/<name>`
- the account's configuration folder for its Code tab: `~/.claude-accounts/profiles/<name>`

The default account's copy is the normal Claude app, with its usual data folder.

macOS asks once whether the launcher may control System Events. Allow it: the launcher uses it to bring the right window forward.

### First sign-in

The sign-in link returns to the app through `claude://`. If two copies are open, the link can reach the wrong one. So for the first sign-in of a new copy:

1. Quit every Claude window (Cmd+Q).
2. Open only the new copy, and sign in.
3. Reopen the others.

### Connectors (MCP servers)

Connectors sign in the same way, and each account keeps its own connector sign-ins. To sign one in while other copies stay open, use the terminal, which returns to `localhost` instead of `claude://`:

```sh
cca run personal
```

Then type `/mcp`, pick the server and sign in. The account's Claude app uses it from its next conversation. In the Claude Accounts app, **MCP servers → Sign In…** does the same: it opens a terminal with Claude on that account at its `/mcp` list.

### What each copy keeps separate

- Chat tab: skills and connectors set up on claude.ai, and desktop extensions, are per copy.
- Code tab: uses the account's configuration folder, so it shares `settings.json`, `CLAUDE.md`, skills and plugins with the other accounts (see [Shared files](architecture.md#shared-files)) and keeps its own sessions and MCP sign-ins.
- Chats in the Chat tab are stored by Anthropic for the signed-in account, not by CCA.

## Claude app updates (macOS)

Every copy runs the one `/Applications/Claude.app`, which updates itself. Copies that are open during an update keep the old version until they restart, and the Claude updater reopens only the default account's copy, even when another copy installed the update.

```sh
cca update            # restart every open copy once, now
cca autoupdate on     # do it automatically after each Claude app update
```

`cca autoupdate on` adds a launchd job that checks once a minute and whenever `/Applications` changes. After an update it:

- quits each copy that was open, as Cmd+Q does, and opens it again on the new version. If work is running, Claude may ask first.
- reopens the copy that closed to install the update, and closes the default copy that the updater opened in its place.

macOS may ask once for permission to control Claude. Allow it, or the copies cannot be restarted. The log is `~/.claude-accounts/autoupdate.log`. `cca autoupdate off` turns it off.

These commands restart the Claude app. They do not update CCA; see [Installation](installation.md#update-the-cli).

## Claude in Chrome per account

*macOS only.* The Claude in Chrome extension signs in once per Chrome profile, and a profile holds one Claude account at a time. So give each account a Chrome profile of its own:

```sh
cca chrome                  # list Chrome's profiles and the accounts linked to them
cca chrome acme Work        # link an account to a profile: the name Chrome shows, or its folder ("Profile 3")
cca chrome acme             # open Chrome in that profile
cca chrome acme --unlink    # drop the link
```

Sign in to the extension once in each profile, with the account linked to it. After that, `cca chrome <name>` opens Chrome with the extension already on that account. Removing an account drops its link too.

- Links are kept in `~/.claude-accounts/chrome-profiles` and saved with each backup.
- CCA only reads Chrome's list of profiles. It changes nothing in Chrome or in the extension.
- If the linked profile no longer exists, `cca chrome <name>` refuses instead of opening an empty new profile.
- Needs jq and Google Chrome in `/Applications`.

macOS lets Terminal read Chrome's profile list but not the desktop app. So each time CCA reads it (`install.sh`, `cca chrome`), it keeps a copy in `~/.claude-accounts/chrome-profiles-seen`, and the Claude Accounts app uses that copy. After you add a Chrome profile, run `cca chrome` once in Terminal so the app sees it.

## The Claude Accounts app

<!-- Phase 4: add a real screenshot here (assets/screenshots/desktop.png). -->

### Install

Download it from [GitHub Releases](https://github.com/AbbasAlsbihawi/cca/releases/latest):

| Platform | File |
|---|---|
| macOS, Apple silicon | `ClaudeAccounts-<version>-arm64-mac.dmg` |
| macOS, Intel | `ClaudeAccounts-<version>-x64-mac.dmg` |
| Windows, x64 | `ClaudeAccounts-Setup-<version>.exe` |

Neither build is signed with a paid developer certificate, so the first launch is blocked:

- **macOS:** open System Settings → Privacy & Security and choose *Open Anyway*.
- **Windows:** on the SmartScreen prompt, choose *More info* → *Run anyway*.

On macOS, install the CLI with `./install.sh` first. On Windows, the app puts its own copy of `cca.ps1` in `~\.claude-accounts` when none is there; run `.\install.ps1` as well if you want the `cca` command in PowerShell.

### What it does

The window is laid out like macOS System Settings: your accounts are in the sidebar, and each one has its own page. For each account you can:

- open its Claude app copy, or make the launcher (**Make App**, **Remake App**)
- pick a colour for its icon
- open a terminal that uses the account
- log in again (**Log In Again…**)
- sign in to its MCP servers, in a terminal (**MCP servers → Sign In…**)
- pick its Chrome profile and open Chrome there (macOS)
- bind and unbind folders
- restore conversations, with a preview first
- remove the account, after a confirmation

Add an account with **+** under the list; the sign-in runs in a terminal window. The **General** page at the bottom of the sidebar (*Settings…*, ⌘, on macOS) holds everything that applies to all accounts:

- take a backup now, turn the daily backup on or off, and see the latest backup
- see the app's version and update status, with a progress bar while an update downloads; **Check Now** checks right away
- on macOS: turn Claude app autoupdate on or off, and **Restart Claude…**, which quits and reopens every open copy as `cca update` does. A restart also gives an account the default account's MCP servers if it has none yet.

If a command fails, a banner says so. **Show Activity** lists every command the window ran, with its output.

Closing the window keeps the app running in the menu bar (macOS) or the tray (Windows). That menu lists your accounts (click one to open its Claude app), per-account actions (*Open*, *New Terminal*, *Make app*), *Backup now*, *Open window* and *Quit*.

### Updates

The app checks GitHub Releases for a newer version about 15 seconds after it starts, and then every 4 hours. **Check Now** on the General page, or *Check for Updates…* in the app menu, checks right away.

- **macOS:** the app downloads the release zip for its architecture and replaces its own bundle. When the new release uses the same Electron version, it downloads a small update-only zip (about 1 MB) instead of the full app. A cut-off download picks up where it stopped, up to five tries.
- **Windows:** the app uses electron-updater. A downloaded update can install now or when you quit.

A check that fails because of the connection runs again 10 minutes later.

### How it talks to the CLI

The app runs the `cca` CLI for every action, so the terminal and the app always agree. On macOS it runs `~/.claude-accounts/cca.zsh` with zsh; on Windows it runs `cca.ps1` through a small PowerShell script. Arguments are passed as an argument list, never as a shell command string. The app reads `cca list --json` to draw its window. Commands that need input, such as `cca add` and `cca login`, open in a real terminal window.

## Windows notes

- `cca app <name> [color]` makes a Start menu shortcut in `Programs\cca`. With a colour, the shortcut gets a tinted Claude icon, and the Claude Accounts app shows the colour as a dot next to the account. Windows may still show the plain Claude icon on a running window in the taskbar.
- `cca open <name>` starts the Claude desktop app with its own `--user-data-dir`. CCA looks for the app in the usual install folders under `%LOCALAPPDATA%` and in installed app packages. If it is elsewhere, set `CCA_CLAUDE_EXE` to its `Claude.exe`.
- `cca chrome`, `cca update` and `cca autoupdate` are not available on Windows.

## Limitations

- Depends on undocumented Claude desktop app behaviour; a Claude app update can break it.
- First sign-in of each copy needs the other copies closed (the `claude://` link).
- The desktop builds are unsigned, so the operating system warns on first launch.
