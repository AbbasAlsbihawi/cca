# CLI reference

[← Back to README](../README.md)

Every command below works on macOS (`cca.zsh`) and Windows (`cca.ps1`) unless it says otherwise. Run `cca help` for the built-in summary.

- [How `claude` picks an account](#how-claude-picks-an-account)
- [Account names](#account-names)
- [Accounts](#accounts): `cca`, `list`, `add`, `login`, `remove`
- [Choosing an account](#choosing-an-account): `use`, `bind`, `unbind`, `run`
- [Claude desktop app](#claude-desktop-app): `app`, `open`, `update`, `autoupdate`
- [Claude in Chrome](#claude-in-chrome): `chrome`
- [Backups](#backups): `backup`, `restore`, `autobackup`, `import`
- [Environment variables](#environment-variables)

## How `claude` picks an account

CCA replaces the `claude` command in your shell with a small function. Each time you run `claude`, the first match wins:

1. `cca use <name>` in this terminal
2. a folder bound with `cca bind`: the closest bound folder at or above the current folder
3. the default account (`~/.claude`)

The function then runs the real `claude` with that account's configuration folder. It prints a dim line such as `claude account: personal (folder /Users/you/code/personal)` first; set `CCA_QUIET=1` to hide it.

Inside a Claude Code session (when `CLAUDECODE` is set), `claude` keeps the account of that session.

The wrapper exists only in shells that load CCA: interactive zsh on macOS, and PowerShell with the profile line on Windows. A program that starts the `claude` binary directly does not see `cca use` or folder bindings. Use `cca run <name>` there, or set `CLAUDE_CONFIG_DIR` yourself.

## Account names

Names use lowercase letters, digits, `-` and `_`, and start with a letter or digit: `work`, `personal`, `client-acme`, `acme_2`. The default account's name is the content of `~/.claude-accounts/default-name`, or `default` when that file does not exist.

## Accounts

### `cca` (or `cca status`)

Shows the account used in the current folder and why, every account with its email and organization, and every bound folder. The account used here is marked with `*`.

```text
Here: personal  (folder /Users/you/projects/side-project)

Accounts:
  work           you@company.example  (Company)
* personal       you@example.com

Folders:
  /Users/you/projects/side-project -> personal
```

### `cca list [--json]` (or `cca ls`)

Lists the accounts with their emails. An account that is not signed in shows `not logged in`. On macOS, emails are read with jq; without jq every account shows `not logged in`. On Windows, `cca list` also asks Claude Code (`claude auth status`) whether each account is really signed in.

`--json` prints one JSON object for scripts and the desktop app: a `version` number, the default account name, the available icon colours, whether autobackup and autoupdate are on, the backup snapshots, the Chrome profiles (macOS) and, for each account, its name, email, organization, sign-in state, colour, launcher, linked Chrome profile, whether its Claude app copy is running, and its bound folders. The `version` field changes if the format does.

### `cca add <name> [options]`

Creates an account and starts the sign-in in your browser.

```sh
cca add personal
cca add personal --email you@example.com   # fill in the email on the sign-in page
cca add acme --sso                         # force the SSO sign-in flow
```

Options are passed to `claude auth login`, so any option your Claude Code version accepts works. `--email` and `--sso` are the common ones.

`cca add` creates `~/.claude-accounts/profiles/<name>`, links the [shared files](architecture.md#shared-files) into it, copies the default account's MCP servers and theme into it (macOS needs jq), and signs in. It fails if the account already exists; use `cca login` for that.

If the browser is already signed in to another Claude account, switch accounts there or use a private window.

### `cca login <name> [options]`

Signs an existing account in again, for example when the login expired or the wrong account was used. It takes the same options as `cca add`. While [autobackup](#cca-autobackup-onoffstatus) is on, it takes a backup first.

### `cca remove <name>` (or `cca rm`)

Logs the account out, drops its folder bindings and Chrome profile link, and moves its configuration folder, desktop data and launcher to the Trash (the Recycle Bin on Windows), so it can be undone. While autobackup is on, it takes a backup first.

Quit that account's Claude app copy first; `cca remove` refuses while it is open. For the default account, only the login and the launcher go; `~/.claude` and its settings stay.

## Choosing an account

### `cca use <name>`

Uses an account in this terminal only, until you close it or stop:

```sh
cca use personal    # this terminal now uses personal
cca use             # show what this terminal uses
cca use -           # stop; follow folder bindings again (cca use off does the same)
```

`cca use` wins over folder bindings.

### `cca bind <name> [folder]`

Makes a folder and all its subfolders use an account. The folder defaults to the current one.

```sh
cca bind personal                    # the current folder
cca bind acme ~/clients/acme         # another folder
```

Binding a folder again replaces its old binding. When folders are nested, the closest bound folder wins. Bindings are saved in `~/.claude-accounts/bindings`.

### `cca unbind [folder]`

Removes the binding on exactly this folder (default: the current one). If the folder only inherits a binding from a parent, `cca unbind` says which folder to unbind instead.

### `cca run <name> [claude arguments]`

Runs `claude` once with an account, whatever the bindings say. Everything after the name goes to `claude`:

```sh
cca run personal
cca run acme --continue
```

`cca run` also works where the `claude` wrapper is not loaded, which makes it the way to use a specific account from scripts.

## Claude desktop app

See [desktop.md](desktop.md) for how these fit together.

### `cca app <name> [color]`

Makes a launcher that opens the Claude desktop app for one account:

- **macOS:** `~/Applications/Claude <Name>.app`, with the Claude icon. Drag it to the Dock.
- **Windows:** a Start menu shortcut, `Claude <Name>`.

Colours: `red`, `orange`, `yellow`, `green`, `teal`, `blue`, `purple`, `pink`, `gray`.

```sh
cca app personal            # plain Claude icon
cca app personal purple     # tinted icon
cca app personal            # later: keeps the saved colour
```

An unknown colour is an error and changes nothing. If the icon cannot be tinted, you get a warning and the plain icon. On macOS, `cca app` refuses to replace an app with the same name that it did not make. If the account does not exist yet, `cca app` creates its folder without signing in.

### `cca open <name>`

Opens the Claude desktop app for an account, or brings its window to the front if it is already open. It never starts a second copy on the same data folder. For the default account it opens the normal Claude app.

On macOS, bringing a window forward uses System Events; allow it once when macOS asks.

### `cca update` (macOS)

Quits every open Claude app copy, as Cmd+Q does, and opens it again, so each one runs the version installed in `/Applications/Claude.app`. If work is running, Claude may ask before quitting. This command restarts Claude app copies; it does **not** update CCA itself (see [Installation](installation.md#update-the-cli)).

### `cca autoupdate on|off|status` (macOS)

`on` adds a launchd job that runs once a minute and whenever `/Applications` changes. After the Claude app updates, it restarts every copy that was open, reopens copies that closed for the update, and closes the default copy that the Claude updater opened in their place. The log is `~/.claude-accounts/autoupdate.log`. `off` removes the job; `status` shows whether it is on and the installed Claude version.

## Claude in Chrome

### `cca chrome [<name> [<profile>|--unlink]]` (macOS)

The Claude in Chrome extension signs in once per Chrome profile, so each account can have a profile of its own.

```sh
cca chrome                    # list Chrome's profiles and the accounts linked to each
cca chrome acme Work          # link acme to the profile Chrome shows as "Work"
cca chrome acme "Profile 3"   # or use the profile's folder name
cca chrome acme               # open Chrome in acme's profile
cca chrome acme --unlink      # drop the link
```

Needs jq and Google Chrome in `/Applications`. Details: [desktop.md](desktop.md#claude-in-chrome-per-account).

## Backups

See [backup-restore.md](backup-restore.md) for what is saved and how restore decides what to copy.

### `cca backup [--quiet|list]`

```sh
cca backup            # take a snapshot now
cca backup --quiet    # the same, without the summary line
cca backup list       # snapshot names, newest first
```

### `cca restore <name> [snapshot] [-n|--dry-run] [--account <uuid>]`

Brings an account's conversations back from the newest snapshot that has the account, or from the snapshot you name. It never overwrites a file. Quit that account's Claude app copy first.

```sh
cca restore personal
cca restore personal 2026-05-01_130000
cca restore personal --dry-run            # show what would be copied; change nothing
cca restore personal --account <uuid>     # say which Claude account its sessions belong to
```

On Windows, `cca restore` takes only `<name>` and `[snapshot]`: there is no dry run and no `--account`.

### `cca autobackup on|off|status`

A daily backup at 13:00. A missed run happens at the next wake (macOS) or the next start (Windows). macOS uses a launchd job (`~/Library/LaunchAgents/dev.cca.backup.plist`); Windows uses a Task Scheduler task named `cca-backup`.

### `cca import` (macOS)

The older name of `cca restore`. On Windows it prints that it is not available; use `cca restore`.

## Environment variables

| Variable | Platform | Purpose |
|---|---|---|
| `CCA_QUIET` | both | Set to any value to hide the `claude account: ...` line. |
| `CCA_BACKUP_KEEP` | both | How many snapshots to keep (default 30). |
| `CCA_ACCOUNT` | macOS | The account `cca use` sets. When it is exported before zsh starts, that shell uses the account; the desktop app's *New Terminal* works this way. On Windows, `cca use` keeps the account in a PowerShell variable, and an environment variable with this name is not read. |
| `CCA_CLAUDE_EXE` | Windows | Path to the Claude desktop app's `Claude.exe`, when it is not in a usual install folder. |
| `CCA_HOME` | both | Where CCA keeps its data (default `~/.claude-accounts`). |

Mainly for tests and unusual setups:

| Variable | Platform | Default |
|---|---|---|
| `CCA_CLAUDE_APP` | macOS | `/Applications/Claude.app` |
| `CCA_MAIN_DIR` | both | `~/.claude` |
| `CCA_MAIN_JSON` | both | `~/.claude.json` |
| `CCA_MAIN_APP_DATA` | both | `~/Library/Application Support/Claude` (macOS), `%APPDATA%\Claude` (Windows) |
| `CCA_LAUNCH_AGENTS` | macOS | `~/Library/LaunchAgents` |
| `CCA_CHROME_APP` | macOS | `/Applications/Google Chrome.app` |
| `CCA_CHROME_DATA` | macOS | `~/Library/Application Support/Google/Chrome` |
| `CCA_LAUNCHERS` | Windows | the Start menu `Programs\cca` folder |
| `CCA_TRASH` | both | unset: removals go to the Trash or Recycle Bin; set: to this folder instead |
