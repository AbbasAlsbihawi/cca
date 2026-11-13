# Phase 3C report: CLI version and Windows restore parity

Date: 2026-11-06 · Branch: `feat/phase-3c-cli-versioning` (on top of `fix/phase-3b-stabilization`) · Pushed for CI · CI green · No pull request yet.

## 1. Executive summary

| Feature | Result |
|---|---|
| 001 `cca version` / `cca --version` | Done on both platforms; prints `cca <version>` from the one version source |
| Version architecture | `desktop/package.json` stays the source. A small script keeps the CLI version lines equal to it: through `npm version`, by hand, and as a CI check |
| 002 Windows `cca restore --dry-run` / `--account` | Done, matching macOS; a dry run changes nothing |
| 003 desktop package description | Updated; no identifier changed |
| 004 CI | Read-only token, installer syntax check, version check; nothing removed |
| Tests | zsh **311 passed, 0 failed**; Windows CI **282 passed, 0 failed** (24 new); both CI jobs green |

## 2. Owner approval and baseline

- **Approval:** the owner said "Start Phase 3C" and had already approved commits and pushes for CI in Phase 3 ("whatever you need, I agree").
- **Baseline:** `f254db1` (Phase 3B report) on `fix/phase-3b-stabilization`. New branch: `feat/phase-3c-cli-versioning`.
- **Untouched:** no earlier commit was changed, `main` was not touched, and no release was made.

## 3. Version architecture

What was there:

- `desktop/package.json` `version` (0.1.12) drives the desktop build, and `desktop/scripts/publish.sh` tags `v$V` from it.
- The CLIs had no version.
- `install.sh` copies `cca.zsh`, `install.ps1` copies `cca.ps1`, and the Windows desktop installer ships `cca.ps1` as an extra resource.

Design (the smallest reliable one):

- One line in each CLI holds the version: `typeset -g CCA_VERSION=0.1.12` in `cca.zsh` and `$script:CCA_VERSION = '0.1.12'` in `cca.ps1`. Installed copies therefore carry it with them: no repository, Git, network or jq needed at run time.
- `desktop/scripts/sync-version.js` (Node, no dependencies):
  - reads and validates the `package.json` version (`x.y.z` or `x.y.z-pre`)
  - requires exactly one version line per CLI
  - rewrites them, keeping the file's line endings, or with `--check` changes nothing and exits 1 on any mismatch
- `desktop/package.json` scripts:
  - `"version"` (npm's lifecycle hook, run by `npm version` after it bumps `package.json`)
  - `"sync:version"`, to run the sync by hand
  - `"check:version"`, to run the check
- **Checked with a real `npm version patch --no-git-tag-version` on a scratch copy.** It moved `package.json`, `cca.zsh` and `cca.ps1` from 0.1.12 to 0.1.13 together. There was no recursion (the script never calls npm), and the check passed afterwards. Since `--no-git-tag-version` is the documented release step, the two CLI files simply join the release commit with `package.json`, as `package.json` already does. No extra dirty files appear.
- `publish.sh` is unchanged. CI catches a mismatch before a release is cut from `main`.

## 4. CLI version implementation

- **macOS:** `cca version` and `cca --version` → `_cca_version`. It prints `cca <version>`, or exits 1 with "this copy of cca has no valid version" if the line was damaged. Both are listed in `cca help` and completion.
- **Windows:** `version` and `--version` → `Show-CcaVersion`, the same behaviour, plus help and completion.
- **No other command changed.**

## 5. Windows restore implementation

What macOS does:

- `-n` / `--dry-run` reports without changing anything.
- `--account <uuid>` names the **Claude account ID** whose Code-tab sessions in the main Claude app belong to this CCA account.

The prompt described `--account ACCOUNT_NAME`. That is not what the option means on macOS, so Windows follows macOS: the CCA account is still the first positional argument.

Changes in `cca.ps1`:

- **Options are parsed like zsh.** `-n` / `--dry-run` and `--account <value>` can come anywhere. Other words are positional, and more than two positionals is a usage error. `--account` without a value is an error on both platforms (zsh used to ignore it silently).
- **The `--account` value is used only if it matches `^[0-9A-Za-z-]+$`**, the same rule as before and as zsh. A value like `..\..\x` is never joined into a path.
- **A dry run changes nothing.** It creates no folder (the desktop folder included), copies no file and moves no deleted mark. It counts what would be copied, the deleted marks next to existing and to-be-copied sessions, and the files already there. Its message ends "Nothing was changed."
- **The real run is unchanged**, except that it also reports "Already there, left as is: N files", as macOS does.
- **Untouched:** the backup format, location and naming, overwrite protection (never overwrite), and the app-open refusal (a dry run is refused too, as on macOS).

## 6. Package metadata

The `desktop/package.json` description is now "CCA desktop app: a multi-account manager for Claude Code and the Claude desktop app." Unchanged: `name`, `productName`, `appId`, the executable and bundle names, user data paths, icons, update feed and `version`.

## 7. CI changes (`.github/workflows/test.yml`)

- `permissions: contents: read` for the whole workflow; the tests need nothing more.
- macOS job:
  - `sh -n install.sh && sh -n uninstall.sh`
  - `node --check` now also covers `desktop/scripts`
  - the new step "Check the CLI versions match desktop/package.json"
- **Unchanged:** the zsh suite (still self-isolating under `env -i`), both `.ps1` parse steps, and the Windows PowerShell 5.1 behavioural suite. PowerShell 7 behavioural coverage was not added: the suite targets 5.1, and 7 already parses every file.

## 8. Tests added

**zsh (§25, 17 checks):**

- `cca --version` and `cca version` equal `package.json`, also without jq and from outside the repository
- a damaged version line fails clearly
- help lists the command
- the real check passes
- on a copy: a mismatch fails, `--check` changes nothing, the sync rewrites both lines, the check passes after the sync, and an invalid package version fails
- `restore --account` without a value fails with a message

**PowerShell (24 checks, at the end of `run.ps1`):**

- version: `cca --version` and `cca version` equal `package.json`, exit 0
- restore dry run:
  - says what it would do, and changes nothing (a full listing of the box compared before and after)
  - a repeat says the same, and files already there are not counted again
- restore, real run: copies the transcript and never overwrites an existing file
- `--account`:
  - a dry run finds the main app's sessions for that ID and changes nothing; both option orders give the same result
  - a missing value and an unsafe value fail
  - the real run copies the session
- refusals: an unknown snapshot, an unsafe snapshot name, an extra name
- deleted marks: the dry run counts the mark and leaves it; the real run moves it to the test trash
- a malformed snapshot does not fail

## 9. Tests executed

| Check | Result |
|---|---|
| zsh suite, `env -i HOME=<scratch> TMPDIR=<scratch> PATH=…(incl. node) zsh -f tests/run.sh` | **311 passed, 0 failed**, no skips, no safety-stub notes; scratch folders empty |
| `pwsh` on macOS, the suite's helpers + all account, version and restore blocks | 38 passed, 0 failed |
| `pwsh -File tests/parse-ps1.ps1` | 10 parsed, 0 failed |
| `sh -n install.sh`, `sh -n uninstall.sh`, `zsh -n cca.zsh`, `node --check` (desktop incl. scripts) | ok |
| `node desktop/scripts/sync-version.js --check` | `cca.zsh: 0.1.12`, `cca.ps1: 0.1.12`, exit 0 |
| Real `npm version patch --no-git-tag-version` on a scratch copy | all three files moved to 0.1.13; check passed |
| Workflow YAML parsed | ok |
| GitHub Actions on `feat/phase-3c-cli-versioning`, [run 42139238624](https://github.com/AbbasAlsbihawi/cca/actions/runs/42139238624) | both jobs **success**. macOS: zsh suite 311 passed, 0 failed; version check `cca.zsh: 0.1.12`, `cca.ps1: 0.1.12`. Windows PowerShell 5.1: **282 passed, 0 failed** (258 + 24 new) |

## 10. Tests pending

- A real release with the new `"version"` script; it is exercised only on a scratch copy.
- Interactive use on a real Windows machine of `cca restore -n` against a real backup. CI covers it only with fixtures, by design.

## 11. Files changed

| File | Change |
|---|---|
| `cca.zsh` | `CCA_VERSION` line, `_cca_version`, dispatch, help, completion; `restore --account` needs a value |
| `cca.ps1` | `CCA_VERSION` line, `Show-CcaVersion`, dispatch, help, completion; restore options and dry run in `Invoke-CcaRestore` and `Copy-CcaMissing` |
| `desktop/scripts/sync-version.js` | new |
| `desktop/package.json` | description; `version`, `sync:version`, `check:version` scripts |
| `.github/workflows/test.yml` | permissions, installer syntax check, `node --check` of `desktop/scripts`, version check |
| `tests/run.sh`, `tests/run.ps1` | new checks (section 8) |
| `README.md`, `docs/cli-reference.md`, `docs/backup-restore.md`, `docs/platform-support.md`, `docs/installation.md`, `docs/development.md`, `SECURITY.md`, `.github/ISSUE_TEMPLATE/bug_report.yml`, `.github/ISSUE_TEMPLATE/windows_test_report.yml`, `CHANGELOG.md` | docs for the above |

## 12. Security considerations

- The version command reads only its own constant: no credentials, files or network.
- Restore keeps every existing guard: account name validation, the snapshot name pattern, the `--account` ID pattern, never overwriting, and refusing while the account's Claude app is open. The dry run removes all writes.
- The sync script writes only the two version lines in the repository, and only from a version that passed validation.
- CI now runs with a read-only token and still has no secrets.

## 13. Compatibility

- Every existing command and output is unchanged, except:
  - two new words, `version` and `--version`, which were "unknown command" before
  - restore on Windows prints one more line ("Already there…") when files exist
  - `--account` with no value now fails instead of being ignored
- Scripts parsing `cca list --json` are unaffected.
- The release flow is the same commands as before; `npm version` now also updates two lines.

## 14. Remaining limitations

- A copy of the CLI installed from a clone between releases reports the last released version.
- The version line is plain text in each CLI, so someone editing it by hand must run `npm run sync:version` instead; CI catches a mismatch.

## 15. Rollback

Two commits on `feat/phase-3c-cli-versioning` (`0d54258` code and tests, `1b1a291` docs) plus this report. Reverting them restores Phase 3B. Nothing outside the repository changed: no release, no settings, no job.

## 16. Phase 3D recommendations

- Rename `productName` from "Claude Accounts" to "CCA" and keep `appId` `dev.cca.accounts`.
- Teach the macOS updater to move the bundle to `CCA.app`, and teach `uninstall.sh` both names.
- Update the hard-coded strings (tray, updater, shim, `afterPack.js`).
- Try a real upgrade from v0.1.12 on macOS and Windows before choosing the version number; 0.2.0 is reasonable once the migration passes.
- Bump the version with `npm version minor --no-git-tag-version`, which now updates the CLIs too.
- Open the pull requests in order: #20 (docs) first, then Phase 3 (`fix/phase-3b-stabilization`, then `feat/phase-3c-cli-versioning`), so each stays easy to review.
