# Phase 3D Gate C report: real install and upgrade tests (macOS part)

Date: 2026-11-06 · Branch: `feat/phase-3d-desktop-rename` @ `54b9344` · Not committed yet · No release, no pull request.

Status: **macOS done; Windows not run yet.** Verdict for release: **NOT READY** until the Windows tests and the remaining items below are done.

## Executive summary

- The tests ran in disposable macOS virtual machines: fresh install, upgrade, the real first update and uninstall. The owner's own Mac was never used for a candidate, and its state was compared before and after.
- **One release blocker was found and fixed.** The upgrade test (M2) showed that v0.1.12 keeps Electron's data in `<appData>/claude-accounts`. Gate B had pinned `<appData>/Claude Accounts`, so 0.2.0 started a new folder and could run next to a 0.1.12 copy. Gate B.1 (`5a0547e`, CI green) pins `claude-accounts`; every retest passed.
- **The real first update works.** The genuine, unmodified v0.1.12 updater found a 0.2.0 release on an isolated mock feed and picked the `CCA-…` zip. It verified and installed it in place, keeping the folder name `Claude Accounts.app`, and relaunched as CCA 0.2.0 with the data unchanged.
- **First launch of a downloaded copy is blocked by Gatekeeper**, because the app is ad-hoc signed. It opens after Privacy & Security → *Open Anyway*. The owner decided that 0.2.0 stays unsigned, with exact first-launch docs.
- **No AppTranslocation after a normal Finder install,** so the updater can write where the app lives. The translocation seen in M1 came from the test's own copy method.

## Owner approvals

- "Start Stage 1", "Start Stage 2", "Start Stage 3A", "Start M1", "Start M2", "Start Gate B.1", "Commit and push" (B.1), "Start Finder test", "Start M3-A", "Start the report", "Run uninstall test".
- **Owner decisions:**
  - 0.2.0 stays unsigned (no company certificate), with first-launch docs.
  - Add a Windows 11 ARM VM test run by Claude Code before the contributor's x64 run.
- ChatGPT reviewed each stage. It approved skipping M3-B, because the unmodified updater passed.

## Test environments

| Item | Value |
|---|---|
| Host | Apple M2 Pro, 16 GB, macOS 27.2. Its own `Claude Accounts.app` 0.1.11 was never touched. |
| Host isolation | Baseline compared before and after each stage: the app's version, date and `Info.plist` hash, `/Applications` entries, launch agents, launchd jobs and LaunchServices entries for `dev.cca.accounts`. All unchanged. |
| VM tool | Tart 2.32.1, from the official GitHub release; checksum and notarized Developer ID signature checked. Homebrew 7 rejects the tap's formula. |
| VM image | `ghcr.io/cirruslabs/macos-tahoe-vanilla` (digest `eeec54bf…`), macOS 26.6.2 (25G83), arm64. 4 CPU, 8 GB. |
| Clean snapshot `cca-clean` | The image plus a dedicated test SSH key, plus Gatekeeper turned on. The vanilla image ships with Gatekeeper assessments **disabled**. |
| Upgrade baseline `cca-m2base` | `cca-clean` plus the genuine v0.1.12, as described under "Upgrade from v0.1.12" below. |
| Access | Key-based SSH (the owner entered the image's default password once); Screen Sharing for the owner's clicks. `screencapture` over SSH is denied, so screenshots were not taken; this report uses window lists, process paths, logs and hashes. |
| Data | Synthetic only: accounts `demo-work` and `demo-personal`, binding `~/projects/demo → demo-work`, no Claude login. |

## Candidate builds

- Built in a scratch copy of the branch, with `npm version 0.2.0 --no-git-tag-version` in that copy only, and `electron-builder … --publish never`.
- The desktop code is identical to `5a0547e` (Gate B.1). Nothing was published.

| File | SHA-256 |
|---|---|
| `CCA-0.2.0-arm64-mac.dmg` | `40097326bb049fada0efb583c5cec2d3b69a91f09f0a93344fd8f7273eed9578` |
| `CCA-0.2.0-x64-mac.dmg` | `c134f5ae7d68207676411e9186eddaf4f7a04f47c3807ca63c59efdf8d9ded2c` |
| `CCA-0.2.0-arm64-mac.zip` | `9e28cc588987e7dbe2c244a023d6f13b21e2ec903e5e68b3df2836db3039c2ea` |
| `CCA-0.2.0-x64-mac.zip` | `0d577398e7c998ac9e09b7afa9b8733ac64022435ec28b720ecdd45665b22bfb` |
| `CCA-Setup-0.2.0.exe` | `4f0465e3dbda430b8194dba5d40bda503952ae36a64fdbd2c91b87fef005d2e4` |
| `CCA-Setup-0.2.0.exe.blockmap` | `c76322a5464fd362fac889e84c0e2f8e60dd67c50a7f535ce5838b6bd20a111b` |
| `latest.yml` | `56b3494a949523af480013b93c92ce59d4ef85b376ff3ee5afe0c735590551c3` |

**Checks on the build:**
- Both macOS architectures: `CCA`, `dev.cca.accounts`, 0.2.0, ad-hoc signed, `codesign --verify --deep --strict` passes.
- No update-only zip. The `publish.sh` file list, run alone with stubbed commands, uploads exactly the 7 files above when `NO_UPDATE_ZIP=1` is set.
- Windows installer settings: GUID `8a5b5904-a939-5366-a9c8-063f626483ae`, the same as 0.1.12 because it is derived from the appId. Install folder and exe `Claude Accounts`, shortcut `CCA`, uninstall name `CCA 0.2.0`.

## macOS: fresh install (M1)

- **Steps:**
  1. The dmg was copied in and given a Safari-style quarantine attribute.
  2. The CLI 0.2.0 was installed with `install.sh`.
  3. `CCA.app` was copied to `/Applications`, then opened.
- **First launch:** blocked by Gatekeeper. `spctl` reports "rejected", and `syspolicy_check` reports "Adhoc Signed App". The process was held, and the only window was the system alert.
- **Approval:** the owner cleared it in Privacy & Security → *Open Anyway*, inside the VM. The quarantine flag changed from `0083` to `00c3`.
- **After approval:**
  - the CCA window shows
  - one main process; a second launch (`open -n`) exits
  - clean quit, and a relaunch with no alert
  - no launch agents added
  - the app polls `cca list --json`, and the data hashes are equal before and after a relaunch
- The account list inside the window was not confirmed by eye.
- **Recheck with the B.1 build:** first launch creates only `<appData>/claude-accounts`.

## macOS: upgrade from v0.1.12 (M2)

- **Baseline (`cca-m2base`):**
  - the genuine `ClaudeAccounts-0.1.12-arm64-mac.dmg`, whose SHA-256 equals the GitHub digest, installed as `/Applications/Claude Accounts.app`
  - CLI v0.1.12, the synthetic data, and a marker file in `<appData>/claude-accounts`
- **First run (Gate B build): FAIL.** 0.2.0 used a new `<appData>/Claude Accounts`. With the old app running, opening `CCA.app` started a second app, so two windows and two locks.
- **After Gate B.1:**
  - **M2b, in-place replacement** (the post-update state): `/Applications/Claude Accounts.app/Contents/MacOS/CCA` runs and uses `claude-accounts`; the lock is owned by its process. No new folder appears, and the marker and data hashes are identical.
  - **M2a, `CCA.app` next to `Claude Accounts.app`:** in both launch orders, the second app exits, whether opened normally or with `open -n`. One window.
  - Opening by bundle id picks the newest version.
  - The old app was not deleted.

## macOS: Finder install and AppTranslocation

- **Steps:**
  1. The owner dragged `CCA.app` from the dmg window to Applications in Finder. Finder set quarantine flag `0183`.
  2. The app was launched through LaunchServices.
- **Result:** it ran from `/Applications/CCA.app/Contents/MacOS/CCA`, not from an `AppTranslocation` path.
- **The updater's writability probe passes:** a file next to the bundle can be created and removed, and the bundle is writable. No update was run.
- M1's translocation came from copying with `ditto`.
- When the app does run translocated, the updater refuses safely, but its message ("not writable") does not say why.
- The owner's *Open Anyway* in this VM did not complete. That step is covered by M1.

## macOS: the v0.1.12 updater (M3-A)

**Setup, inside the VM only:**
- `/etc/hosts` maps `api.github.com` to 127.0.0.1.
- A mock feed with a VM-only test CA serves a fake v0.2.0 release. It contains the fixed arm64 zip with its real size and SHA-256.
- The binary is unmodified (codesign passes).

**Trust attempts:**

| Attempt | Result |
|---|---|
| No change | Certificate rejected in the handshake |
| CA added to the System keychain | Refused over SSH (needs user interaction); still rejected |
| `NODE_EXTRA_CA_CERTS` through `launchctl setenv` and `open` | Rejected |
| `NODE_EXTRA_CA_CERTS` on a direct exec of the unmodified binary | Accepted |

**With the direct exec**, the real v0.1.12 updater:
1. Requested `releases/latest`.
2. Chose `CCA-0.2.0-arm64-mac.zip` by its fallback rule, as the unit test predicted.
3. Downloaded it and passed its size, digest, `ditto` and `codesign` checks.
4. Showed "Claude Accounts 0.2.0 is ready to install". The owner chose *Install and restart*.

**After the swap:**
- `/Applications/Claude Accounts.app` holds CCA 0.2.0, with the folder name kept. Codesign passes, there is no quarantine and no `.old` or `.new` leftover.
- The app relaunched itself from that path with its window.
- `userData` is `claude-accounts`, and the marker and data are identical.
- The relaunched 0.2.0 checked the feed itself (`CCA/0.2.0`) and found nothing newer.
- **Minor:** the detached swap script file stays in `$TMPDIR`.

**Limits:**
- The test needed `NODE_EXTRA_CA_CERTS` on a direct exec to trust the mock. A real update talks to the real GitHub and needs no such step.
- Before SSH was up, the auto-started old app probably made one normal read-only request to the real `releases/latest`. The latest release is still v0.1.12, so there was nothing to do.

## macOS: uninstall

**Setup:**
- A clone of the upgraded M3-A VM: `/Applications/Claude Accounts.app` holds CCA 0.2.0, and the app is running.
- Command: the branch's `uninstall.sh`, run as `sh uninstall.sh`.

**First run, with the app running:**
- Removed:
  - the two `.zshrc` lines (a backup was written)
  - `~/.claude-accounts/cca.zsh`
  - `/Applications/Claude Accounts.app` (bundle id checked)
- Kept:
  - `~/.claude-accounts` with `profiles/demo-*` and `bindings` (hash unchanged)
  - `<appData>/claude-accounts` with the marker
- Exit 0. The message lists what was kept and how to remove it by hand.

**Second run:** exit 0, nothing else removed; it writes one more `.zshrc` backup.

**Fresh `CCA.app` next to a foreign app:** with `/Applications/CCA.app` (0.2.0) and a foreign `~/Applications/CCA.app` (bundle id `com.example.other`), only ours was removed.

**Limits:**
- It does not quit a running app. The process kept running from the removed bundle until it was quit, and then it quit cleanly.
- `<appData>/claude-accounts` (Electron caches and state) stays. Neither the message nor the docs mention it.
- No launchd jobs were enabled in this VM; their removal is covered by `tests/run.sh`.

## Rollback (not run)

Rollback was not tested. Manual procedure if 0.2.0 has to be withdrawn:

1. On GitHub, mark v0.1.12 as the latest release again. This stops new updates, because the 0.1.x and 0.2.0 updaters only move to a newer `releases/latest`.
2. Machines that already updated stay on 0.2.0; no updater downgrades. To go back on a Mac:
   1. Quit CCA.
   2. Move `/Applications/Claude Accounts.app` or `CCA.app` to the Trash.
   3. Install `ClaudeAccounts-0.1.12-<arch>-mac.dmg` from the v0.1.12 release.
   4. Allow the first launch with *Open Anyway*.
3. Data is kept: `~/.claude-accounts` is never touched by the app, and 0.1.12 and 0.2.0 share `<appData>/claude-accounts`.

**Risks:**
- If step 1 is skipped, a reinstalled 0.1.12 updates itself back to 0.2.0.
- A CLI installed from 0.2.0 stays at 0.2.0 until `install.sh` from v0.1.12 is run.
- On Windows, installing 0.1.12 over 0.2.0 (same GUID) is untested.

## Windows

**Not run yet.** The code reading and the build settings give these expectations:
- Same GUID, folder and exe, so the installer upgrades in place.
- The installer renames the "Claude Accounts" shortcut to "CCA" on upgrade: `--keep-shortcuts` and `Rename` on an auto-update; delete and create on a manual run. One shortcut is expected, not two. This corrects the Gate B report's "may show both".
- `userData` at `%APPDATA%\claude-accounts`.

**Planned:**
1. Claude Code runs W1 (fresh), W2a (manual upgrade), W2b (`--updated /S --force-run`), shortcuts, uninstall and data checks in a Windows 11 ARM VM (UTM, x64 installer under emulation).
2. Then the contributor's x64 run.

## Evidence matrix

| Test | Result |
|---|---|
| Candidate build checks (identity, signature, names, checksums, file list) | PASS |
| M1 fresh install: install, identity, window, single instance, quit and relaunch | PASS |
| M1 first launch of a downloaded copy | BLOCKED by Gatekeeper (expected, unsigned); cleared by *Open Anyway* |
| M1 account list seen by eye | NOT RUN |
| M2 upgrade, Gate B build: userData and single instance | FAIL (fixed in B.1) |
| M2b in-place upgrade, B.1 build | PASS |
| M2a coexistence, cross-version single instance, both orders, B.1 build | PASS |
| Fresh install creates `claude-accounts`, B.1 build | PASS |
| Finder install: no AppTranslocation; updater writability | PASS |
| M3-A unmodified v0.1.12 updater: discovery, choice, download, checks, swap, relaunch, data | PASS (trust through `NODE_EXTRA_CA_CERTS` on a direct exec) |
| M3-B instrumented v0.1.12 build | NOT RUN (not needed) |
| Data preservation across every macOS test | PASS |
| macOS uninstall (`uninstall.sh`): upgraded `Claude Accounts.app`, fresh `CCA.app`, foreign `CCA.app` kept, data kept, repeat run | PASS (does not quit a running app; leaves `<appData>/claude-accounts`) |
| macOS rollback (reinstall 0.1.12 over 0.2.0) | NOT RUN (manual procedure and risks documented) |
| Windows W1, W2a, W2b, shortcuts, uninstall, userData | NOT RUN |
| Contributor x64 confirmation | NOT RUN |

## Release blockers

1. Windows tests (ARM VM, then contributor x64).
2. First-launch docs: macOS 15/26 *Open Anyway* steps, and Windows SmartScreen *More info → Run anyway*.
3. Rollback is documented, not tested. Release order:
   - merge #20, then Phase 3, then this branch
   - `npm version minor --no-git-tag-version`, then `NO_UPDATE_ZIP=1 npm run release -- --prerelease` from `main`
   - test, then promote

## Recommendations

- Keep `claude-accounts` pinned, and keep the userData test in CI.
- **Later improvements:**
  - a clear updater message when CCA runs from an AppTranslocation path ("move CCA to Applications with Finder")
  - removing the swap script after use
  - correcting the Gate B report's Windows shortcut sentence
- The owner's Mac stays on 0.1.11 until Windows passes; it updates itself once 0.2.0 is the latest release.
- **Signing later:** a personal Apple Developer ID would remove the first-launch block. On Windows, pick the signer name once, because electron-updater compares publisher names.
