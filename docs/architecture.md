# Architecture

[← Back to README](../README.md)

CCA is a shell script (`cca.zsh` on macOS, `cca.ps1` on Windows) plus an optional Electron app that runs it. It has no server and no background service of its own, apart from the optional scheduled jobs you turn on.

## Accounts are configuration folders

Claude Code keeps its login, settings and conversations in a configuration folder, and reads the folder's location from the `CLAUDE_CONFIG_DIR` environment variable. CCA gives each account its own folder:

```text
~/.claude                         default account (named in ~/.claude-accounts/default-name)
~/.claude-accounts/
├── profiles/
│   ├── personal/                 CLAUDE_CONFIG_DIR for "personal"
│   └── acme/                     CLAUDE_CONFIG_DIR for "acme"
├── desktop/
│   ├── personal/                 Claude desktop app data for "personal"
│   └── acme/
├── bindings                      folder → account
├── default-name                  the default account's name
└── backups/                      snapshots
```

Because each folder has its own login, every account stays signed in. On macOS, Claude Code stores each folder's login in its own keychain entry.

## How `claude` picks an account

Loading CCA defines a `claude` function in your shell. When you run `claude`:

1. If `CLAUDECODE` is set (you are inside a Claude Code session), it runs the real `claude` unchanged, so a nested session keeps the parent's account.
2. Otherwise it resolves the account, first match wins:
   1. the account set with `cca use` in this terminal
   2. the closest folder at or above the current folder that is bound with `cca bind`
   3. the default account
3. It prints `claude account: <name> (<reason>)` to the terminal (unless `CCA_QUIET` is set).
4. It runs the real `claude` with `CLAUDE_CONFIG_DIR` set to the account's folder, or with `CLAUDE_CONFIG_DIR` removed for the default account.

`cca run <name>` skips step 2 and uses the named account.

The function exists only in shells that load CCA. Programs that start the `claude` binary directly do not go through it.

## Bindings

`~/.claude-accounts/bindings` has one line per bound folder: the absolute folder path, a tab, and the account name. On macOS, paths are resolved to their real location (symlinks followed) when you bind. When bound folders are nested, the longest matching path wins, so a client folder inside your work folder can use a different account.

Bindings store names, which is why the default account should be named before you bind anything: renaming it later leaves old bindings pointing at a name that no longer exists, and `claude` then stops with "account '…' does not exist".

## Shared files

These items in `~/.claude` are shared with every account, if they exist:

- `settings.json`
- `CLAUDE.md`
- `skills`
- `plugins`
- `agents`
- `commands`
- `output-styles`
- `keybindings.json`

CCA links each one into every account's folder: a symlink on macOS; a symlink, junction (folders) or hard link (files) on Windows. A plugin or skill installed from one account is therefore available in all of them.

The links are checked each time an account starts (`claude`, `cca run`, `cca open`, `cca add`): a missing link is added, so a file you add to `~/.claude` later reaches every account. **A file an account has of its own is kept and never replaced.**

To give one account its own copy, replace the link with a regular file. For example, on macOS:

```sh
cd ~/.claude-accounts/profiles/acme
ls -l settings.json                       # should show: settings.json -> /Users/you/.claude/settings.json
rm settings.json                          # removes the link only, not your real settings
cp ~/.claude/settings.json settings.json  # now acme has its own copy to edit
```

For a shared folder such as `skills`, remove the link without a trailing slash (`rm skills`). If you later delete the account's own copy, CCA links the shared one again on the next start.

Remember that `settings.json` can hold hooks, permissions and environment variables. While it is shared, those apply to every account.

## What stays separate

Everything Claude Code writes to an account's configuration folder stays with that account, including:

- the login
- conversation transcripts (`projects/`) and memory
- MCP servers added with `claude mcp add` (kept in the account's `.claude.json`)
- connector (MCP) sign-ins

In the Claude desktop app, each copy also keeps its own Chat tab skills and connectors set up on claude.ai, and its own desktop extensions.

## MCP servers for new accounts

When CCA creates an account, it copies the `mcpServers` (and `theme`) from the default account's `~/.claude.json` into the new account's `.claude.json`. If Claude Code wrote the account's `.claude.json` first, without an `mcpServers` key, CCA adds the key on the next `cca login` or `cca open`. An account that already has `mcpServers` keeps what it has. On macOS this needs jq; on Windows PowerShell does it.

The copy includes everything in those server definitions, including any API keys written into them. On macOS the new file is readable only by you.

## Desktop copies

`cca open <name>` starts the installed Claude desktop app with:

- `--user-data-dir=~/.claude-accounts/desktop/<name>`, so Electron keeps that copy's sign-in, settings and data apart
- `CLAUDE_CONFIG_DIR=~/.claude-accounts/profiles/<name>`, so its Code tab uses the account's configuration folder

Before starting it, CCA looks through the running processes for a Claude app started with that `--user-data-dir`. If one is running, it brings that window to the front instead of starting a second copy. The default account's copy is the one started without `--user-data-dir`.

On macOS, `cca app` builds a small AppleScript launcher in `~/Applications` that runs `cca open <name>`. It copies the Claude icon into it, optionally tints the icon with Core Image, and marks the launcher with `Contents/Resources/cca-account` so CCA only ever replaces or removes launchers it made. On Windows, `cca app` makes a Start menu shortcut that runs `cca open <name>` in a hidden PowerShell window.

## The CCA desktop app

The Electron app never reimplements CCA. For each action it runs the CLI as a child process with an argument list, never a shell command string:

- macOS: `zsh -f -c 'source "$CCA_HOME/cca.zsh" && cca "$@"'` with the arguments
- Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File cca-shim.ps1` with the arguments; the shim loads `cca.ps1` and runs one command

It reads `cca list --json` to draw the window. Commands that need the user (`cca add`, `cca login`, MCP sign-in) open in a real terminal window.

## Backups

See [backup-restore.md](backup-restore.md).

## File layout

### macOS

| Path | What it is |
|---|---|
| `~/.claude-accounts/cca.zsh` | The script, copied there by `install.sh` |
| `~/.claude-accounts/default-name` | The default account's name |
| `~/.claude-accounts/bindings` | Folder bindings |
| `~/.claude-accounts/profiles/<name>/` | Each account's configuration folder |
| `~/.claude-accounts/desktop/<name>/` | Each Claude app copy's data folder |
| `~/.claude-accounts/chrome-profiles` | The Chrome profile linked to each account |
| `~/.claude-accounts/chrome-profiles-seen` | Chrome's profile list as CCA last read it, for the desktop app |
| `~/.claude-accounts/backups/` | Backup snapshots, `backup.log` and `autobackup.log` |
| `~/.claude-accounts/app-state` | The Claude version and open copies `cca update` saw last |
| `~/.claude-accounts/autoupdate.log` | The autoupdate log |
| `~/Applications/Claude <Name>.app` | Launchers made by `cca app` |
| `~/Library/LaunchAgents/dev.cca.backup.plist` | The daily backup job, while autobackup is on |
| `~/Library/LaunchAgents/dev.cca.update.plist` | The autoupdate job, while autoupdate is on |
| `~/.zshrc` | One line that loads `cca.zsh` |

### Windows

| Path | What it is |
|---|---|
| `~\.claude-accounts\cca.ps1` | The script |
| `~\.claude-accounts\default-name`, `bindings` | Same as on macOS |
| `~\.claude-accounts\profiles\<name>\` | Each account's configuration folder |
| `~\.claude-accounts\desktop\<name>\` | Each Claude app copy's data folder |
| `~\.claude-accounts\colors\<name>.txt`, `icons\<name>.ico` | Each account's colour and tinted icon |
| `~\.claude-accounts\backups\` | Backup snapshots and `backup.log` |
| Start menu `Programs\cca\Claude <Name>.lnk` | Launchers made by `cca app` |
| Task Scheduler task `cca-backup` | The daily backup job, while autobackup is on |
| PowerShell profile(s) | One line that loads `cca.ps1` |
