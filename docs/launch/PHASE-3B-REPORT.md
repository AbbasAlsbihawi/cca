# Phase 3B report: stabilization fixes

Date: 2026-11-06 · Branch: `fix/phase-3b-stabilization` (on top of `test/phase-3a-regression`) · Pushed for CI on the owner's approval · CI green · No pull request yet.

## 1. Executive summary

Phase 3B fixed the four confirmed bugs from Phase 3A and closed the four test isolation gaps. Each bug's known-bug check is now a normal assertion.

| | Result |
|---|---|
| BUG-001 uninstall leaves the autoupdate job | Fixed; `uninstall.sh` is now tested in a throwaway folder with a stub `launchctl` (26 checks) |
| BUG-002 Windows *New Terminal* uses the wrong account | Fixed; 14 checks, including a fresh PowerShell process |
| BUG-003 no jq shows "not logged in" | Fixed; emails are read without jq, and a login that cannot be read shows as unknown (15 checks) |
| BUG-004 help says "Mac app" | Fixed |
| G1–G4 test isolation | Closed |
| zsh suite | **294 passed, 0 failed**, no known bugs left (Phase 3A: 252 passed, 3 known bugs) |
| PowerShell | every `.ps1` parses; Windows CI (Windows PowerShell 5.1): **258 passed, 0 failed**, including the 14 new account checks |

## 2. Owner approval and baseline

- **Approval:** the owner approved Phase 3B, the push of the branch for Windows CI, and the commits ("whatever you need, I agree").
- **Baseline:** `f65dc2f` (Phase 3A) on `test/phase-3a-regression`. The new branch `fix/phase-3b-stabilization` starts there.
- **Untouched:** no existing commit was rebased, amended or squashed. `main` was not changed.

## 3. Test isolation (G1–G4)

| Gap | Fix | Check |
|---|---|---|
| G1 LaunchServices | `cca.zsh` calls LaunchServices through a new one-line function, `_cca_lsregister` (same behaviour). Every test starts with a stub for it, so `cca app` never registers anything in the real LaunchServices database | "app registers the launcher (LaunchServices stubbed)" |
| G2 real process list | A `ps` stub that lists nothing is first on the test `PATH`, so a test without its own `ps` stub sees no Claude process. Tests that need processes still define their own | all tests pass; the suite prints a note if any test reaches a safety stub (none did) |
| G3 Trash | `run()` and `jrun()` pass `CCA_TRASH=$T/trash` to every command; the start-up guard also checks it | guard + all remove/restore tests |
| G4 clean environment | `run.sh` restarts itself under `env -i` with only `PATH`, `TMPDIR` and the locale; `HOME` becomes a throwaway folder. Its temporary folder is now created **inside `TMPDIR`**: macOS `mktemp -d` alone ignored `TMPDIR`. `run.ps1` drops every inherited `CCA_*` variable and `CLAUDE_CONFIG_DIR` at the start, and `newbox` also clears `$env:CCA_ACCOUNT`. The CI workflow was not changed: the isolation lives in the suites, so CI and local runs get it alike | the PowerShell checks passed with `CCA_ACCOUNT` and `CLAUDE_CONFIG_DIR` deliberately leaked into the run |

Extra safety stubs on the test `PATH`:

- `open`, so no real app is launched
- `launchctl`, so no real job is changed

`_cca_front` and `_cca_quit_pid` are stubbed by default, so no real window is brought forward and no real app is quit. All runs left their throwaway folders empty.

## 4. Fixes

### BUG-002: Windows account selection

- **Root cause.** The desktop app starts PowerShell with the environment variable `CCA_ACCOUNT`. `cca.ps1` read only the PowerShell variable `$global:CCA_ACCOUNT`.
- **Fix (smallest safe change).** When `cca.ps1` loads, it copies `$env:CCA_ACCOUNT` into `$global:CCA_ACCOUNT` if no choice exists yet. It then removes the environment variable, so the PowerShell variable is the only source of truth. `cca use -` also clears the environment variable, in case something sets it later.

| Situation | Account used | Same as macOS? |
|---|---|---|
| 1. `cca use <name>` already ran in this session | that account (an explicit choice wins) | yes |
| 2. `CCA_ACCOUNT` set when the shell starts | that account | yes |
| 3. a folder binding applies | the bound account | yes |
| 4. none of the above | the default account | yes |
| `CCA_ACCOUNT` names no account | `claude` stops with "account '…' (set in this terminal) does not exist"; nothing silently falls back | yes, as in `cca.zsh` |
| a program started from this terminal | does not inherit the choice | no: on macOS an exported variable is inherited (documented) |

- **`cca use` is compatible.** It behaves exactly as before; `cca use -` was checked before the change (it removed the global variable and printed a message) and still does.
- **Tests (`run.ps1`):** no variable, a valid name, removed from the environment, becomes the `cca use` choice, switching, an explicit choice wins over the variable, `cca use -` clears it, an unknown name fails and runs nothing, a fresh PowerShell process, a new box starts clean.

### BUG-001: macOS uninstall

- **Root cause.** `uninstall.sh` knew only the backup job.
- **Fix.**
  - It loops over both CCA jobs (`dev.cca.backup`, `dev.cca.update`): `launchctl bootout` (a failure is ignored, as before), delete the plist, and say which job went. Other jobs are never touched.
- **Testability, without weakening production.**
  - `CCA_TEST_APPLICATIONS` replaces `/Applications` only if it resolves to an existing folder strictly inside `TMPDIR`.
  - An empty, `/`, missing or outside path stops the script with an error before it changes anything.
  - With the variable unset, behaviour is exactly as before.
  - The bundle-id check (`dev.cca.accounts`) still guards every app removal.
- **Tests (`run.sh` §24).** They run in a throwaway home, a throwaway Applications folder and a stub `launchctl`, and cover:
  - both jobs, backup only, autoupdate only, no jobs
  - `launchctl` failing, a second run
  - an unrelated job kept, a foreign app with the same name kept, only CCA launchers removed
  - `cca.zsh` removed and data kept, `.zshrc` cleaned
  - the test folder `/`, a folder outside `TMPDIR` and a missing folder, each refused with nothing changed
- **Safety.** The real `uninstall.sh` never ran against the host; the suite refuses to run §24 unless all its paths are inside the throwaway folder.

### BUG-003: no jq

- **Root cause.** `_cca_oauth` returned nothing without jq.
- **Fix.**
  - With jq: unchanged.
  - Without jq, it reads the flat `oauthAccount` object with a zsh pattern, the same approach `_cca_account_uuid` already uses, and decodes `\"`, `\\` and `\/`.
  - No `oauthAccount`, or `"oauthAccount": null`, means not logged in.
  - An `oauthAccount` it cannot read safely (for example a nested object) returns status 2. `cca list` then shows `login unknown (install jq)`, and `cca list --json` gives `loggedIn: null`.
  - No Python fallback, because `/usr/bin/python3` can open the developer-tools install prompt.
  - Only the email and organization are ever printed, never other fields.
- **Desktop app.** It already shows "Not logged in" only when `loggedIn === false`, so `null` shows no false claim; no UI change was needed.
- **Tests (`run.sh` §23):**
  - jq present, the default account with an organization
  - a pretty-printed file with odd spacing, escaped characters
  - no `oauthAccount`, a `null` one, no file at all
  - an unreadable `oauthAccount` gives unknown
  - a token in the file is never printed, in text or JSON
  - JSON `true` / `false` / `null`, the same email with jq, several accounts at once

### BUG-004: help text

`cca help` now says "the desktop app" (macOS help; the Windows help already did).

## 5. Windows support

This phase did not change the status of any Windows feature. BUG-002 is a fix for a Windows path that the desktop app uses, now covered by tests on both PowerShell versions in CI.

## 6. Documentation

- **Uninstall:** `docs/installation.md` no longer asks for `cca autoupdate off` before uninstalling, and lists both jobs.
- **jq:** the README, `docs/installation.md` and `docs/troubleshooting.md` describe "login unknown (install jq)" instead of "not logged in".
- **`CCA_ACCOUNT`:** `docs/cli-reference.md` documents it for both platforms and documents `loggedIn: null`.
- **Known issues:** `docs/desktop.md` and `docs/platform-support.md` drop the *New Terminal* known issue.
- **Tests:** `docs/development.md` describes the clean-environment test runs.
- **CHANGELOG:** lists the four fixes and the test changes under **Unreleased**.

## 7. Test execution

| Check | Result |
|---|---|
| zsh suite, run as `env -i HOME=<scratch> TMPDIR=<scratch> PATH=… zsh -f tests/run.sh` (the suite also restarts itself clean) | **294 passed, 0 failed**; no safety-stub notes; scratch folders empty afterwards |
| `zsh -n cca.zsh`, `sh -n install.sh`, `sh -n uninstall.sh` | ok |
| `pwsh -NoProfile -File tests/parse-ps1.ps1` | 10 parsed, 0 failed |
| New PowerShell account checks under `pwsh` on macOS (the suite's own helpers, with `CCA_ACCOUNT` and `CLAUDE_CONFIG_DIR` leaked into the run on purpose) | 14 passed, 0 failed |
| `node --check` on every desktop source file | ok (no desktop code changed) |
| GitHub Actions on `fix/phase-3b-stabilization`, [run 42137511769](https://github.com/AbbasAlsbihawi/cca/actions/runs/42137511769) | both jobs **success**. macOS: zsh suite 294 passed, 0 failed; `.ps1` parse 6/0. Windows PowerShell 5.1: parse 6/0; behavioural suite **258 passed, 0 failed**, including all 14 account checks |

## 8. Scope exclusions respected

Not done in this phase, as agreed: `cca --version`, Windows restore parity, the desktop rename or updater migration, installer redesign, dependency or release changes, UI changes, icon, `appId`, `productName`, CI workflow changes.

## 9. Remaining risks

- **On Windows, a choice no longer reaches child processes.** `cca.ps1` removes `CCA_ACCOUNT` from the environment, so a PowerShell started from inside a New Terminal window does not inherit the choice (on macOS an exported variable is inherited). This is intentional: it keeps one source of truth.
- **The jq-free reader is deliberately narrow.** It reads only a flat `oauthAccount`. If Claude Code ever nests objects inside it, users without jq see "unknown" (honest) until jq is installed.
- **Scope of `CCA_TEST_APPLICATIONS`.** It exists only for tests and is limited to `TMPDIR`. Someone who controls the environment of `uninstall.sh` could already do anything, so it adds no new capability.

## 10. Readiness

**READY for Phase 3C** (CLI improvements and versioning): local and CI tests are green on both platforms. Suggested next steps:

- open a pull request for `fix/phase-3b-stabilization` after the docs pull request (#20) is merged
- or open it now, based on `docs/launch-phase-1-2`, so the reviewer sees only the Phase 3 commits
