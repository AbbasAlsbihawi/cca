# Phase 3D Gate C report: real install and upgrade tests (macOS and Windows)

Date: 2026-11-06 (macOS), 2026-11-11 (Windows) · Branch: `feat/phase-3d-desktop-rename` @ `388cb0d`, plus the Gate B.2 fix in the working tree (not committed) · No release, no pull request.

Status: **macOS done; Windows 11 ARM VM done.** The Windows tests found a second release blocker, fixed in Gate B.2 (not committed yet). Verdict for release: **NOT READY** until Gate B.2 is reviewed and committed with CI green, the contributor's native x64 run is done, and the remaining items below are done.

## Executive summary

- The tests ran in disposable macOS virtual machines: fresh install, upgrade, the real first update and uninstall. The owner's own Mac was never used for a candidate, and its state was compared before and after.
- **One release blocker was found and fixed.** The upgrade test (M2) showed that v0.1.12 keeps Electron's data in `<appData>/claude-accounts`. Gate B had pinned `<appData>/Claude Accounts`, so 0.2.0 started a new folder and could run next to a 0.1.12 copy. Gate B.1 (`5a0547e`, CI green) pins `claude-accounts`; every retest passed.
- **The real first update works.** The genuine, unmodified v0.1.12 updater found a 0.2.0 release on an isolated mock feed and picked the `CCA-…` zip. It verified and installed it in place, keeping the folder name `Claude Accounts.app`, and relaunched as CCA 0.2.0 with the data unchanged.
- **First launch of a downloaded copy is blocked by Gatekeeper**, because the app is ad-hoc signed. It opens after Privacy & Security → *Open Anyway*. The owner decided that 0.2.0 stays unsigned, with exact first-launch docs.
- **No AppTranslocation after a normal Finder install,** so the updater can write where the app lives. The translocation seen in M1 came from the test's own copy method.
- **Windows 11 ARM VM (the x64 installer under emulation):** fresh install, manual upgrade from v0.1.12, both real update paths, uninstall and single instance all pass with the Gate B.2 build. The data stays in `%APPDATA%\claude-accounts`, and the "Claude Accounts" shortcut becomes one "CCA" shortcut.
- **A second release blocker was found on Windows and fixed (Gate B.2).** The "Restart now" update (`--updated --force-run`) still showed the installer's "Choose Installation Options" page, so an update could move a per-user copy to Program Files behind a UAC prompt. `desktop/build/installer.nsh` now keeps the existing install scope on updates. All six Windows runs pass with the rebuilt installer, from per-user and per-machine installs.
- **Still open on Windows:** "list failed: timed out" under ARM emulation (a separate finding), the native x64 run, and the SmartScreen first-launch docs.

## Owner approvals

- "Start Stage 1", "Start Stage 2", "Start Stage 3A", "Start M1", "Start M2", "Start Gate B.1", "Commit and push" (B.1), "Start Finder test", "Start M3-A", "Start the report", "Run uninstall test".
- **Owner decisions:**
  - 0.2.0 stays unsigned (no company certificate), with first-launch docs.
  - Add a Windows 11 ARM VM test run by Claude Code before the contributor's x64 run.
- Windows: "Start Gate B.2" (the installer fix, rebuild and retests). The owner did the steps that need a person in the VM: Windows setup, SmartScreen, the first W1 and W2a installs, and the UAC prompts.
- ChatGPT reviewed each stage. It approved skipping M3-B, because the unmodified updater passed. It rated the Windows path A result a release blocker for 0.2.0 and approved Gate B.2 as an NSIS-only fix.

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
| Windows VM | UTM 5.0.8 (GitHub release, notarized), QEMU ARM virt, 4 CPU, 6 GB. Windows 11 Pro 26300 ARM64 from Microsoft's ISO (hash matches Microsoft's). x64 emulation, Defender on. UAC was off in the fresh VM and was turned on before W1. No snapshots (not supported with GPU acceleration), so each run starts from an uninstall plus a silent install of the baseline. |
| Windows access | Key-based SSH (session 0, elevated). Desktop actions run in session 1 through interactive scheduled tasks with the user's normal token, like a double-click. Screenshots come from session 1. The installer files in `Downloads` carry the download mark (MOTW); the update-path copies sit in `%LOCALAPPDATA%\claude-accounts-updater\pending` without it, as electron-updater leaves them. |
| Windows data | The same synthetic accounts and binding, plus a marker file in `%APPDATA%\claude-accounts`; hashes checked after every run. |

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

**Gate B.2 rebuild (2026-11-11), same scratch method, with the B.2 working-tree changes:**

| File | SHA-256 |
|---|---|
| `CCA-Setup-0.2.0.exe` | `d1637d6149b8723cb396afa05524006745285aef3816864529417d0c8a06cd94` |
| `CCA-Setup-0.2.0.exe.blockmap` | `e35be0cb19dddc896d7eab6d66156f4865e4068abf5b9294632c569a540ce065` |
| `latest.yml` | `541e9773141d9a57c63d0fabd95269ff0706a0f1a85e256e0c50dd6c9325d8a8` |
| `CCA-0.2.0-arm64-mac.zip` | `21b48e58f0b13355b8a33e92d752bf91739092a17190f47957b8ee85c583610b` |
| `CCA-0.2.0-x64-mac.zip` | `5a8d02df3088c66e3a319fe27b9f27b9de4ea362f9450f36119117ee96d7dd51` |

- `builder-debug.yml` shows the installer script `!include`s `desktop/build/installer.nsh`.
- B.2 changes only the Windows installer settings. The macOS app code is the same, so the macOS DMGs tested above stay the macOS candidates.
- **The DMG step hung twice in this scratch build** (once during a host load spike, once at normal load). Both times the image contents were written and then the image stayed mounted until the 30-minute limit. Afterwards nothing held the image and it unmounted at once. The zips were built both times. To check before the release build: build the DMGs alone and watch what keeps the fresh image busy (Spotlight or the antivirus are the first suspects).

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

All runs used the x64 installer under emulation in the Windows 11 ARM VM. Data hashes (marker, bindings, profiles) were unchanged after every run.

**The two real update paths** (from `desktop/main/updater/windows.js`, electron-updater 6 and the assisted NSIS template):
- **Path A, "Restart now":** `quitAndInstall()` runs the installer with `--updated --force-run`. It is not silent: progress page, then the Finish page; CCA starts from the Finish page's "Run CCA" box.
- **Path B, quit after the download:** `autoInstallOnAppQuit` runs `--updated /S`. Silent, no relaunch.
- The earlier plan's `--updated /S --force-run` matches neither path, so the two real ones were tested.

**First runs with the Gate C candidate (`4f0465e3…`):**
- **W1, fresh install:** PASS. SmartScreen "Windows protected your PC", "Unknown publisher", then *Run anyway* (expected, unsigned). Per-user install in `%LOCALAPPDATA%\Programs\Claude Accounts`, `CCA 0.2.0` in HKCU, one `CCA.lnk` in the Start Menu and on the Desktop, `userData` in `%APPDATA%\claude-accounts`.
- **Uninstall (`/S /currentuser`):** PASS. It removes the app folder, both registry keys and both shortcuts, and keeps `%APPDATA%\claude-accounts` and `~\.claude-accounts`. `/S` without the scope does nothing when run from SSH; Settings › Apps passes the scope itself.
- **W2a, manual upgrade over v0.1.12 (genuine, hash matches GitHub):** PASS. Same folder and exe, `CCA 0.2.0`, one `CCA.lnk` each, no "Claude Accounts.lnk" left, data unchanged.
- **Single instance in the desktop session:** PASS. A second launch exits and only the first copy stays. The first W1 check of this was invalid: the task command lost its quotes, so it never started a second copy. It was redone correctly.
- **Path B from per-user v0.1.12:** PASS.
- **Path A from per-user v0.1.12: FAIL (release blocker).** The installer showed "Choose Installation Options" during the update. The per-user copy was removed and CCA was installed for all users in `C:\Program Files\Claude Accounts` (HKLM, `/allusers`) after a UAC prompt. Data kept. **Cause:** electron-builder 26.15.3's assisted installer skips only the license and folder pages on `--updated`; the install-mode page still shows.

**Gate B.2 fix (working tree, not committed):**
- `desktop/build/installer.nsh`: the `customInstallMode` hook. When the installer runs with `--updated` and exactly one existing install is found, it keeps that scope (per-user or per-machine) and skips the page. Fresh installs, and machines with both scopes, behave as before; the uninstaller is unchanged.
- electron-builder 26 checks for the hook as `customInstallmode` (lowercase m; fixed in v27, electron-builder #10161), so the file also defines that name, empty, when it is missing.
- **Known limitation:** if a machine has both a per-user and a per-machine copy, an update still shows the options page and the user picks. B.2 does not choose silently in that case; it needs separate handling later.
- `package.json`: `build.nsis.include` and the explicit `CCA-Setup-${version}.exe` artifact name.
- `desktop/test/nsis-update-mode.test.js` (4 tests, added to CI): the config, the hook's logic, the lowercase fallback, and that the template still calls the hook.

**Retests with the B.2 installer (`d1637d61…`):**

| Run | Start state | Result |
|---|---|---|
| Path B `--updated /S` | per-user v0.1.12 | PASS: stays per-user, HKCU only, one `CCA.lnk` each, no relaunch |
| Path A `--updated --force-run` | per-user v0.1.12 | PASS: screenshot shows "Installing" with no input, so the page was skipped; stays per-user; CCA starts after Finish |
| Path B `--updated /S` | all-users v0.1.12 | PASS on try 2: UAC prompt, Yes; stays in Program Files, HKLM only, `CCA.lnk` in ProgramData Start Menu and Public Desktop, no HKCU key, no relaunch. Try 1: the prompt was not answered for about 80 minutes, the installer stopped with 1223 (elevation cancelled) and changed nothing |
| Path A `--updated --force-run` | all-users v0.1.12 | PASS: UAC prompt at start, Yes; "Installing" with no options page; stays in Program Files; after Finish CCA runs from Program Files as the normal user (started by Explorer, not elevated) |
| W1 fresh install | nothing installed | PASS: the options page still shows, "Only for me" preselected; per-user install; single instance PASS |
| W2a manual upgrade | per-user v0.1.12 | PASS: the options page shows "Only for me (Abbas)" and "There is already a per-user installation… Will reinstall/upgrade"; stays per-user; one `CCA.lnk` each; CCA starts after Finish |

- The uninstaller of 0.2.0 was used between runs for both scopes (`/S /currentuser`, `/S /allusers`). Each time the folder, registry keys and shortcuts were gone and the data was kept.
- **For the docs:** a silent update of an all-users install asks for UAC each time. If nobody answers, the update is skipped and the old version keeps working.

**Separate finding (not fixed, not in B.2):** under ARM emulation the app shows "list failed: timed out". The x64 Electron app runs `cca-shim.ps1 list --json` with a 60-second limit. The same command takes 18–24 seconds from native ARM64 PowerShell, but more than 60 seconds from the emulated app. It needs checking on native x64 Windows (contributor). Possible fixes later: a Windows arm64 build, a faster list path, or a longer first timeout.

**Still to do:** the contributor's native x64 run. ARM64 emulation does not replace it.

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
| Windows W1 fresh install, SmartScreen, shortcuts, userData (ARM VM) | PASS (Gate C build and B.2 build) |
| Windows single instance in the desktop session | PASS (first check invalid, redone) |
| Windows uninstall, per-user and all-users | PASS (data kept) |
| Windows W2a manual upgrade from v0.1.12 | PASS (Gate C build and B.2 build) |
| Windows path B `--updated /S`, per-user and all-users | PASS (all-users needs a UAC Yes) |
| Windows path A `--updated --force-run`, Gate C build | FAIL: moved a per-user copy to Program Files (fixed in B.2) |
| Windows path A `--updated --force-run`, B.2 build, per-user and all-users | PASS (scope kept, no options page) |
| Windows account list under ARM emulation | FINDING: "list failed: timed out" (separate) |
| Contributor x64 confirmation | NOT RUN |

## Release blockers

1. Gate B.2: review, commit, push and green CI (owner's order). Then the contributor's native x64 run, including the account list time.
2. First-launch docs: macOS 15/26 *Open Anyway* steps, and Windows SmartScreen *More info → Run anyway*. Update docs: on Windows "Restart now" shows a progress page and a Finish page; an all-users install asks for UAC on every update.
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
  - Windows: the account list time under ARM emulation (see the Windows section)
  - when moving to electron-builder 27, recheck `desktop/build/installer.nsh` (the hook guard is fixed there; the CI test fails if the template's hook call changes)
  - the DMG step that hung in the scratch build (see "Candidate builds")
- The owner's Mac stays on 0.1.11 until Windows passes; it updates itself once 0.2.0 is the latest release.
- **Signing later:** a personal Apple Developer ID would remove the first-launch block. On Windows, pick the signer name once, because electron-updater compares publisher names.
