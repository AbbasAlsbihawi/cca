# Security policy

## Supported versions

CCA is published as versions `0.x` from the `main` branch, and fixes ship in the next release. There are no backports to older versions. Use the latest [release](https://github.com/AbbasAlsbihawi/cca/releases/latest), or the latest `main` if you installed the CLI from a clone.

## Reporting a vulnerability

Please report security problems privately, not in a public issue.

1. Use GitHub's private vulnerability reporting: open the repository's **Security** tab and choose **Report a vulnerability**.
2. If that option is not available, open a regular issue titled "Security contact request", with no details of the problem. The maintainer will reply with a private way to send the report.

Please do not disclose the problem publicly until a fix is released or we have agreed on a disclosure date. This is a volunteer project, so responses are best effort and no response time is guaranteed.

## What to include

- what the problem is and what an attacker could do with it
- the steps to reproduce it, ideally on a test account or a throwaway setup
- your platform (macOS or Windows and its version) and the CCA version: the output of `cca --version` (or, for 0.1.12 and older, the release tag or the commit of your clone), and the desktop app version from its General page
- whether you have a fix in mind

Do **not** send credentials, tokens, cookies, keychain items, the contents of `.claude.json` or `.credentials` files, conversation transcripts or real account emails. Replace them with placeholders. If a log is needed, remove those values first.

## What counts as a vulnerability

Examples of problems we want to hear about:

- an account name, folder path, Chrome profile name or snapshot name that makes CCA run unintended commands or touch files outside its folders
- CCA deleting or overwriting user data, despite its rule that removals go to the Trash or Recycle Bin and that restore never overwrites
- login tokens or other secrets ending up in backups, logs or files readable by other users
- the desktop app's update process accepting a file that is not the published release
- the installers changing shell profiles or other files in an unsafe way

Not vulnerabilities, because they are how CCA is designed and are documented in [docs/privacy-security.md](docs/privacy-security.md):

- CCA is **not a security boundary**. Every account runs as your operating system user, and any program running as you can read every account's folder and every backup.
- `settings.json`, `CLAUDE.md`, skills, plugins and the other [shared files](docs/architecture.md#shared-files) are shared by every account unless you unshare them, including any hooks, permissions and environment variables in `settings.json`.
- New accounts get a copy of the default account's MCP server definitions, which can contain API keys or tokens.
- Local backups are **not encrypted**. They hold conversation transcripts, which can contain source code and anything pasted into a chat.
- The desktop app builds are not signed with a paid developer certificate.

Problems in Claude Code or the Claude desktop app themselves should be reported to Anthropic, not here.

## Protecting your own setup

- Treat `~/.claude-accounts` (and especially `~/.claude-accounts/backups`) as sensitive, like your home folder.
- Keep your computer's disk encrypted (FileVault or BitLocker) and your user account locked when you are away.
- Review the hooks and environment variables in `~/.claude/settings.json` knowing that they apply to every account that shares it.
- Remove API keys from MCP server definitions you do not want copied into new accounts.

More detail: [docs/privacy-security.md](docs/privacy-security.md).
