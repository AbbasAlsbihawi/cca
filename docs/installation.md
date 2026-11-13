# Installation

[← Back to README](../README.md)

## Requirements

| | macOS | Windows |
|---|---|---|
| Shell | zsh (the default macOS shell) | Windows PowerShell 5.1 or PowerShell 7 |
| Claude Code | `claude` on your `PATH` ([install guide](https://code.claude.com/docs/en/overview)) | same |
| Claude desktop app | Only for the desktop features ([download](https://claude.com/download)), at `/Applications/Claude.app` | Only for the desktop features; see [Windows desktop notes](desktop.md#windows-notes) |
| jq | Recommended (`brew install jq`) | Not needed |
| Google Chrome | Only for `cca chrome` | Not used |

What jq does on macOS:

- `cca list`, `cca` and the desktop app read account emails with jq. Without it, CCA reads them with a simpler pattern; a login it cannot read that way shows as "login unknown (install jq)".
- New accounts get the default account's MCP servers and theme only when jq is installed.
- `cca chrome` needs jq to read Chrome's profile list.
- When `cca restore` copies sessions from the main Claude app, it reads them with jq, or with `python3` when jq is missing.

CCA does not support bash or fish on macOS: `install.sh` hooks into `~/.zshrc` only.

## macOS

### Install the CLI

```sh
git clone https://github.com/AbbasAlsbihawi/cca.git
cd cca
./install.sh
```

`install.sh`:

1. Copies `cca.zsh` to `~/.claude-accounts/cca.zsh` and makes `~/.claude-accounts` readable only by you.
2. Reads Chrome's profile list once and keeps a copy for the desktop app (see [Claude in Chrome](desktop.md#claude-in-chrome-per-account)).
3. Adds one line to `~/.zshrc` that loads `cca.zsh`, after saving a backup of `~/.zshrc` as `~/.zshrc.bak-cca-<timestamp>`. If the line is already there, it changes nothing.

Open a new terminal, or run `source ~/.zshrc`.

### Name your default account

Your existing Claude Code login (the folder `~/.claude`) becomes the default account. Give it a name before you bind any folder:

```sh
echo work > ~/.claude-accounts/default-name
```

Bindings are saved with account names. Until you name the default account it is called `default`, and if you rename it later, folders bound to the old name stop working until you bind them again.

### Update the CLI

```sh
cd cca
git pull
./install.sh
```

Running `install.sh` again replaces `~/.claude-accounts/cca.zsh` and leaves `~/.zshrc` alone. Terminals that are already open load the new version on their next `cca` command. Check it with `cca --version`.

### Uninstall

```sh
./uninstall.sh
```

`uninstall.sh`:

- removes the CCA lines from `~/.zshrc` (after saving a backup)
- deletes `~/.claude-accounts/cca.zsh`
- removes the daily backup and autoupdate jobs (`~/Library/LaunchAgents/dev.cca.backup.plist`, `dev.cca.update.plist`)
- deletes the launchers that `cca app` made in `~/Applications`
- deletes the CCA desktop app (`CCA.app`, or `Claude Accounts.app` for a copy updated from an older version) from `/Applications` or `~/Applications`, but only if its bundle identifier is `dev.cca.accounts`

It keeps your account data: `~/.claude-accounts` with every account's configuration, desktop data, bindings and backups. Keychain items named `Claude Code-credentials-<hash>` also stay; remove them in Keychain Access if you want.

To delete all account data as well, including every backup:

```sh
rm -rf ~/.claude-accounts
```

This cannot be undone. Your default account in `~/.claude` is not affected.

## Windows

### Install the CLI

```powershell
git clone https://github.com/AbbasAlsbihawi/cca.git
cd cca
.\install.ps1
```

`install.ps1`:

1. Copies `cca.ps1` to `~\.claude-accounts\cca.ps1`.
2. Adds one line that loads it to your PowerShell profile (`Documents\WindowsPowerShell\profile.ps1` for Windows PowerShell 5.1 and `Documents\PowerShell\profile.ps1` for PowerShell 7), for each shell that is installed. It saves a backup of each profile first, and skips a profile that already loads CCA.
3. Tells you if the execution policy blocks profile scripts.

Open a new PowerShell window. If PowerShell blocks your profile, allow your own scripts once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

For full symlink support, turn on Developer Mode in Windows settings. Without it, CCA falls back to junctions (folders) and hard links (files) for shared files.

### Name your default account

```powershell
Set-Content "$HOME\.claude-accounts\default-name" work
```

### Update the CLI

```powershell
cd cca
git pull
.\install.ps1
```

Then open a new PowerShell window, and check the version with `cca --version`.

### Uninstall

```powershell
.\uninstall.ps1
```

`uninstall.ps1` removes the profile lines (after saving backups), deletes `~\.claude-accounts\cca.ps1`, removes the `cca-backup` scheduled task and deletes the Start menu launchers folder made by `cca app`. Your accounts and backups stay in `~\.claude-accounts`. To delete them too:

```powershell
Remove-Item -Recurse -Force "$HOME\.claude-accounts"
```

This cannot be undone.

## The CCA desktop app

The desktop app is optional. Download it from [GitHub Releases](https://github.com/AbbasAlsbihawi/cca/releases/latest):

| Platform | File |
|---|---|
| macOS, Apple silicon | `CCA-<version>-arm64-mac.dmg` |
| macOS, Intel | `CCA-<version>-x64-mac.dmg` |
| Windows, x64 | `CCA-Setup-<version>.exe` |

- **macOS:** install the CLI with `./install.sh` first; the app runs `~/.claude-accounts/cca.zsh`.
- **Windows:** the installer carries its own copy of `cca.ps1` and puts it in `~\.claude-accounts` when it is missing. Run `.\install.ps1` as well if you want the `cca` command in PowerShell.

Releases before 0.2.0 called the app "Claude Accounts" and named their files `ClaudeAccounts-…`. An older copy updates itself to CCA. On a Mac it keeps the folder name `Claude Accounts.app`, and on Windows the program file stays `Claude Accounts.exe` for now. Your accounts and settings in `~/.claude-accounts` are not affected.

The builds are not signed with a paid developer certificate, so macOS and Windows warn the first time. Steps: [First launch](desktop.md#first-launch). How updates install: [Updates](desktop.md#updates).
