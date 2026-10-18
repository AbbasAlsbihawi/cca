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
| `cca list` | list accounts with their emails |
| `cca app <name>` | make a 'Claude <Name>' app in ~/Applications for that account |
| `cca open <name>` | open the Claude app for an account (or bring it to the front) |

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

Clicking the launcher opens that account's copy of the Claude app, or brings it to the front. It never opens a second copy on the same data.

First sign-in:

1. Quit every Claude window (Cmd+Q).
2. Open only the new one, and sign in.
3. Reopen the others.

The sign-in link returns through `claude://`. If two copies are open, it can reach the wrong one.

macOS asks once for permission to let the launcher control System Events. Allow it. The launcher uses this to bring the right window forward.

Each desktop copy uses its own data folder, `~/.claude-accounts/desktop/<name>`. Its Code tab uses the config folder of that account.

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
- `~/Applications/Claude <Name>.app`: desktop launchers
- one line in `~/.zshrc` that loads `cca.zsh`

## Troubleshooting

- `command not found: cca`: open a new terminal, or run `source ~/.zshrc`.
- A desktop copy shows the wrong account: quit all Claude copies, open only that one, log out, then log in.
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
