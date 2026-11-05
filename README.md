# CCA — Claude Accounts

**One workflow. Multiple Claude accounts.**

Manage multiple Claude accounts across the Claude Code CLI, the Claude desktop app, and your projects, without constant sign-outs.

[![Latest release](https://img.shields.io/github/v/release/AbbasAlsbihawi/cca)](https://github.com/AbbasAlsbihawi/cca/releases/latest)
[![Tests](https://github.com/AbbasAlsbihawi/cca/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/AbbasAlsbihawi/cca/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

CCA is a free, open-source command-line tool for macOS and Windows, with an optional desktop app. It gives each Claude account its own configuration folder, so your personal, work and client accounts all stay signed in at the same time. Bind a project folder to an account once, and `claude` uses that account every time you work there.

> CCA is an independent community project. It is not affiliated with, endorsed by or supported by Anthropic.

[Install](#install) · [Quick start](#quick-start) · [Commands](#commands) · [Desktop app](#desktop-app) · [Platform support](#platform-support) · [Documentation](#documentation) · [Releases](https://github.com/AbbasAlsbihawi/cca/releases)

<!-- Phase 4: add a short terminal demo here (assets/demo/cca-demo.gif) once a real recording exists. -->

## Why CCA

Many developers keep more than one Claude account: a personal one, one from their employer, and sometimes one per client. Claude Code and the Claude desktop app are signed in to one account at a time, so switching usually means logging out, logging back in, and checking that the next session runs on the right account.

CCA removes that step:

- **Every account stays signed in.** Switching is a command, not a login.
- **Projects pick their own account.** Bind a folder to an account, and work code runs on the work account while client code runs on that client's account.
- **Desktop copies run side by side.** Each account can have its own copy of the Claude desktop app, open at the same time as the others.

## Features

| Feature | What it does | Platforms |
|---|---|---|
| Multiple accounts | Each account gets its own Claude Code configuration folder and its own login. | macOS, Windows |
| Terminal switching | `cca use <name>` picks an account for one terminal. `cca run <name>` uses it for a single run. | macOS, Windows |
| Project binding | `cca bind <name>` makes a folder and all its subfolders use an account. | macOS, Windows |
| Shared setup | `settings.json`, `CLAUDE.md`, skills, plugins, agents, commands, output styles and key bindings are linked from your default account, so you set them up once. | macOS, Windows |
| MCP servers | A new account starts with the MCP servers of your default account. Each account keeps its own MCP sign-ins. | macOS (needs `jq`), Windows |
| Claude desktop app per account | `cca app <name> [color]` makes a launcher that opens the Claude desktop app with that account's own data folder, with an optional tinted icon. | macOS, Windows |
| Backup and restore | `cca backup` takes a snapshot of every account's local Claude Code conversations. `cca restore` brings back what is missing and never overwrites a file. Optional daily backup. | macOS, Windows |
| Claude in Chrome per account | `cca chrome` links each account to its own Chrome profile. | macOS |
| Restart after Claude app updates | `cca update` and `cca autoupdate` restart every open copy of the Claude desktop app on the newly installed version. | macOS |
| Claude Accounts app | A desktop app that does all of the above with buttons, plus a menu bar or tray menu. It updates itself. | macOS, Windows |

Shared versus separate: settings, `CLAUDE.md`, skills and plugins are **shared** by every account. Logins, chat history, memory, MCP sign-ins and MCP servers added with `claude mcp add` stay **separate** per account. See [How it works](#how-it-works).

## Install

### macOS

Requirements: macOS with zsh (the default shell), [Claude Code](https://code.claude.com/docs/en/overview) (`claude`), and [jq](https://jqlang.org) (recommended: `brew install jq`). Without jq, CCA cannot show account emails, copy MCP servers into new accounts, or link Chrome profiles.

```sh
git clone https://github.com/AbbasAlsbihawi/cca.git
cd cca
./install.sh
```

Then open a new terminal, or run `source ~/.zshrc`.

### Windows

Requirements: Windows PowerShell 5.1 or PowerShell 7, and Claude Code.

```powershell
git clone https://github.com/AbbasAlsbihawi/cca.git
cd cca
.\install.ps1
```

Then open a new PowerShell window. If PowerShell blocks your profile script, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once.

### Desktop app (optional)

Download the Claude Accounts app from [GitHub Releases](https://github.com/AbbasAlsbihawi/cca/releases/latest): `ClaudeAccounts-<version>-arm64-mac.dmg` (Apple silicon), `ClaudeAccounts-<version>-x64-mac.dmg` (Intel Mac) or `ClaudeAccounts-Setup-<version>.exe` (Windows x64). On macOS, install the CLI first. The builds are not signed with a paid developer certificate, so the first launch needs one extra step; see [docs/desktop.md](docs/desktop.md#install).

Updating, uninstalling and removing data: [docs/installation.md](docs/installation.md).

## Quick start

1. **Name your current login first**, before you bind any folder. Bindings store account names, and your existing login is called `default` until you name it.

   ```sh
   echo work > ~/.claude-accounts/default-name                   # macOS
   ```

   ```powershell
   Set-Content "$HOME\.claude-accounts\default-name" work          # Windows
   ```

2. **Add a second account.** This opens the browser to sign in.

   ```sh
   cca add personal --email you@example.com
   ```

   If the browser is already signed in to another Claude account, switch accounts there or use a private window.

3. **Bind a project folder** to an account.

   ```sh
   cd ~/projects/side-project
   cca bind personal
   ```

4. **Switch for one terminal, or for one run.**

   ```sh
   cca use personal     # this terminal only
   cca use -            # stop; follow folder bindings again
   cca run personal     # one claude run on this account
   ```

5. **Check which account is active.**

   ```sh
   cca
   ```

   ```text
   Here: personal  (folder /Users/you/projects/side-project)

   Accounts:
     work           you@company.example  (Company)
   * personal       you@example.com

   Folders:
     /Users/you/projects/side-project -> personal
   ```

`claude` also prints a dim `claude account: ...` line before it starts. Set `CCA_QUIET=1` to hide it.

## Real-world examples

**Personal projects.** Keep side projects on your own subscription.

```sh
cca add personal
cca bind personal ~/code/personal
cca app personal green          # macOS: a "Claude Personal" launcher with a green icon
```

**Work projects.** If you named your existing login `work` in step 1, there is nothing else to do: any folder without a binding uses the default account. To make it explicit, bind the folder anyway with `cca bind work ~/work`.

**Client projects.** Give each client its own account, sign-in method and browser profile.

```sh
cca add acme --sso              # the client's SSO sign-in
cca bind acme ~/clients/acme
cca app acme orange             # macOS: "Claude Acme", orange icon
cca chrome acme "Acme"          # macOS: link the Chrome profile named "Acme"
```

Every account shares your default account's `settings.json`, `CLAUDE.md`, skills and plugins. If a client needs a different setup, see [Shared files](docs/architecture.md#shared-files).

## Commands

| Command | What it does |
|---|---|
| `cca` | Show the account used here, all accounts and bound folders. |
| `cca add <name> [opts]` | Create an account and log in (`--email you@example.com`, `--sso`). |
| `cca login <name> [opts]` | Log in again (expired, or the wrong account). |
| `cca use <name>` | Use an account in this terminal (`cca use -` to stop). |
| `cca bind <name> [folder]` | Always use an account in a folder and its subfolders. |
| `cca unbind [folder]` | Remove a folder binding. |
| `cca run <name> [args]` | Run `claude` once with an account. |
| `cca list [--json]` | List accounts with their emails (`--json` for scripts and the desktop app). |
| `cca app <name> [color]` | Make a "Claude &lt;Name&gt;" launcher for the account's Claude desktop app, with an optional coloured icon. |
| `cca open <name>` | Open the Claude desktop app for an account, or bring it to the front. |
| `cca chrome [<name> [<profile>\|--unlink]]` | List Chrome profiles, link one to an account, or open Chrome in it (macOS). |
| `cca remove <name>` | Log an account out and move its folders and launcher to the Trash (Recycle Bin on Windows). |
| `cca backup [--quiet\|list]` | Save every account's conversations; `list` shows the snapshots. |
| `cca restore <name> [snapshot] [-n] [--account <uuid>]` | Bring an account's conversations back, never overwriting anything (`-n` and `--account`: macOS only). |
| `cca autobackup on\|off\|status` | A daily backup at 13:00. |
| `cca update` | Quit and reopen every open Claude app copy so each runs the installed version (macOS). |
| `cca autoupdate on\|off\|status` | Do that automatically after the Claude app updates (macOS). |
| `cca help` | Show the built-in help. |

Which account `claude` uses, first match wins:

1. `cca use <name>` in this terminal
2. a folder bound with `cca bind`: the closest bound folder at or above the current one
3. the default account (`~/.claude`)

Inside a Claude Code session, `claude` keeps the account of that session. Full reference with options, examples and environment variables: [docs/cli-reference.md](docs/cli-reference.md).

## Desktop app

CCA works with the Claude desktop app in two ways:

- **A Claude app copy per account.** `cca app personal` makes `~/Applications/Claude Personal.app` (a Start menu shortcut on Windows). It opens the Claude desktop app with its own data folder, `~/.claude-accounts/desktop/personal`, so every account stays signed in to the app at once. The first sign-in needs all other Claude windows closed, because the sign-in link returns through `claude://`.
- **The Claude Accounts app.** A window laid out like macOS System Settings, with your accounts in a sidebar. For each account you can open its Claude app, pick an icon colour, open a terminal on it, log in again, sign in to MCP servers, pick a Chrome profile, bind folders, restore conversations or remove it. The General page handles backups, autobackup and updates. A menu bar (macOS) or tray (Windows) menu stays available when the window is closed.

The app calls the `cca` CLI for everything, so the terminal and the app always agree. It relies on undocumented Claude desktop app behaviour and may break after a Claude app update. Details, first sign-in steps and limitations: [docs/desktop.md](docs/desktop.md).

<!-- Phase 4: add a real screenshot of the Claude Accounts app here (assets/screenshots/desktop.png). -->

## How it works

- **One configuration folder per account.** Claude Code reads its settings and login from the folder in `CLAUDE_CONFIG_DIR`. CCA keeps each extra account in `~/.claude-accounts/profiles/<name>`. Your default account stays in `~/.claude`.
- **A `claude` wrapper.** CCA defines `claude` as a shell function (zsh or PowerShell). It works out which account applies, then runs the real `claude` with that account's folder.
- **Shared files are links.** Shared items in `~/.claude` are linked into every account's folder: symlinks on macOS; symlinks, junctions or hard links on Windows. A missing link is added each time an account starts, and a file an account has of its own is kept.
- **Desktop copies.** `cca open` starts the Claude desktop app with `--user-data-dir` pointing at the account's data folder and `CLAUDE_CONFIG_DIR` pointing at its config folder.
- **Backups are local copies.** Snapshots go to `~/.claude-accounts/backups/` (APFS clones on macOS, plain copies on Windows).

Architecture and file layout: [docs/architecture.md](docs/architecture.md). Backups in detail: [docs/backup-restore.md](docs/backup-restore.md).

## Privacy and security

- **Local only.** CCA has no server, no account system and no telemetry. The CLI makes no network requests of its own; signing in is done by Claude Code. The desktop app contacts GitHub to check for its own updates.
- **Logins stay with Claude Code.** Each account's login is stored by Claude Code for that configuration folder; on macOS each account gets its own keychain entry. CCA reads only the email, organization and account ID that Claude Code saves, and never copies login tokens into backups.
- **Shared settings apply to every account.** Hooks, permissions and environment variables in `settings.json`, plus `CLAUDE.md`, skills and plugins, reach every account. MCP server definitions, including any keys written in them, are copied from the default account into new accounts.
- **Not a security boundary.** All accounts run as your operating system user, and any program running as you can read every account's folder and backups. CCA keeps accounts organized; it does not isolate them from each other.
- **Unsigned desktop builds.** Your operating system warns on first launch. Build from source if you prefer.
- **Use your own accounts.** Follow Anthropic's terms and your organization's policies. CCA is not a way to get around usage limits.

More detail: [docs/privacy-security.md](docs/privacy-security.md). Security policy: [SECURITY.md](SECURITY.md).

## Platform support

| Area | macOS | Windows |
|---|---|---|
| CLI: accounts, `use`, `bind`, `run`, `list`, `remove` | Supported | Supported |
| Backup, restore, daily autobackup | Supported | Supported; `restore` has no `--dry-run` or `--account` |
| Claude app copy per account (`cca app`, `cca open`) | Supported | Supported |
| Claude Accounts app | Supported (Apple silicon and Intel) | Supported (x64) |
| Claude Accounts app self-update | Supported | Supported |
| Claude in Chrome per account (`cca chrome`) | Supported | Not available |
| Restart after Claude app updates (`cca update`, `cca autoupdate`) | Supported | Not available |
| Linux | Not supported | — |

Evidence behind each status and the full list of differences: [docs/platform-support.md](docs/platform-support.md).

## Troubleshooting

- **`command not found: cca`**: open a new terminal, or run `source ~/.zshrc`.
- **`cca list` says "not logged in" for every account (macOS)**: install jq (`brew install jq`).
- **The terminal uses the wrong account**: run `cca` to see why, then `cca login <name>` if the login itself is wrong.
- **A desktop copy shows the wrong account**: quit every Claude copy, open only that one, log out, then log in.
- **Signing in picks the wrong Google account**: type the email and use "Continue with email" instead of "Continue with Google".

More: [docs/troubleshooting.md](docs/troubleshooting.md).

## Documentation

| Guide | Contents |
|---|---|
| [Installation](docs/installation.md) | Requirements, install, update and uninstall on macOS and Windows, the desktop app |
| [CLI reference](docs/cli-reference.md) | Every command, option and environment variable |
| [Desktop](docs/desktop.md) | Claude app copies per account, the Claude Accounts app, Claude in Chrome, Claude app updates |
| [Architecture](docs/architecture.md) | How accounts, links, bindings and desktop copies work; file layout |
| [Backup and restore](docs/backup-restore.md) | Snapshots, restore, autobackup |
| [Privacy and security](docs/privacy-security.md) | What stays local, what is shared, what backups hold |
| [Platform support](docs/platform-support.md) | What is supported and tested on each platform |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and fixes |
| [Development](docs/development.md) | Repository layout, tests and releasing |

## Contributing

Bug reports, ideas and pull requests are welcome in [GitHub Issues](https://github.com/AbbasAlsbihawi/cca/issues). Contributions from Windows users are especially welcome: the Windows port and several Windows fixes came from contributors. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to set up, test and open a pull request. Report security problems privately as described in [SECURITY.md](SECURITY.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Disclaimer

CCA is an unofficial project and is not affiliated with Anthropic. "Claude" and "Claude Code" are names of Anthropic products, used here only to describe what CCA works with. The desktop features rely on undocumented behaviour of the Claude desktop app and may break after an update.

Use CCA to separate your own accounts. Follow your organization's policies, and do not use it to get around usage limits.

## License

[MIT](LICENSE) © 2026 Abbas Alsbihawi
