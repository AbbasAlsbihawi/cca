# Phase 1 report: product identity and README

Date: 2026-11-06 · Scope: documentation only · Status: complete, waiting for owner review. Nothing has been committed or pushed.

**Recommendation: READY for Phase 2**, after the owner reviews the diff and answers the open questions in [Owner decisions](#owner-decisions).

> **Update after owner review (2026-11-06):** the owner confirmed that Windows has been used on real installs by two contributors, who also sent Windows fixes ([#1](https://github.com/AbbasAlsbihawi/cca/pull/1), [#7](https://github.com/AbbasAlsbihawi/cca/pull/7), [#12](https://github.com/AbbasAlsbihawi/cca/pull/12)). Every Windows row that said "Experimental" now says "Supported" in the README and `docs/`. The tables below show the state when this report was written. The Windows *New Terminal* bug (9.2) still stands.

## 1. Audit

Read in full or in the relevant parts: `README.md`, `cca.zsh` (all 1,245 lines), `cca.ps1` (dispatch, help, `claude` wrapper, desktop, backup, restore, autobackup), `install.sh`, `install.ps1`, `uninstall.sh`, `uninstall.ps1`, `desktop/package.json`, the desktop main process (`main.js`, `cca.js`, `tray.js`, `menu.js`, `interactive.js`, `updater/*`, `cca-shim.ps1`), the renderer's visible labels, `desktop/scripts/*.sh`, `tests/run.sh`, `tests/run.ps1`, `.github/workflows/test.yml`, the GitHub releases, CI runs and repository metadata.

Git state before the work: branch `main`, clean working tree, at `cbaa3da` (release 0.1.12). No user changes needed preserving.

### Confirmed functionality (from source)

| Feature | macOS (`cca.zsh`) | Windows (`cca.ps1`) |
|---|---|---|
| Accounts as `CLAUDE_CONFIG_DIR` folders; `add`, `login`, `remove`, `list`, status | yes | yes |
| `claude` wrapper with order: `cca use` > closest folder binding > default; nested sessions keep their account | yes | yes |
| `use`, `bind`, `unbind`, `run` | yes | yes |
| Shared files linked from `~/.claude` (8 items), added at each start, own files kept | symlinks | symlink, junction or hard link |
| MCP servers and theme copied into new accounts | yes, needs jq | yes |
| `cca app` launcher with tinted icon (9 colours), `cca open` | yes | yes (Start menu shortcut) |
| `cca chrome` profile linking | yes | no |
| `cca update`, `cca autoupdate` (restart Claude app copies after a Claude app update) | yes | no |
| `backup` (+ `--quiet`, `list`), keep 30, lock, log | yes, APFS clones | yes, plain copies |
| `restore` | `[snapshot]`, `-n/--dry-run`, `--account` | `[snapshot]` only |
| `autobackup` daily 13:00 | launchd | Task Scheduler |
| `import` (old name of restore) | yes | prints "not available" |
| `list --json` for the desktop app | yes | yes, same shape |
| Claude Accounts Electron app: sidebar, per-account page, General page, tray / menu-bar menu, self-update (4-hour checks, 5 download tries, 10-minute retry, ~1 MB update zip on macOS) | yes | yes (electron-updater) |

Releases: v0.1.4 to v0.1.12 on GitHub; v0.1.12 is the latest and not marked as a prerelease. Assets: arm64 and x64 `.dmg`/`.zip`, update-only zips, and `ClaudeAccounts-Setup-0.1.12.exe`. CI (`test.yml`) passed on `main` on 2026-11-05.

### Installation requirements

- macOS: zsh, Claude Code. jq is effectively required for a good experience (see misleading claims below). Chrome only for `cca chrome`. The Claude desktop app only for desktop features.
- Windows: Windows PowerShell 5.1 or PowerShell 7, Claude Code, an execution policy that allows the profile; Developer Mode for real symlinks.
- Desktop app: macOS needs the CLI installed first; the Windows installer carries its own `cca.ps1`.

### Known limitations

- Desktop features depend on undocumented Claude desktop app behaviour (`--user-data-dir`, `CLAUDE_CONFIG_DIR` in the Code tab).
- First sign-in of each Claude app copy needs the other copies closed (`claude://` link).
- Desktop builds are unsigned (ad-hoc on macOS); first launch is blocked until allowed.
- Windows desktop features have not been tried on a real install (stated in the old README).
- The `claude` wrapper exists only in shells that load CCA; programs that start the `claude` binary directly ignore bindings.
- Not a security boundary: all accounts share the OS user, and `settings.json` (hooks, permissions, env), `CLAUDE.md`, skills and plugins are shared.
- Linux is not supported.

### Documentation weaknesses found

1. The README opened with one plain sentence: no value proposition, badges, navigation or audience.
2. User and maintainer content were mixed: release steps and tests sat in the landing page.
3. No platform support matrix; the Windows "untested" note was buried in a paragraph.
4. No privacy or security section.
5. No `docs/` folder; everything lived in one 311-line page.
6. The tray / menu-bar menu, keyboard shortcuts and update intervals of the desktop app were not documented.
7. No instructions for updating CCA itself.

### Potentially misleading claims in the old docs

| Old claim | Reality | Fixed in |
|---|---|---|
| Windows: "The terminal commands work the same as on macOS: … `restore` …" | Windows `restore` has no `--dry-run` and no `--account`; `import` is not available. | README, cli-reference, backup-restore, platform-support |
| jq is optional and only copies MCP servers | Without jq, `cca list`, `cca` and the desktop app show every account as "not logged in", and `cca chrome` fails. | README, installation, troubleshooting |
| `cca update` / `cca autoupdate` | The names suggest a CCA self-update, but they restart Claude app copies. The docs never said how to update CCA. | cli-reference, desktop, installation |
| Uninstall "removes … cca" | `uninstall.sh` leaves the autoupdate launchd job, which then fails every minute. | installation, troubleshooting |
| Repository description: "Run several Claude accounts on one Mac" | Windows is supported too. | Proposed metadata below (not applied) |
| `cca help`: "`--json`: for scripts and the Mac app" | The desktop app is cross-platform. | Recorded for a code change (below) |

## 2. Documentation structure

The README is now the landing page: what CCA is, why it helps, install, quick start, examples, the full command table, short summaries, platform matrix, top troubleshooting items and a docs index. Detail moved to `docs/`:

| File | Contents |
|---|---|
| `docs/installation.md` | Requirements (incl. what jq does), install, update, uninstall on both platforms, desktop app downloads |
| `docs/cli-reference.md` | Resolution order, name rules, every command with options and examples, environment variables |
| `docs/desktop.md` | Claude app copies, first sign-in, MCP sign-in, Claude app updates, Claude in Chrome, the Claude Accounts app, Windows notes, limitations |
| `docs/architecture.md` | Config folders, the `claude` wrapper, bindings, shared files (and how to unshare one), MCP seeding, desktop copies, app ↔ CLI bridge, file layout |
| `docs/backup-restore.md` | What backups contain and do not contain, retention, restore rules, Windows differences |
| `docs/privacy-security.md` | What stays local, what CCA reads, what is shared, backups, what CCA does not protect against, policies |
| `docs/platform-support.md` | Status matrix, CI evidence, macOS/Windows differences, known gaps |
| `docs/troubleshooting.md` | Old items kept, plus 20 new ones from error messages in the source |
| `docs/development.md` | Repository layout, tests, desktop development, releasing (moved from README) |

Nothing from the old README was dropped. Every old section now lives in the README or in one of these files.

## 3. Product identity

Applied as proposed: **CCA — Claude Accounts**, tagline *One workflow. Multiple Claude accounts.*, the GitHub description sentence as the README subtitle. The repository name, the `cca` command, file names, `appId` (`dev.cca.accounts`) and package names were not touched. The README and disclaimer state that CCA is unofficial and not affiliated with Anthropic, and that it is not a way around usage limits.

Concerns to flag:

1. **Trademark.** "Claude" is an Anthropic product name. A product called "Claude Accounts" (also the desktop app's `productName`) could be read as official or draw a trademark complaint. Descriptive use ("an account manager for Claude") is safer. The disclaimer now says the names are used only to describe what CCA works with. Owner decision; not a blocker for Phase 1.
2. **Acronym.** "CCA" came from "Claude Code accounts" (the comment `install.sh` writes into `~/.zshrc`). "Claude Accounts" does not spell CCA. Harmless, but "CCA — Claude Code Accounts" would match if you want it to.
3. **"across CLI, Desktop, and projects"** is accurate on macOS. On Windows, the desktop part is experimental, so the README marks it per platform instead of in the tagline.

## 4. Files

Created:

- `docs/installation.md`
- `docs/cli-reference.md`
- `docs/desktop.md`
- `docs/architecture.md`
- `docs/backup-restore.md`
- `docs/privacy-security.md`
- `docs/platform-support.md`
- `docs/troubleshooting.md`
- `docs/development.md`
- `docs/launch/PHASE-1-REPORT.md` (this file)

Modified:

- `README.md`

Not modified: every script, the desktop app, tests, CI, `package.json`, `LICENSE`, `.gitignore`.

## 5. Verified features

Verified by reading the source in this session (not by running a real account): every row of the table in section 1; every `cca` subcommand and option named in the docs (checked against the dispatch in `cca.zsh` and `cca.ps1`); `--email` and `--sso` (checked with `claude auth login --help`, which also lists `--console`, passed through by CCA); all file paths, launchd labels, the Task Scheduler task name, colours, retention, lock and log behaviour; desktop app labels, menu items, shortcuts and updater constants (`FIRST_CHECK_MS` 15 s, `CHECK_INTERVAL_MS` 4 h, `DOWNLOAD_ATTEMPTS` 5, `RETRY_SOON_MS` 10 min); release asset names (from the v0.1.12 release).

## 6. Unverified claims

These are in the docs, marked as such where needed, and need the owner or a tester to confirm:

| Claim | Basis | Where it is marked |
|---|---|---|
| Windows Claude app copies (`cca app`, `cca open`) work | Code only; the old README said untested | "Experimental" everywhere |
| The Windows Claude Accounts app and its updater work | Code and a published installer; no record of a real-install test | "Experimental" |
| The Windows CLI works with a real Claude login | CI behaviour tests use a stub `claude` | "Supported (CI behaviour tests)" — please confirm |
| The macOS desktop app is "checked by hand" and the CLI is "in regular use by the maintainer" | Repository history and the maintainer's setup | platform-support.md — please confirm |
| Windows *New Terminal* opens on the wrong account | Code reading (see 9.2); not reproduced | desktop.md, platform-support.md |
| Connector sign-ins stay separate per account; Chat tab items are per copy | Old README; not re-tested | as before |
| Claude Code deletes conversations after 30 days by default | Old README; not re-checked against current Claude Code docs | backup-restore.md |

## 7. Remaining documentation gaps

- `CONTRIBUTING.md`, `SECURITY.md`, issue and pull request templates, `CHANGELOG.md`, code of conduct (Phase 2).
- A private channel for security reports (privacy-security.md has an interim note).
- Screenshots and a demo (Phase 4); insertion points are marked with HTML comments in `README.md` and `docs/desktop.md`.
- A formal schema for `cca list --json` if third parties are expected to rely on it.
- An architecture diagram (a Mermaid diagram in `docs/architecture.md` would render on GitHub without an image file).

## 8. Recommended visual assets (Phase 4)

| Path | Content |
|---|---|
| `assets/demo/cca-demo.gif` | 30–45 s terminal recording: `cca add`, `cca bind`, `cca`, then `claude` printing `claude account: …`. Use demo accounts and `example.com` emails only. |
| `assets/screenshots/terminal.png` | Output of `cca` with three demo accounts and two bindings |
| `assets/screenshots/desktop.png` | The Claude Accounts window on macOS, an account page selected |
| `assets/screenshots/desktop-general.png` | The General page (backups, updates) — optional |
| `assets/screenshots/launchers.png` | Dock with tinted "Claude Work / Personal / Acme" launchers — optional |
| Social preview image (1280×640) | Name, tagline, "Open source · macOS & Windows · Unofficial" |

No real asset exists today, so no image link was added.

## 9. Findings in the code (for a later phase; nothing changed)

1. `uninstall.sh` removes the backup job but not the autoupdate job (`~/Library/LaunchAgents/dev.cca.update.plist`). After uninstalling, the job runs every minute and fails because `cca.zsh` is gone. Fix: boot out and delete that plist too. Workaround documented.
2. Windows: the desktop app's *New Terminal* starts PowerShell with the environment variable `CCA_ACCOUNT`, but `cca.ps1` reads the PowerShell variable `$global:CCA_ACCOUNT`, so the window likely follows bindings instead of the chosen account. Fix: read `$env:CCA_ACCOUNT` once at load. Needs a Windows test.
3. macOS without jq: `cca list` reports "not logged in" instead of saying jq is missing. Fix: a python3 fallback (as `_cca_json_field` already does), or a clear message.
4. `cca help` in `cca.zsh` says "the Mac app"; the app is cross-platform.
5. `desktop/package.json` description ("switch between Claude Code accounts from the menu bar or tray") predates the window UI.
6. Windows `cca restore` lacks `--dry-run` and `--account`, unlike macOS.

## 10. Proposed GitHub metadata (not applied)

- **Description:** `Manage multiple Claude accounts across Claude Code, the desktop app and your projects — without constant sign-outs. Unofficial · macOS & Windows.`
- **Topics:** `claude-code`, `claude`, `multi-account`, `account-switcher`, `developer-tools`, `cli`, `zsh`, `powershell`, `electron`, `macos`, `windows`, `productivity`. Left out: `open-source` (every public repository is) and `anthropic` (could suggest affiliation).
- **Social preview text:** "CCA — Claude Accounts · One workflow. Multiple Claude accounts. · Open source · macOS & Windows · Unofficial".
- **Website:** leave empty until there is a docs site; a GitHub Pages site can be considered in Phase 4 or 5.

## 11. Validation

| Check | Result |
|---|---|
| `git status --short` | `M README.md`, `?? docs/` — no other file touched |
| `git diff --stat` | `README.md`: 174 insertions, 216 deletions |
| Relative links and anchors (scripted check over all 10 Markdown files) | 69 links, 0 problems |
| External links (`curl -L`, 9 URLs incl. badges, releases, issues, Claude Code docs, jq, Claude download) | all HTTP 200 |
| Code fences balanced; table rows match their headers | 0 problems |
| Every `cca` subcommand and option in the docs exists in the source | yes (21 subcommand forms; options `--account`, `--dry-run`, `-n`, `--email`, `--sso`, `--json`, `--quiet`, `--unlink`) |
| Arabic in committed text (`perl … \p{Arabic}`) | none |
| Secrets or personal data | none; only `you@example.com`, `you@company.example`, `/Users/you` |
| Application logic modified | no |
| Test suites | not run: no code changed. CI on `main` last passed on 2026-11-05 |
| Markdown linter | none installed; checks above were scripted instead |

## 12. Risks and limitations of this phase

- The docs describe the code as of `cbaa3da`. Future code changes must update `docs/` too; Phase 2 should add a pull request checklist item for that.
- Ten Markdown files are more to maintain than one; content was split by topic to avoid duplication, but the README summaries must stay in step with the detail pages.
- The README shows on GitHub only after the owner commits and pushes. Until then the public page is unchanged.
- The statuses "Supported" and "Experimental" rest partly on the owner's answers below.

## 13. Next steps for Phase 2

1. Owner review of this diff, then a commit and pull request (only on the owner's order).
2. Apply the GitHub description and topics above (only on the owner's order).
3. Add `CONTRIBUTING.md` (tests, Windows test reports, "update docs with code"), `SECURITY.md` (turn on GitHub private vulnerability reporting), issue templates (bug report asking for platform, CCA version and redacted `cca list --json`; Windows test report), a pull request template with a docs checkbox, and `CHANGELOG.md` seeded from the existing releases.
4. Plan the six code findings in section 9 as small, tested fixes (Phase 3).

## Owner decisions

1. **Windows status:** has any Windows part (CLI with a real login, `cca app`/`cca open`, the Claude Accounts installer) been used on a real Windows machine? The answer moves rows between "Supported" and "Experimental".
2. **Name:** keep "CCA — Claude Accounts", or change to a descriptive form such as "CCA — account manager for Claude" because of the trademark concern?
3. **Commit:** when you are happy with the diff, say so and name the branch; nothing is committed until then.
