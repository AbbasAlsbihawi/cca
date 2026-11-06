# Phase 3A report: safety audit, test isolation and bug reproduction

Date: 2026-11-06 · Branch: `test/phase-3a-regression` (on top of `docs/launch-phase-1-2`) · Production code unchanged.

**Recommendation: READY for Phase 3B.** The three bugs it should fix are confirmed and each has a regression test. BUG-001 also needs a small testability change, described in section 4.

## 1. Executive summary

- **Approval gate.** The audit plan (read-only audit, then known-bug tests only, no production change, a separate branch, isolated test runs) was approved in advance by the owner for all of Phase 3A.
- **Test isolation is good** for the zsh and PowerShell suites. Both redirect every CCA path to a throwaway folder and stub `claude`. The zsh suite also refuses to start if any path still points outside its throwaway home. Four small gaps remain (section 2).
- **The installers are not tested at all**, and `uninstall.sh` cannot be tested safely as written: it reaches the real `/Applications` and the real launchd domain.
- **Bugs confirmed with evidence:**
  - BUG-001: uninstall leaves the autoupdate job.
  - BUG-002: the Windows desktop *New Terminal* opens on the wrong account.
  - BUG-003: without jq, every account shows as "not logged in".
  - BUG-004: the help text says "Mac app".
- **Recorded as known bugs in the suites.** Each of these four now has a check that reports `xfail` (known bug). That check fails the run as soon as the bug is fixed, so the fix must turn it into a normal assertion.
- **Test results:**
  - zsh suite: **252 passed, 0 failed, 3 known bugs** (baseline before this phase: 251 passed, 0 failed).
  - Every `.ps1` file parses under PowerShell 7.
  - The Windows suite runs only on Windows, so its new check runs in CI once the branch is pushed. Its logic was reproduced locally with `pwsh` (section 5).

## 2. Test isolation audit

### Test architecture

| | `tests/run.sh` (zsh) | `tests/run.ps1` (PowerShell) |
|---|---|---|
| Framework | Hand-written helpers: `ok`, `bad`, `eq`, `has`, `hasnt`, `yes`, `no`; counters; exit code = failures | Same style: `ok`, `bad`, `eq`, `has`, `keys`, `code`, `checkjson` |
| Runs on | macOS (CI: `macos-latest`) | Windows only (CI: `windows-latest`, Windows PowerShell 5.1) |
| Home folder | `mktemp -d` → `$T/home`, removed on exit | `newbox`: a GUID folder under the temp path per group, removed at the end |
| CCA paths | `unset -m 'CCA_*'` first, then defaults derived from the throwaway `HOME`; a guard stops the run if `CCA_HOME`, `CCA_MAIN_DIR`, `CCA_MAIN_JSON`, `CCA_MAIN_APP_DATA`, `CCA_LAUNCH_AGENTS` or `CCA_CHROME_DATA` falls outside it | `newbox` sets `CCA_HOME`, `CCA_MAIN_DIR`, `CCA_MAIN_JSON`, `CCA_MAIN_APP_DATA`, `CCA_TRASH`, `CCA_LAUNCHERS` and clears `$global:CCA_ACCOUNT` |
| `claude` | Stub script first on `PATH`, prints `CFG=` and `ARGS=` | Stub `claude.cmd` (and a no-extension script for macOS) first on `PATH` |
| System commands | zsh function stubs per test: `ps`, `open`, `launchctl`, `_cca_front`, `_cca_quit_pid`, `_cca_open`, `_cca_app_version`, `_cca_instances` | Uses PowerShell's own process as the "Claude app"; Task Scheduler cmdlets run for real only in tests that create no task |
| Trash | Every `cca remove` / `cca restore` test sets `CCA_TRASH=$T/trash` | `CCA_TRASH` set in every box |
| Coverage | 22 sections: syntax, add, bindings, use, unbind, errors, list/status, run, nested sessions, reload, open, app (real `osacompile`, `codesign`), remove, restore, backups, autobackup, update/autoupdate, list --json, chrome | colours, list --json shape, exit codes, the desktop shim, sign-in check |

### Commands that could reach real user data or the real system

| Where | What it touches | Status |
|---|---|---|
| `uninstall.sh` | Deletes `/Applications/Claude Accounts.app` (bundle id `dev.cca.accounts`), runs real `launchctl bootout gui/<uid>` with a plist path (which unloads the job by its label in the real launchd domain), edits `~/.zshrc` | **Not tested; unsafe to run in a test as written** |
| `install.sh` | Writes `~/.claude-accounts`, appends to `~/.zshrc` | Not tested; safe with a throwaway `HOME` |
| `install.ps1`, `uninstall.ps1` | Profile files under `Documents`, Task Scheduler task `cca-backup`, Start menu folder | Not tested |
| `run.sh` §13 (`cca app`) | Real `osacompile`, `codesign`, `lsregister -f` on a launcher in the throwaway home; reads the real `/Applications/Claude.app` icon | Writes only to the throwaway home, but **registers that launcher with the real LaunchServices database** (gap G1) |
| `run.sh` line 316 (`cca restore work`) | Real `ps` process list, read-only | The expected result (refused) is the same whether or not the real Claude app is open, but the reason differs (gap G2) |
| `_cca_trash` without `CCA_TRASH` | `/usr/bin/trash` → the real Trash | Every current test sets `CCA_TRASH`; a future test that forgets would use the real Trash (gap G3) |
| Local runs of `run.sh` | Inherited environment | Safe only because of the `unset` and the guard. The owner's rule for local runs is `env -i HOME=<scratch> TMPDIR=<scratch> PATH=… zsh -f tests/run.sh`; CI does not use `env -i` (gap G4) |

Gaps to close in Phase 3B or 3C (test-only changes):

- **G1:** stub `lsregister` in §13, or skip that line outside CI.
- **G2:** stub `ps` in the `restore work` test.
- **G3:** set `CCA_TRASH=$T/trash` in `run()` itself, so no test can reach the real Trash.
- **G4:** run the CI step with an explicit environment too.

## 3. Bugs

| ID | Finding | Classification | Root cause | Affected versions |
|---|---|---|---|---|
| BUG-001 | `uninstall.sh` leaves the autoupdate job running | **Confirmed bug** | `uninstall.sh` boots out and deletes only `dev.cca.backup.plist`; the autoupdate job `dev.cca.update.plist` (added in 0.1.5, PR #8) is never removed. After uninstall, the job runs every 60 s and fails because `cca.zsh` is gone | 0.1.5 – 0.1.12 |
| BUG-002 | Windows desktop *New Terminal* uses the wrong account | **Confirmed bug** (reproduced with stubs) | `desktop/main/interactive.js` `openShell()` starts `cmd /c start powershell -NoExit` with the environment variable `CCA_ACCOUNT=<name>`. The new PowerShell loads the profile and `cca.ps1`; `Resolve-CcaAccount` reads only `$global:CCA_ACCOUNT` (the variable `cca use` sets), never `$env:CCA_ACCOUNT`, so the window follows folder bindings or the default account. macOS is not affected: zsh reads the exported variable directly | Windows desktop app since *New Terminal* exists |
| BUG-003 | Without jq, every account is "not logged in" | **Confirmed bug** | `_cca_oauth` returns nothing when `jq` is missing, so `cca list`, `cca` and `cca list --json` (`email: null`, `loggedIn: false`) report every account as signed out. `_cca_account_uuid` already falls back to a regex read when jq is missing, so the code has a precedent | all macOS versions |
| BUG-004 | `cca help` says "the Mac app" | **Documentation issue in code** | Help text written before the app was cross-platform | 0.1.0 – 0.1.12 |
| BUG-005 | `desktop/package.json` description is out of date | **Documentation issue** | "switch between Claude Code accounts from the menu bar or tray" predates the window UI. Fixing it changes metadata only; `appId`, `name` and `productName` must stay | — |
| BUG-006 | Windows `cca restore` lacks `--dry-run` and `--account` | **Feature parity gap** (missing feature, not an intentional difference: nothing in the code or history says it was left out on purpose). Now documented | `Invoke-CcaRestore` reads two positional arguments only | — |
| BUG-007 | No `cca --version` / `cca version` | **Feature gap** | Neither CLI has a version; see section 7 | — |
| BUG-008 | Rename the desktop app from "Claude Accounts" to "CCA" | **Owner-approved direction, not a bug**; needs a migration plan (section 9). Not implemented | — | — |

No suspected-but-unconfirmed bugs remain: BUG-002 was the only one not yet reproduced, and it is now reproduced.

## 4. Regression tests added (known bugs)

Both suites gained a `known` helper. A known-bug check prints `xfail - <name> (<bug>, known bug)` and does not fail the run. If the check starts to pass, it prints `FAIL - <name>: <bug> looks fixed; make this a normal check` and fails the run. That forces the fix to replace it with a normal assertion. Nothing existing was weakened.

| Test | Bug | Setup | Mocked | Expected after the fix | Current result | Cleanup |
|---|---|---|---|---|---|---|
| `uninstall.sh removes the autoupdate job` (`run.sh` §23) | BUG-001 | Reads `uninstall.sh` with `grep` | nothing; the script is **not run**, because it would reach the real `/Applications` and launchd | the script removes `dev.cca.update.plist` | xfail | none needed |
| `list shows the email with jq` (`run.sh` §23) | control for BUG-003 | throwaway home, default account with an email | `claude` | email shown | **ok** | suite cleanup |
| `list shows the email without jq` (`run.sh` §23) | BUG-003 | same, with `path=($T/bin)` so jq cannot be found | `claude` | email shown (or a clear "jq is missing" message, if 3B chooses that; the check then changes) | xfail | suite cleanup |
| `help does not call the desktop app the Mac app` (`run.sh` §23) | BUG-004 | `cca help` | — | no "Mac app" | xfail | — |
| `New Terminal: CCA_ACCOUNT from the environment picks the account` (`run.ps1`, end) | BUG-002 | `newbox`, a `personal` profile, `$env:CCA_ACCOUNT='personal'`, `cca.ps1` sourced again | `claude` stub | `claude` runs with `profiles\personal` | xfail (reproduced locally, see section 5; runs in Windows CI after a push) | box removed with the others; the variable is cleared |

For BUG-001, the static check is a stopgap. Before the real fix, Phase 3B should make `uninstall.sh` testable:

- let the app locations be overridden, for example a `CCA_APPLICATIONS` variable that defaults to `/Applications`
- call `launchctl` through a function or a `PATH` stub, as `cca.zsh` already does with `_cca_launchctl`

A behavioural test can then run `uninstall.sh` in a throwaway home and check that both plists are gone.

Not given a test, on purpose:

- BUG-005: metadata only.
- BUG-006 and BUG-007: features whose shape 3C must decide first.
- BUG-008: a migration, not a check.

## 5. Reproduction evidence

All runs used throwaway folders under the session scratchpad. No real account, credential, backup or job was read or changed.

- zsh baseline: `env -i HOME=<scratch>/home TMPDIR=<scratch>/tmp PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin zsh -f tests/run.sh` gave **251 passed, 0 failed**. The scratch home was empty afterwards.
- zsh after this phase, same command: **252 passed, 0 failed, 3 known bugs** (BUG-001, BUG-003, BUG-004).
- PowerShell parse: `pwsh -NoProfile -File tests/parse-ps1.ps1` gave **10 parsed, 0 failed**.
- BUG-002 with `pwsh` on macOS, using a standalone copy of the test's setup (redirected CCA paths, stub `claude`, `CCA_ACCOUNT=personal` in the environment, `cca.ps1` sourced):
  - environment variable only → `CFG=` (the default account: bug reproduced)
  - after `cca use personal` → `CFG=…/accounts/profiles/personal` (control)
  - The throwaway folder was removed afterwards.
- BUG-001: `grep -c dev.cca.update.plist uninstall.sh` → 0. `uninstall.sh` names only `dev.cca.backup.plist`.

## 6. CI review and recommendations (no workflow changed)

Current state: one workflow (`test.yml`), on every push and pull request.

- **macOS job:** `zsh -n cca.zsh`, the zsh suite, a `.ps1` parse under PowerShell 7, and `node --check` on the desktop sources.
- **Windows job:** a `.ps1` parse and the behavioural suite under Windows PowerShell 5.1. It passes `$LASTEXITCODE` through correctly.

Recommendations:

1. Syntax-check the POSIX installers: `sh -n install.sh uninstall.sh`.
2. Once `uninstall.sh` is testable (section 4), test both installers on macOS in a throwaway home, and `install.ps1` / `uninstall.ps1` on Windows with redirected profile paths.
3. Run the zsh suite with an explicit environment (`env -i HOME=… TMPDIR=… PATH=…`), so CI matches the safe local command.
4. Upload the suite logs as an artifact when a job fails.
5. Add small `node:test` unit tests (no new dependency) for the desktop's pure functions: the updater's version compare and asset choice in `updater/mac.js`.
6. Add the Markdown link check used in Phases 1 and 2 as a script, so docs links are checked on every pull request.

## 7. Versioning

| Source | Value today |
|---|---|
| `desktop/package.json` `version` | `0.1.12`, bumped with `npm version patch --no-git-tag-version` |
| Git tag / GitHub release | `desktop/scripts/publish.sh` tags `v$V` from `package.json` and creates the release |
| `cca.zsh`, `cca.ps1` | no version at all |
| Gap seen | 0.1.7 was set in `package.json` (PR #11) but never published |

Recommendation: keep `desktop/package.json` as the single source.

- Add one `CCA_VERSION` line to `cca.zsh` and `cca.ps1`.
- Have npm's `version` lifecycle script rewrite that line in both files during `npm version`.
- Add a CI check that fails if either file differs from `package.json`.
- `cca --version` and `cca version` print `cca <version>`. The bug report form can then ask for that instead of a tag or commit.

This touches release tooling, so it belongs in 3C.

## 8. Security review

No exploitable vulnerability was found. Observations, none of which call for a public issue:

1. **Input handling is careful.**
   - Account names are validated with `^[a-z0-9][a-z0-9_-]*$` on both platforms, snapshot names with their date pattern, and `--account` with `^[0-9A-Za-z-]+$`.
   - The desktop app passes arguments as arrays, never as shell strings. The PowerShell shim receives a real argument list.
   - Generated launchd plists escape `&` and `<`.
2. **User data deletion is guarded.**
   - Removals go to the Trash or Recycle Bin. `uninstall.sh` deletes an app bundle only if its bundle id is `dev.cca.accounts`.
   - Backup pruning skips when a copy failed. Restore never overwrites.
3. **Shared settings and MCP definitions** cross accounts by design (documented). MCP definitions can hold keys; on macOS the copy is created with `umask 077`.
4. **Backups** are unencrypted, with owner-only permissions on macOS (documented).
5. **Temporary files** use `mktemp` and are removed. The backup lock expires after an hour.
6. **Desktop updates.**
   - macOS checks GitHub's per-asset SHA-256 digest and `codesign --verify --deep --strict`. Windows' electron-updater checks the SHA-512 in `latest.yml`.
   - These protect against corruption, not against a compromised GitHub account or release, because the builds are ad-hoc signed or unsigned.
   - Longer term: publish checksums in the release notes, and consider real code signing.
7. **Windows shim** runs with `-ExecutionPolicy Bypass`, scoped to that one bundled script (documented).
8. **Tests:** the isolation gaps G1–G4 in section 2.

## 9. Desktop rename analysis (BUG-008; nothing implemented)

What "Claude Accounts" (`productName`) controls today:

| Area | Effect of renaming to "CCA" | Needed |
|---|---|---|
| macOS bundle | `/Applications/Claude Accounts.app` | The self-updater replaces the bundle at its current path, so an upgraded install keeps the old folder name. It must move it to `CCA.app` (or accept the old name). Dock items pointing at the old path break |
| Windows | `Claude Accounts.exe`, install folder, Start menu and desktop shortcut names, uninstaller display name; `afterPack.js` writes "Claude Accounts" version strings | Keep `appId` `dev.cca.accounts` so electron-updater upgrades in place; check on a Windows machine that the old shortcuts and folder are replaced, not duplicated |
| Electron user data | `~/Library/Application Support/Claude Accounts`, `%APPDATA%\Claude Accounts` (follows the app name); `cca.js` keeps its shim fallback copy there | Re-created automatically; nothing user-critical lives there. CCA's own data in `~/.claude-accounts` is not affected |
| Hard-coded strings | tray tooltip, updater dialogs, `cca-shim.ps1` error, mac updater script comments | Update all |
| `uninstall.sh` | Looks for `Claude Accounts.app` only | Look for both names (the bundle id check keeps this safe) |
| Bundle id / `appId` | `dev.cca.accounts` | **Keep**, for update continuity and the uninstall check |

Proposal for Phase 3D:

- Rename `productName` to "CCA" and keep `appId` and `name`.
- Teach the macOS updater to move the bundle to `CCA.app`, and teach `uninstall.sh` both names.
- Update the strings.
- Try an upgrade from 0.1.12 on both platforms before release, and ship it as a minor version (0.2.0) with a note about the new name.

## 10. Proposed Phase 3B changes

In this order, each with its known-bug check turned into a normal assertion:

1. **BUG-002 (Windows wrong account):** at load, `cca.ps1` takes the account from `$env:CCA_ACCOUNT` when it names an existing account and `$global:CCA_ACCOUNT` is not set. `cca use -` must clear both. Check on a real Windows install.
2. **BUG-001 (uninstall):** make `uninstall.sh` testable (section 4), then boot out and delete `dev.cca.update.plist` too; add a behavioural test in a throwaway home with a stubbed `launchctl`. Remove the docs workaround.
3. **BUG-003 (no jq):** in `_cca_oauth`, fall back to a zsh regex read of `emailAddress` and `organizationName` (as `_cca_account_uuid` does). If parsing fails, say jq is missing instead of "not logged in". Do not fall back to `/usr/bin/python3`, which can open an install prompt on Macs without the developer tools, and the desktop app calls `cca list` often.
4. **BUG-004:** help text "the desktop app".
5. Test gaps G1–G4 (test-only).

Leave for 3C: BUG-005, BUG-006, BUG-007, the CI items. Leave for 3D: BUG-008.

## 11. Risks and rollback

- **Risk:** the new PowerShell known-bug check has run locally only in a copy of its logic. CI will run the real thing after a push.
  - Mitigation: it uses only helpers the suite already uses (`newbox`, `stubclaude`), and the file parses under PowerShell 7.
- **Risk:** a 3B fix to BUG-002 changes which account a new Windows window uses.
  - Mitigation: it only applies when the environment variable names an existing account, which only the desktop app sets.
- **Rollback:** everything in 3A is one commit on `test/phase-3a-regression`. `git revert <commit>`, or deleting the branch, removes it. No production code, release, job or remote setting changed.

## 12. Validation

| Check | Result |
|---|---|
| Production files changed (`cca.zsh`, `cca.ps1`, installers, `desktop/`) | none (`git diff --stat`: `tests/run.sh`, `tests/run.ps1`, this report) |
| Real user data accessed | no (`env -i`, throwaway homes, redirected CCA paths; the scratch home was empty after each run) |
| Real authentication | no (stub `claude` only) |
| launchd jobs / scheduled tasks / applications changed or quit | no |
| Remote GitHub settings, releases, pushes in 3A | none |
| Test results | zsh: 252 passed, 0 failed, 3 known bugs. `.ps1` parse: 10 parsed, 0 failed. Windows behavioural suite: not run locally (Windows only) |
| `tests/run.ps1` stays ASCII | yes |
