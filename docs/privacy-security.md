# Privacy and security

[← Back to README](../README.md)

CCA organizes several Claude accounts on one computer. This page explains what it stores, what it shares between accounts, and what it does not protect against.

## What stays local

- CCA has no server, no account system and no telemetry.
- The CLI (`cca.zsh`, `cca.ps1`) makes no network requests of its own. Signing in, and everything Claude does, is handled by Claude Code and the Claude desktop app.
- The CCA desktop app contacts GitHub (the releases of this repository) to check for and download its own updates.
- Opening Chrome with `cca chrome` only starts Chrome in a profile. CCA reads Chrome's list of profiles and changes nothing in Chrome or in the Claude in Chrome extension.

## What CCA reads and writes

- **Logins.** Claude Code stores each account's login for its own configuration folder; on macOS each account gets its own keychain entry. CCA does not read, copy or store login tokens.
- **Account details.** To show who is signed in, CCA reads the email address, organization name and account ID that Claude Code saves in each account's `.claude.json`. On Windows it also asks `claude auth status`.
- **Its own files.** CCA writes its own configuration (bindings, default account name, Chrome profile links, colours) and the per-account folders under `~/.claude-accounts`. On macOS, `~/.claude-accounts`, the account folders and the backups folder are made readable only by you.
- **Shell startup.** The installers add one line to `~/.zshrc` (macOS) or your PowerShell profile (Windows), after saving a backup copy of the file.

Full file list: [Architecture → File layout](architecture.md#file-layout).

## What is shared between accounts

These files in `~/.claude` are linked into every account: `settings.json`, `CLAUDE.md`, `skills`, `plugins`, `agents`, `commands`, `output-styles` and `keybindings.json`.

That means, while they are shared:

- hooks, permission rules and environment variables in `settings.json` apply to every account
- the instructions in `CLAUDE.md` reach every account
- every installed plugin and skill runs for every account

New accounts also get a copy of the default account's MCP server definitions, including any API keys or tokens written into them.

If an account must not share one of these (for example, a client account that must not see your personal instructions or hooks), give it its own copy: see [Shared files](architecture.md#shared-files).

## What stays separate

Each account keeps its own login, conversation transcripts, memory, MCP sign-ins and MCP servers added with `claude mcp add`. Each Claude app copy keeps its own data folder.

## What backups contain

Backups are unencrypted local copies of every account's conversation transcripts and Code tab session lists, plus CCA's bindings and settings. Conversations can contain source code, file contents and anything pasted into a chat, so treat `~/.claude-accounts/backups` as sensitive. Backups do not contain logins or tokens. Details: [backup-restore.md](backup-restore.md).

## What CCA does not protect against

CCA is an organizing tool, **not a security boundary**:

- All accounts run as your operating system user. Any program running as you, including Claude Code itself and anything it runs, can read every account's folder and every backup.
- Shared files (above) carry settings, hooks and instructions across accounts unless you unshare them.
- CCA does not encrypt anything.

If you need strong separation between clients, use separate operating system users or separate machines.

## Desktop app builds

The CCA desktop app is not signed with a paid developer certificate. macOS and Windows warn on first launch, and you have to allow it once. The source of every build is in this repository; you can read it, or build the app yourself (see [Development](development.md)). On Windows, the app runs its bundled PowerShell script with `-ExecutionPolicy Bypass` for that one script, so a restrictive execution policy does not block it.

## Account policies

- Use CCA to separate accounts that are yours to use.
- Follow Anthropic's terms and your employer's or clients' policies about which accounts may be used for which work, and about where code and conversations may be stored.
- CCA is not a way to get around usage limits, quotas or organizational controls.

## Reporting a security problem

See [SECURITY.md](../SECURITY.md). Please report security problems privately, not in a public issue.
