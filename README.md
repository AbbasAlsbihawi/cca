# cca

cca runs several Claude accounts on one Mac, for example personal, work and client, in the Claude Code terminal and in the Claude desktop app. You do not log out to switch.

cca is unofficial and not affiliated with Anthropic.

## Requirements

- macOS and zsh
- Claude Code CLI (`claude`)
- Claude desktop app, for the desktop part only
- jq (optional): copies your MCP servers into new accounts, and into an account that has none yet

## Install

```sh
git clone https://github.com/AbbasAlsbihawi/cca.git && cd cca && ./install.sh
```

Then open a new terminal.

To uninstall, run `./uninstall.sh`. This keeps your account data. To remove the data too:

```sh
rm -rf ~/.claude-accounts
```

## Windows

`cca.ps1` is a PowerShell port (Windows PowerShell 5.1 or PowerShell 7). Install:

```powershell
git clone https://github.com/AbbasAlsbihawi/cca.git; cd cca; .\install.ps1
```

Open a new PowerShell window afterwards. If PowerShell blocks your profile, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once. Uninstall with `.\uninstall.ps1`.

The terminal commands work the same as on macOS: `add`, `login`, `use`, `bind`, `unbind`, `run`, `list`, `remove`, `backup`, `restore`, `autobackup` (a Task Scheduler job). Differences:

- Shared files (`settings.json`, `skills`, ...) are linked with symlinks, falling back to junctions and hard links. Turn on Developer Mode in Windows settings for full symlink support.
- `cca app <name> [color]` makes a Start menu shortcut. With a colour (red, orange, yellow, green, teal, blue, purple, pink, gray) the shortcut gets a tinted Claude icon, and the desktop app shows the colour as a dot next to the account. The tint is on the shortcut; Windows may still show the plain Claude icon on a running window in the taskbar. `cca open <name>` starts the desktop app with its own `--user-data-dir`. The app is looked for in the usual install folders; set `CCA_CLAUDE_EXE` to its `Claude.exe` if it is elsewhere. The desktop part is untested on a real install.
- `cca import` is not available; `cca restore` also pulls sessions from the main Claude app.
- Removed accounts go to the Recycle Bin.

## Quick start

1. Name your current login first. Do this before you bind any folder.

   ```sh
   echo work > ~/.claude-accounts/default-name
   ```

2. Add a second account. This opens the browser to sign in.

   ```sh
   cca add personal --email you@example.com
   ```

   If the browser is signed in to another Claude account, switch it, or use a private window.

3. In a project folder, bind the folder to an account.

   ```sh
   cd ~/projects/client-x
   cca bind personal
   ```

4. Use an account in one terminal, or for one run.

   ```sh
   cca use personal     # this terminal
   cca use -            # stop using it in this terminal
   cca run personal     # one run only
   ```

5. See which account you are using here.

   ```sh
   cca
   ```

## Commands

| Command | What it does |
|---|---|
| `cca` | show the account used here, all accounts and bound folders |
| `cca add <name> [opts]` | create an account and log in (opts: `--email you@x.com`, `--sso`) |
| `cca login <name> [opts]` | log in again (expired, or the wrong account) |
| `cca use <name>` | use an account in this terminal (`cca use -` to stop) |
| `cca bind <name> [folder]` | always use an account in a folder and its subfolders |
| `cca unbind [folder]` | remove a folder binding |
| `cca run <name> [args]` | run claude once with an account |
| `cca list [--json]` | list accounts with their emails (`--json`: for scripts and the desktop app) |
| `cca app <name> [color]` | make a 'Claude <Name>' app in ~/Applications for that account, with a coloured icon |
| `cca open <name>` | open the Claude app for an account (or bring it to the front) |
| `cca chrome [<name> [<profile>\|--unlink]]` | open Chrome in the profile linked to an account; with a profile, link it; alone, list Chrome's profiles (macOS, see [Claude in Chrome per account](#claude-in-chrome-per-account)) |
| `cca remove <name>` | log out an account; move its folders and launcher to the Trash |
| `cca backup [--quiet\|list]` | save every account's conversations; `list` shows the snapshots |
| `cca restore <name> [snapshot] [-n] [--account <uuid>]` | bring an account's conversations back, without overwriting anything (`-n`: dry run) |
| `cca autobackup on\|off\|status` | a daily backup at 13:00 |
| `cca update` | quit and reopen every open Claude app copy, so each runs the installed version (macOS) |
| `cca autoupdate on\|off\|status` | do that by itself after the Claude app updates (macOS) |

## Which account `claude` uses

The first match wins:

1. `cca use <name>` in this terminal
2. a folder bound with `cca bind <name>` (that folder or a parent folder)
3. the default account (`~/.claude`)

Inside a Claude Code session, `claude` keeps the account of that session.

`claude` prints a dim line, `claude account: ...`, before it starts. Set `CCA_QUIET=1` to hide it.

## Claude app per account

```sh
cca app personal
```

This makes `~/Applications/Claude Personal.app`. Drag it to the Dock.

Give it a colour to tell accounts apart: `cca app personal purple`. Colours: red, orange, yellow, green, teal, blue, purple, pink, gray. Run `cca app personal` again later and it keeps the colour. An unknown colour is an error and changes nothing. If the icon cannot be tinted, you get a warning and the plain icon.

Clicking the launcher opens that account's copy of the Claude app, or brings it to the front. It never opens a second copy on the same data.

First sign-in:

1. Quit every Claude window (Cmd+Q).
2. Open only the new one, and sign in.
3. Reopen the others.

The sign-in link returns through `claude://`. If two copies are open, it can reach the wrong one.

Connectors (MCP servers) sign in the same way, and each account keeps its own sign-ins. To sign one in while other copies stay open, use the terminal, which does not use `claude://`:

```sh
cca run personal
```

Then type `/mcp`, pick the server and sign in. The account's Claude app uses it from its next conversation. In the desktop app, *Sign in to MCP…* does the same: it opens Terminal with Claude on that account at its `/mcp` list.

macOS asks once for permission to let the launcher control System Events. Allow it. The launcher uses this to bring the right window forward.

Each desktop copy uses its own data folder, `~/.claude-accounts/desktop/<name>`. Its Code tab uses the config folder of that account.

### Updates

Every copy runs the one `/Applications/Claude.app`, which updates itself. Copies that are open during an update keep the old version until they restart. The updater reopens only the default account's copy, even when another copy installed the update.

```sh
cca autoupdate on
```

This adds a launchd job that looks once a minute, and whenever `/Applications` changes. After an update it:

- quits each copy that was open, as Cmd+Q does, and opens it again on the new version. If work is running, Claude may ask first.
- reopens the copy that closed to install the update, and closes the default copy the updater opened in its place.

macOS may ask once for permission to control Claude. Allow it, or the copies cannot be restarted. The log is `~/.claude-accounts/autoupdate.log`. `cca autoupdate off` turns it off. To restart every open copy once by hand: `cca update`.

## Claude in Chrome per account

The Claude in Chrome extension signs in once per Chrome profile, and a profile holds one Claude account at a time. So give each account a Chrome profile of its own (macOS):

```sh
cca chrome                  # list Chrome's profiles and the accounts linked to them
cca chrome supercell Work   # link an account to a profile: the name Chrome shows, or its folder ("Profile 3")
cca chrome supercell        # open Chrome in that profile
```

Sign in to the extension once in each profile, with the account linked to it. After that, `cca chrome <name>` opens Chrome with the extension already on that account. `cca chrome <name> --unlink` drops the link, and removing an account drops it too. The links are in `~/.claude-accounts/chrome-profiles` and are saved with each backup. cca only reads Chrome's list of profiles; it changes nothing in Chrome or the extension.

macOS lets Terminal read that list but not the desktop app. So each time cca reads it (`install.sh`, `cca chrome`), it keeps a copy in `~/.claude-accounts/chrome-profiles-seen`, and the desktop app uses that copy. After you add a Chrome profile, run `cca chrome` once in Terminal so the app sees it.

## Desktop app

"Claude Accounts" is one app for macOS and Windows that does the same things with buttons. Install it from [GitHub Releases](https://github.com/AbbasAlsbihawi/cca/releases): the `.dmg` on macOS, `ClaudeAccounts-Setup-<version>.exe` on Windows. It updates itself. Neither build is signed with a paid developer certificate, so the first launch is blocked: on macOS open System Settings → Privacy & Security and choose *Open Anyway*; on Windows choose *More info* → *Run anyway*.

The window is laid out like macOS System Settings: your accounts are in the sidebar, and each one has its own page. For each account you can:

- open its Claude app, or make the app
- pick a colour for its icon
- open a Terminal that uses the account
- log in again
- sign in to its MCP servers, in Terminal (see [above](#claude-app-per-account))
- pick its Chrome profile and open Chrome there, for Claude in Chrome (macOS, see [above](#claude-in-chrome-per-account))
- restore conversations, with a preview first
- remove the account, after a confirm
- bind and unbind folders

Add an account with **+** under the list. The *General* page at the bottom of the sidebar (*Settings…*, ⌘, on macOS) is for everything that applies to all accounts: take a backup now, turn the daily autobackup on or off, see the latest backup, and see the app's version and its update status, with a progress bar while an update downloads. *Check Now* there (or *Check for Updates…* in the app menu) checks right away. A download that is cut off picks up where it stopped, up to five tries, and a check that still fails runs again 10 minutes later. On macOS it also turns autoupdate on or off, and *Restart Claude…* quits and reopens every open copy, as `cca update` does (see [Updates](#updates)). A restart also gives an account the default account's MCP servers if it has none yet. If a command fails, a banner says so; *Show Activity* lists every command the window ran, with its output.

The app calls `cca`, so the terminal and the app always agree. On macOS, install `cca` first with `./install.sh`. On Windows the app installs its own copy when it starts; run `.\install.ps1` as well if you want the `cca` command in PowerShell. `cca list --json` prints the accounts, folders and snapshots as JSON, which is what the app reads.

## How it works

Each account has its own config folder, set with `CLAUDE_CONFIG_DIR`. So each account has its own login and its own keychain entry. The default account is `~/.claude`.

These are shared with `~/.claude` through symlinks:

- `settings.json`, `CLAUDE.md`, skills, plugins
- `agents`, `commands`, `output-styles`, `keybindings.json`, if present

So a plugin or skill installed from one account is there in all of them.

cca adds any missing link each time an account starts (`claude`, `cca run`, `cca open`), so a file you add to `~/.claude` later, such as `CLAUDE.md` or `agents`, reaches every account. A file an account has of its own is kept.

These stay separate for each account:

- chat history
- memory
- connector sign-ins, and MCP servers added with `claude mcp add`
- in the desktop app's Chat tab: skills and connectors set up on claude.ai, and desktop extensions

## Files

- `~/.claude-accounts/cca.zsh`: the script
- `~/.claude-accounts/default-name`: the name of the default account
- `~/.claude-accounts/bindings`: folder bindings
- `~/.claude-accounts/chrome-profiles`: the Chrome profile linked to each account
- `~/.claude-accounts/chrome-profiles-seen`: Chrome's profiles as cca last read them, for the desktop app
- `~/.claude-accounts/profiles/<name>/`: config folder of each account
- `~/.claude-accounts/desktop/<name>/`: data folder of each desktop copy
- `~/.claude-accounts/backups/`: backup snapshots
- `~/.claude-accounts/app-state`, `autoupdate.log`: the Claude version and open copies `cca update` saw last, and the autoupdate log
- `~/Applications/Claude <Name>.app`: desktop launchers
- one line in `~/.zshrc` that loads `cca.zsh`

## Backups

`cca backup` saves, for every account:

- its Claude Code transcripts (`projects`)
- its desktop Code tab session list (`claude-code-sessions`)
- your folder bindings, the default account name and the Chrome profile links

Each backup is a snapshot folder in `~/.claude-accounts/backups/<date_time>`. It uses APFS clones, so it is instant and takes almost no extra space. cca keeps the newest 30 snapshots (`CCA_BACKUP_KEEP` changes this) and logs each run in `backups/backup.log`.

```sh
cca backup                 # take a snapshot now
cca backup list            # snapshots, newest first
cca restore personal       # bring conversations back from the newest snapshot
cca restore personal 2026-05-01_130000   # from a chosen snapshot
cca restore personal --dry-run           # shows what would be copied; changes nothing
cca autobackup on          # every day at 13:00 (off to stop, status to check)
```

While autobackup is on, `cca remove` and `cca login` take a backup first. With autobackup off, cca takes no backup unless you run `cca backup`.

Logging out inside a desktop copy hides its conversations from the Code tab. They are not deleted. `cca restore <name>` brings them back: it copies what is missing from the newest snapshot and, for a desktop copy, from the main Claude app, then moves the "deleted" marks of those sessions to the Trash. Quit that account's Claude app first. Restore never overwrites a file. It also copies the Code tab sessions an account used in the main app before it had its own copy, with the transcripts they point to. The account is found from its terminal login (`cca login`) or from the one account its copy has signed in with; otherwise pass `--account <uuid>`. Add `--dry-run` (`-n`) to see what would be copied and which marks would move, without changing anything. Chats in the Chat tab live on Anthropic's servers and show up by themselves once the copy is signed in to that account.

`cca import` still works as an older name for `cca restore`.

Claude Code deletes conversations older than 30 days by default. To keep them, add this to `~/.claude/settings.json`:

```json
"cleanupPeriodDays": 3650
```

Backups sit on the same disk. Keep Time Machine on for a disk failure.

## Removing an account

```sh
cca remove personal
```

This logs the account out, drops its folder bindings and Chrome profile link, and moves its config folder, desktop data and launcher to the Trash (use Put Back to undo). Quit that account's Claude app first. For the default account only the login and launcher go; `~/.claude` stays.

## Troubleshooting

- `command not found: cca`: open a new terminal, or run `source ~/.zshrc`.
- After updating cca, open terminals pick up the new version by themselves on the next `cca` command.
- A desktop copy shows the wrong account: quit all Claude copies, open only that one, log out, then log in.
- Signing in picks the wrong Google account: type the email and use "Continue with email" instead of "Continue with Google".
- The terminal uses the wrong account: run `cca login <name>`.

## Releasing

For maintainers. Releases are cut locally; there is no CI release.

```sh
cd desktop && npm install
npm version patch --no-git-tag-version
npm run dist:all
npm run release
```

To publish a version whose installer has not been tried on its own platform
yet, add `-- --prerelease`. GitHub then marks the release as not production
ready; the tag and the assets are the same.

Both platforms are unsigned. The Windows artifacts are cross-built from macOS.

## Tests

```sh
zsh tests/run.sh
```

## Disclaimer

The desktop part relies on undocumented app behavior. It may break after an app update.

Use cca to separate your own accounts. Follow your organization's policies. Do not use it to get around usage limits.

## License

MIT
