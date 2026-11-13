# Troubleshooting

[← Back to README](../README.md)

Start with `cca`: it shows which account applies in the current folder and why.

## Installation

**`command not found: cca` (macOS)**
Open a new terminal, or run `source ~/.zshrc`. If it still fails, check that `~/.zshrc` has the line that loads `~/.claude-accounts/cca.zsh`, and run `./install.sh` again.

**`cca` is not recognized (Windows)**
Open a new PowerShell window. If PowerShell says running scripts is disabled, allow your own scripts once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

**"the 'claude' command was not found" (Windows)**
Install Claude Code first, then open a new PowerShell window.

**After updating CCA, a terminal still behaves the old way**
On macOS, open terminals load the new version on their next `cca` command. If you copied files by hand instead of running `./install.sh`, run it. On Windows, open a new PowerShell window.

## Accounts

**`cca list` shows "login unknown (install jq)" (macOS)**
Without jq, CCA reads emails with a simpler pattern, and this account's file did not fit it. Install jq with `brew install jq`.

**The terminal uses the wrong account**
Run `cca` to see the reason: `set in this terminal` (undo with `cca use -`), `folder …` (a binding; see `cca unbind`), or `default`. If the account is right but its login is wrong, run `cca login <name>`.

**"account '…' (…) does not exist"**
A binding or `cca use` points at a name that no longer exists, for example after you renamed the default account or removed an account. Bind the folder again with `cca bind <name>`, or run `cca use -`.

**Signing in picks the wrong Google account**
Type the email and use "Continue with email" instead of "Continue with Google". Or start the sign-in with the email filled in: `cca login <name> --email you@example.com`.

**The browser signs in to the wrong Claude account**
The browser is already signed in to another Claude account. Switch accounts in the browser, or use a private window, then run `cca login <name>` again.

## Claude desktop app copies

**A desktop copy shows the wrong account**
Quit every Claude copy, open only that one, log out, then log in.

**The sign-in link opened a different copy**
The link returns through `claude://`, which can reach any open copy. Quit every Claude window (Cmd+Q), open only the copy you are signing in, sign in, then reopen the others.

**An MCP server sign-in goes to the wrong copy**
Sign it in from the terminal instead: `cca run <name>`, then `/mcp`. The terminal sign-in returns to `localhost`, not `claude://`.

**"could not bring '…' to the front" (macOS)**
Allow the launcher, or your terminal, to control System Events in System Settings → Privacy & Security → Automation.

**Copies keep running the old Claude version after an update (macOS)**
Run `cca update` once, or `cca autoupdate on`. If restarts fail, allow control of Claude in System Settings → Privacy & Security → Automation.

**"could not find the Claude desktop app" (Windows)**
Set `CCA_CLAUDE_EXE` to the full path of the Claude app's `Claude.exe`.

## Claude in Chrome (macOS)

**"cca chrome needs jq"**
Install jq: `brew install jq`.

**The CCA desktop app does not list a new Chrome profile**
macOS does not let the app read Chrome's profile list. Run `cca chrome` once in Terminal; the app then uses the list CCA saved.

**"the Chrome profile '…' linked to '…' is gone"**
The profile was deleted in Chrome. Link another one: `cca chrome <name> <profile>`.

## Backups

**"the Claude app for '…' is open"**
`cca restore` and `cca remove` need that account's Claude app copy closed. Quit it with Cmd+Q and try again.

**"another backup is running"**
Wait for the other backup to finish. A lock left behind by a crash is cleared automatically after an hour.

**Restored conversations do not show up in the Code tab**
Quit the copy before restoring, then open it again. A session whose transcript is not on this computer is listed but cannot be opened.

## Desktop app

**macOS blocks the CCA desktop app on first launch**
The app is not signed with a paid developer certificate. Close the warning with *Done*, then open System Settings → Privacy & Security, scroll to Security and click *Open Anyway*, and enter your login password. The button stays for about an hour after the blocked attempt. Full steps: [First launch](desktop.md#first-launch).

**Windows SmartScreen blocks the installer**
Click *More info* → *Run anyway*. On the next page keep *Only for me* unless every user of the PC needs CCA. Full steps: [First launch](desktop.md#first-launch).

**The update says CCA is running from a disk image, or cannot update itself in a folder (macOS)**
CCA can only replace itself in a folder it can write to. Quit it, drag CCA into Applications with Finder, open it from there and click *Check Now*.

**Windows asks for administrator approval on every CCA update**
CCA is installed for everyone (in `C:\Program Files`), so each update needs that approval. To stop it, uninstall CCA and install it again with *Only for me*. Uninstalling keeps your accounts and settings.

**After choosing Later, the update installed when I quit, and CCA did not start again (Windows)**
That is expected. Open CCA from the Start menu; it is the new version.

**A command fails in the app**
A banner shows the error. Use *Show Activity* to see every command the app ran, with its output, and try the same command in a terminal.

## Uninstalling

**Errors keep appearing in `~/.claude-accounts/autoupdate.log` after uninstalling (macOS)**
`uninstall.sh` from CCA 0.1.12 or older left the autoupdate job behind. Reinstall with `./install.sh`, run `cca autoupdate off`, then uninstall again.
