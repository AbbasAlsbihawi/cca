[العربية](README.ar.md)

# cca

cca runs several Claude accounts on one Mac, for example personal, work and client, in the Claude Code terminal and in the Claude desktop app. You do not log out to switch.

cca is unofficial and not affiliated with Anthropic.

## Requirements

- macOS and zsh
- Claude Code CLI (`claude`)
- Claude desktop app, for the desktop part only
- jq (optional): copies your MCP servers into new accounts

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
- `cca app <name>` makes a Start menu shortcut, with no icon colour. `cca open <name>` starts the desktop app with its own `--user-data-dir`. The app is looked for in the usual install folders; set `CCA_CLAUDE_EXE` to its `Claude.exe` if it is elsewhere. The desktop part is untested on a real install.
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
| `cca list [--json]` | list accounts with their emails (`--json`: for scripts and the Mac app) |
| `cca app <name> [color]` | make a 'Claude <Name>' app in ~/Applications for that account, with a coloured icon |
| `cca open <name>` | open the Claude app for an account (or bring it to the front) |
| `cca remove <name>` | log out an account; move its folders and launcher to the Trash |
| `cca backup [--quiet\|list]` | save every account's conversations; `list` shows the snapshots |
| `cca restore <name> [snapshot] [-n] [--account <uuid>]` | bring an account's conversations back, without overwriting anything (`-n`: dry run) |
| `cca autobackup on\|off\|status` | a daily backup at 13:00 |

## Which account `claude` uses

The first match wins:

1. `cca use <name>` in this terminal
2. a folder bound with `cca bind <name>` (that folder or a parent folder)
3. the default account (`~/.claude`)

Inside a Claude Code session, `claude` keeps the account of that session.

`claude` prints a dim line, `claude account: ...`, before it starts. Set `CCA_QUIET=1` to hide it.

## Desktop app

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

macOS asks once for permission to let the launcher control System Events. Allow it. The launcher uses this to bring the right window forward.

Each desktop copy uses its own data folder, `~/.claude-accounts/desktop/<name>`. Its Code tab uses the config folder of that account.

## Mac app

"Claude Accounts" is a small Mac app that does the same things with buttons. Build and install it:

```sh
app/build.sh --install
```

`./install.sh` does this for you when `swiftc` is installed. The app goes to `~/Applications/Claude Accounts.app`.

The window lists your accounts. For each account you can:

- open its Claude app, or make the app
- pick a colour for its icon
- open a New Terminal that uses the account
- log in again
- restore conversations, with a preview first
- remove the account, after a confirm
- bind and unbind folders

For all accounts you can add an account, take a backup now, turn the daily autobackup on or off, and see the snapshots.

The app also has a menu bar icon. It stays there when you close the window.

Add, log in again and New Terminal open Terminal.app.

The app calls `cca`, so the terminal and the app always agree. `cca list --json` prints the accounts, folders and snapshots as JSON, which is what the app reads.

## How it works

Each account has its own config folder, set with `CLAUDE_CONFIG_DIR`. So each account has its own login and its own keychain entry. The default account is `~/.claude`.

These are shared with `~/.claude` through symlinks:

- `settings.json`, `CLAUDE.md`, skills, plugins
- `agents`, `commands`, `output-styles`, `keybindings.json`, if present

These stay separate for each account:

- chat history
- memory

## Files

- `~/.claude-accounts/cca.zsh`: the script
- `~/.claude-accounts/default-name`: the name of the default account
- `~/.claude-accounts/bindings`: folder bindings
- `~/.claude-accounts/profiles/<name>/`: config folder of each account
- `~/.claude-accounts/desktop/<name>/`: data folder of each desktop copy
- `~/.claude-accounts/backups/`: backup snapshots
- `~/Applications/Claude <Name>.app`: desktop launchers
- `~/Applications/Claude Accounts.app`: the Mac app (source in `app/`, built to `app/build/`)
- one line in `~/.zshrc` that loads `cca.zsh`

## Backups

`cca backup` saves, for every account:

- its Claude Code transcripts (`projects`)
- its desktop Code tab session list (`claude-code-sessions`)
- your folder bindings and the default account name

Each backup is a snapshot folder in `~/.claude-accounts/backups/<date_time>`. It uses APFS clones, so it is instant and takes almost no extra space. cca keeps the newest 30 snapshots (`CCA_BACKUP_KEEP` changes this) and logs each run in `backups/backup.log`.

```sh
cca backup                 # take a snapshot now
cca backup list            # snapshots, newest first
cca restore personal       # bring conversations back from the newest snapshot
cca restore personal 2026-05-01_130000   # from a chosen snapshot
cca restore personal --dry-run           # shows what would be copied; changes nothing
cca autobackup on          # every day at 13:00 (off to stop, status to check)
```

`cca remove` and `cca login` take a backup first.

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

This logs the account out, drops its folder bindings, and moves its config folder, desktop data and launcher to the Trash (use Put Back to undo). Quit that account's Claude app first. For the default account only the login and launcher go; `~/.claude` stays.

## Troubleshooting

- `command not found: cca`: open a new terminal, or run `source ~/.zshrc`.
- After updating cca, open terminals pick up the new version by themselves on the next `cca` command.
- A desktop copy shows the wrong account: quit all Claude copies, open only that one, log out, then log in.
- Signing in picks the wrong Google account: type the email and use "Continue with email" instead of "Continue with Google".
- The terminal uses the wrong account: run `cca login <name>`.

## Tests

```sh
zsh tests/run.sh
```

## Disclaimer

The desktop part relies on undocumented app behavior. It may break after an app update.

Use cca to separate your own accounts. Follow your organization's policies. Do not use it to get around usage limits.

## License

MIT
