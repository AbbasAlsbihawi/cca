# Phase 2 report: GitHub community and open-source readiness

Date: 2026-11-06 · Scope: documentation and repository files only · No application code, scripts, CI or dependencies changed · No remote GitHub setting changed.

**Recommendation: READY for Phase 3**, once the owner approves the remote settings in section 6 and picks a name (section 7).

## 1. Phase 1 review gate

- `git status` before Phase 2: only `README.md` modified and `docs/` added, all from Phase 1. No other user changes.
- Phase 1 files present; link check passed.
- After the owner reviewed Phase 1, two changes were made to it:
  - **Windows is supported.** The owner confirmed that two contributors run CCA on real Windows installs and sent Windows fixes: [#1](https://github.com/AbbasAlsbihawi/cca/pull/1) (the Windows port), [#7](https://github.com/AbbasAlsbihawi/cca/pull/7) (Add, colours, login check) and [#12](https://github.com/AbbasAlsbihawi/cca/pull/12) (the Windows desktop app). Every "Experimental" Windows row in the README and `docs/` now says "Supported", and `docs/platform-support.md` cites these PRs. The Phase 1 report has a dated note about this.
  - **Links to the new files.** The README, `docs/privacy-security.md` and `docs/development.md` now link to `CONTRIBUTING.md`, `SECURITY.md` and `CHANGELOG.md`.

## 2. Files

Created:

- `CONTRIBUTING.md`
- `SECURITY.md`
- `CHANGELOG.md`
- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/windows_test_report.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `docs/launch/PHASE-2-REPORT.md` (this file)

Modified since Phase 1: `README.md`, `docs/cli-reference.md`, `docs/desktop.md`, `docs/installation.md`, `docs/platform-support.md`, `docs/privacy-security.md`, `docs/development.md`, `docs/launch/PHASE-1-REPORT.md`.

Not modified: `cca.zsh`, `cca.ps1`, installers, `desktop/`, `tests/`, `.github/workflows/`, `LICENSE`.

## 3. Community files

Audit before Phase 2: `.github/` held only `workflows/test.yml`. There was no contribution guide, security policy, issue template, pull request template, changelog or code of conduct.

| File | What it gives contributors |
|---|---|
| `CONTRIBUTING.md` | Ways to help, fork-and-branch steps, setup per platform, the real test commands, how the two CLIs must stay in step, coding rules taken from the existing code (helper naming, error reporting, 5.1 syntax, argument arrays in the desktop app, never destroy user data), docs and changelog expectations, PR rules, the commit message style the repository already uses |
| `SECURITY.md` | Supported versions, private reporting (with a fallback while private reporting is off), what to include and what never to send, what is and is not a vulnerability, how to protect your own setup |
| `bug_report.yml` | Required: description, steps, expected, actual, OS, OS version, part of CCA, CCA version, install method. Optional: Claude versions, logs, context. A warning against sharing secrets. Label `bug` |
| `feature_request.yml` | Problem, solution, alternatives, platforms, context. Label `enhancement` |
| `windows_test_report.yml` | Windows and PowerShell versions, CCA and Claude versions, Developer Mode, a checklist of 11 Windows features, results, failure steps, logs. No label (none suitable exists) |
| `config.yml` | Blank issues allowed; a "Report a security problem" link to the security policy |
| `PULL_REQUEST_TEMPLATE.md` | Summary, linked issue, type of change, testing (commands, platforms tested and not tested), a 7-item checklist including "matching change in the other CLI" and "docs and changelog updated" |

No code of conduct file was created. `CONTRIBUTING.md` asks for respectful behaviour without claiming a formal code exists. Adding one (for example the Contributor Covenant) is an owner decision.

`CONTRIBUTING.md` ends with the standard line that contributions are released under the MIT License. **Owner: please confirm you want that sentence.**

## 4. CHANGELOG evidence

Sources: `git tag`, `gh release list`, the body of every GitHub release, `git log` between consecutive tags, and the merged pull requests.

| Version | Tag | GitHub release | Notes |
|---|---|---|---|
| 0.1.0 – 0.1.6 | yes | yes | |
| 0.1.7 | **no** | **no** | Set in PR #11 and a "Release 0.1.7" commit, but never tagged or published; its change shipped in 0.1.8. Marked "Not released". |
| 0.1.8 – 0.1.12 | yes | yes | |

- Dates are the GitHub release dates in UTC. Tag commit dates can be a day later in local time (v0.1.3, v0.1.11).
- Every entry comes from a PR title, a commit subject or a comment in the code, reworded for readers. One entry comes from a code comment: the 0.1.3 fix (macOS treated downloaded copies of 0.1.0–0.1.2 as damaged), from `desktop/scripts/publish.sh`.
- External contributors are credited by GitHub profile link: AhmedAbasss (#1, #7) and mustafaa960 (#12). Links are used instead of @-mentions.
- No tag or release was changed.

## 5. Security disclosure limitations

- **Private vulnerability reporting is off** (checked with the GitHub API: `enabled: false`). `SECURITY.md` asks reporters to use it and falls back to a "Security contact request" issue with no details. Turning it on makes the first route work.
- No security email exists, and none was invented.
- No response time is promised.
- The `config.yml` link `https://github.com/AbbasAlsbihawi/cca/security/policy` shows `SECURITY.md` only after it is merged into `main`.
- `SECURITY.md` states clearly what is out of scope by design: CCA is not a security boundary; shared settings; copied MCP definitions; unencrypted backups; unsigned builds.

## 6. GitHub settings to approve (nothing applied)

| Setting | Now | Recommendation |
|---|---|---|
| Description | "Run several Claude accounts on one Mac — …" | `Manage multiple Claude accounts across Claude Code, the desktop app and your projects, without constant sign-outs. Unofficial, macOS and Windows.` (adjust if the name changes, see section 7) |
| Topics | none | `claude-code`, `claude`, `multi-account`, `account-switcher`, `developer-tools`, `cli`, `zsh`, `powershell`, `electron`, `macos`, `windows`, `productivity` (12 of GitHub's 20 allowed) |
| Website | empty | Keep empty until there is a docs site |
| Social preview | none | A 1280×640 image made in Phase 4: name, tagline, "Open source · macOS & Windows · Unofficial", no Claude logo |
| Private vulnerability reporting | off | **Turn on**, so `SECURITY.md` works as written |
| Discussions | off | Keep off until the launch; turn on with a Q&A category in Phase 5 if questions start arriving in issues |
| Wiki | on, unused | Turn off, so there is one place for docs |
| Labels | GitHub defaults | Add `windows`, `macos` and `desktop-app`, then add `windows` to the Windows test form |

## 7. The product name (owner decision)

Anthropic's [trademark guidelines](https://www.anthropic.com/legal/trademark-guidelines) say its names may be used only as Anthropic permits, never in a way that implies sponsorship or affiliation, and never altered. In January 2026, Anthropic asked the open-source project Clawdbot to rename because its name resembled "Claude" ([report](https://laravel-news.com/index.php/clawdbot-rebrands-to-moltbot-after-trademark-request-from-anthropic)); it became Moltbot. That project had no "Claude" in its name at all.

Things that make "CCA — Claude Accounts" risky:

- "Claude Accounts" reads like an Anthropic feature (account management for Claude).
- The desktop app ships as "Claude Accounts" (`productName`), with an orange close to Claude's brand colour.
- `cca app` makes launchers from a tinted copy of the Claude app icon. This happens on the user's machine from their own Claude install, but it is still an altered Claude logo.
- A forced rename after the LinkedIn launch would break links and posts, and would need an app update that renames the installed app.

Options:

| Option | Display name | Cost now | Risk later |
|---|---|---|---|
| A. Keep | CCA — Claude Accounts | none | highest |
| **B. Descriptive (recommended)** | **CCA — multi-account manager for Claude Code**, tagline unchanged | docs only now; the desktop app is renamed from "Claude Accounts" to "CCA" in Phase 3 | low: "Claude" only says what it works with |
| C. New brand | a new name with no "Claude" in it | high: new name search, all docs, the app, the posts | lowest |

Recommendation: **B**. Keep the short name `CCA` and the `cca` command; they carry no "Claude" and nothing breaks. Do not spell out the acronym in the branding. Rename the desktop app to "CCA" in Phase 3 (it changes the installed app's name, so the updater and `uninstall.sh` must handle both names), and give it a colour of its own in Phase 4. This is not legal advice; for certainty, ask Anthropic (the guidelines name `marketing@anthropic.com` for trademark questions).

## 8. Phase 3 backlog (proposed issues, not created)

Each finding was checked again against the source.

| # | Title | Kind | Severity | Platforms | Acceptance criteria |
|---|---|---|---|---|---|
| 1 | Uninstall leaves the autoupdate job running | Confirmed bug (`uninstall.sh` removes only `dev.cca.backup.plist`) | Medium | macOS | `uninstall.sh` boots out and deletes `dev.cca.update.plist`; a test covers it; the workaround is removed from the docs |
| 2 | Desktop app *New Terminal* opens on the wrong account on Windows | Confirmed in code (the app sets the environment variable `CCA_ACCOUNT`; `cca.ps1` reads only `$global:CCA_ACCOUNT`); not yet reproduced | Medium–High (work can run on the wrong account) | Windows | `cca.ps1` takes the account from `$env:CCA_ACCOUNT` when it loads; a `tests/run.ps1` case proves it; tried on a real Windows install |
| 3 | Missing jq shows every account as "not logged in" | Bug (misleading output) | Medium | macOS | Without jq, `cca list` either reads the email another way (python3, as restore already does) or says jq is missing; `cca list --json` reports the same |
| 4 | `cca help` says "the Mac app" | Documentation issue in code | Low | macOS | Help text says "the desktop app" |
| 5 | `desktop/package.json` description is out of date | Documentation issue in code | Low | both | Description matches the app; no identifier changes |
| 6 | Windows `cca restore` lacks `--dry-run` and `--account` | Feature parity gap | Low | Windows | Both options work as on macOS, with tests; docs updated |
| 7 | No `cca --version` | Feature gap (found in Phase 2: the bug form has to ask for a tag or commit) | Low–Medium | both | `cca --version` prints the version on both platforms; the bug form asks for it |
| 8 | Rename the desktop app from "Claude Accounts" | Owner decision (section 7) | — | both | Only if option B or C is chosen: new `productName`, updater and uninstall handle the old name, docs updated |

## 9. Validation

| Check | Result |
|---|---|
| Relative links and anchors in all 15 Markdown files | 91 links, 0 problems |
| External links in the Phase 2 files (40) | all HTTP 200, except the `<your-user>` placeholder and `blob/main/docs/troubleshooting.md` (resolves after merge) |
| Issue forms parsed with PyYAML; schema checked (types, unique ids, labels, options, `required` booleans, string dropdown options) | 4 files, 0 problems |
| Labels used in forms exist in the repository | `bug`, `enhancement` — yes |
| Code fences and table rows | 0 problems |
| CHANGELOG entries against tags, releases, PRs | every entry traced (section 4) |
| Arabic in repository text | none |
| Secrets or personal data | none; contributor emails from `git log` were not used |
| Application code, scripts, CI, dependencies changed | no |
| Remote GitHub settings changed | no |
| Test suites | not run: no code changed |

## 10. Remaining risks

- The name question (section 7) is open; renaming later touches the README, every guide and the desktop app.
- `SECURITY.md` route 1 depends on turning on private vulnerability reporting.
- The docs must keep up with code changes; the PR template and `CONTRIBUTING.md` now ask for that.
- Windows "Supported" rests on contributor use and CI. The *New Terminal* bug shows that Windows desktop paths still need a real-install check when they change.
