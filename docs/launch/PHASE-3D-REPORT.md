# Phase 3D report: desktop app rename to CCA (Gate B)

Date: 2026-11-06 · Branch: `feat/phase-3d-desktop-rename` (on top of `feat/phase-3c-cli-versioning` @ `9e1afc9`) · Pushed for CI · CI green · No pull request yet · No release.

## Executive summary

The desktop app is now built as **CCA**. Its identity is unchanged, so installed 0.1.x copies update to it:

- `appId` `dev.cca.accounts`, package name `claude-accounts`
- the Electron data folder, pinned to its old path
- the Windows program file, `Claude Accounts.exe` (option W2)

The v0.1.12 updater's own rules are under test and pick the new `CCA-*` files. A real upgrade on real machines (Gate C) is still needed before any release.

## Owner approvals

- Gate A design reviewed by ChatGPT; its decisions were adopted (W2, userData pinned, CCA-* files proven against the old rules, skip the update-only zip, no folder rename of existing installs, no release).
- The owner said "Start Gate B".
- The owner said "Commit and push" for this branch. Gate C and any release need separate approval.

## macOS

- `productName` "CCA" builds `CCA.app`. Confirmed with `electron-builder --mac --dir`: CFBundleName and CFBundleExecutable are `CCA`, the bundle id is `dev.cca.accounts`, the helpers are `CCA Helper (…).app`, and `codesign --verify --deep --strict` passes.
- **Upgrade from 0.1.12.**
  - The installed updater reads `releases/latest` and takes `CCA-<v>-<arch>-mac.zip` through its fallback rule.
  - It never takes a `CCA-*` update-only zip (its exact-name rule wants `claudeaccounts-…`), so the first update always downloads the full app. `NO_UPDATE_ZIP=1` in `publish.sh` also keeps the small zip out of the rename release.
  - It swaps the bundle at its current path, so an upgraded Mac keeps the folder `Claude Accounts.app` with CCA inside. That is accepted for 0.2.0: no folder rename.
- **The new updater** (`updater/assets.js`) accepts both `CCA-` and `ClaudeAccounts-` names.

## Windows

- **W2:** `win.executableName` "Claude Accounts" keeps `Claude Accounts.exe`, while the display name, the uninstaller name and the default shortcut name become CCA. Confirmed with `electron-builder --win --x64 --dir`: `release/win-unpacked/Claude Accounts.exe`, with version resources written by `afterPack.js`.
- **The same `appId` gives the same NSIS GUID,** so electron-updater upgrades in place.
- **Open question for Gate C:** the shortcut name changes from "Claude Accounts" to "CCA". Because electron-builder keeps shortcuts during an update, an upgraded machine may show both. The old one still works, since the exe name is unchanged.

## Electron userData

`main.js` sets `userData` to `<appData>/Claude Accounts` before anything uses it, including the single-instance lock. An upgrade keeps what Electron stored there, and an old and a new copy cannot run at the same time.

## Installer, uninstaller, release tools

- **`uninstall.sh`:** removes `CCA.app` and `Claude Accounts.app` from `/Applications` and `~/Applications`, each only with bundle id `dev.cca.accounts`.
- **`publish.sh`:** asset list `CCA-*`, bundle checks on `CCA.app`, release title "CCA v…", and `NO_UPDATE_ZIP=1` to publish full zips only.
- **`update-zip.sh`:** `CCA-*` names and `CCA.app`.
- **`install.ps1`:** the message names `CCA-Setup-<version>.exe`.

## Files changed

| File | Change |
|---|---|
| `desktop/package.json` | `productName` CCA; `CCA-…` artifact names; `win.executableName` "Claude Accounts" |
| `desktop/main/main.js` | userData pinned to the old folder |
| `desktop/main/updater/assets.js` | new: release file choice, both name prefixes (pure, testable) |
| `desktop/main/updater/mac.js` | uses `assets.js`; strings and User-Agent say CCA |
| `desktop/main/updater/windows.js`, `tray.js`, `renderer/app.js`, `renderer/general.js`, `renderer/index.html`, `main/cca-shim.ps1`, `main/afterPack.js` | "CCA" in user-facing text and version strings |
| `desktop/scripts/publish.sh`, `desktop/scripts/update-zip.sh` | `CCA-*` names, `CCA.app`, `NO_UPDATE_ZIP` |
| `uninstall.sh`, `install.ps1` | both app names / new installer name |
| `desktop/test/updater-assets.test.js` | new unit tests |
| `tests/run.sh` | uninstall of both names, foreign `CCA.app` kept |
| `.github/workflows/test.yml` | runs the unit tests |
| `README.md`, `docs/*.md`, issue forms, `CHANGELOG.md` | "CCA desktop app", `CCA-…` files, a note on names before 0.2.0 |

## Regression tests

- **`desktop/test/updater-assets.test.js`** (5 tests): the v0.1.12 rules, copied verbatim from the `v0.1.12` tag, pick the CCA full zip for each architecture and never a CCA update-only zip. The current rules pick the CCA full and update-only zips and still read old-name releases. dmg, exe, blockmap and yml files are never picked, and other architectures get nothing.
- **`tests/run.sh`:** uninstall removes `CCA.app` and `Claude Accounts.app`, and keeps a foreign `CCA.app`.

## Local validation

| Check | Result |
|---|---|
| zsh suite (`env -i`, scratch HOME/TMPDIR) | **314 passed, 0 failed** |
| `node --test desktop/test/updater-assets.test.js` | 5 passed, 0 failed |
| `node desktop/scripts/sync-version.js --check` | `0.1.12` in both CLIs |
| `node --check` (desktop main, renderer, scripts, test), `sh -n` (uninstall, publish, update-zip), `.ps1` parse | ok |
| `electron-builder --mac --dir` / `--win --x64 --dir` (no install, no publish) | `CCA.app` (codesign verify ok) / `Claude Accounts.exe` |
| Links, issue forms | 92 links, 0 problems; forms valid |
| GitHub Actions on `feat/phase-3d-desktop-rename`, [run 42145074336](https://github.com/AbbasAlsbihawi/cca/actions/runs/42145074336) | both jobs **success**. macOS: zsh suite 314 passed, 0 failed; updater unit tests 5 passed, 0 failed; version check `cca.zsh: 0.1.12`, `cca.ps1: 0.1.12`. Windows PowerShell 5.1: **282 passed, 0 failed** |

## Compatibility matrix

| Path | Status |
|---|---|
| v0.1.12 macOS updater finds the CCA full zip | Automated test only |
| v0.1.12 macOS updater ignores a CCA update-only zip (full download) | Automated test only |
| macOS bundle name, id, helpers, signature | Verified (unpacked build) |
| macOS 0.1.12 → CCA auto-update (folder keeps old name) | Pending real-world test |
| Fresh macOS install of `CCA.app` | Pending real-world test |
| Windows exe stays `Claude Accounts.exe` | Verified (unpacked build) |
| Windows 0.1.12 → CCA upgrade, shortcuts, uninstall entry | Pending real-world test |
| userData kept across the upgrade | Automated test only (code path); pending real-world test |
| `uninstall.sh` with either name | Automated test only |
| CCA data in `~/.claude-accounts` | Not affected (no code path touches it) |

## Rollback

- **Before a release:** delete the branch or revert its commits (`4bd5b61` code and tests, `e9526a3` docs, and this report); nothing outside the repository changed.
- **After a release:** mark v0.1.12 as latest again to stop the rollout. Users can reinstall 0.1.12; `~/.claude-accounts` is untouched.

## Known limitations

- An upgraded Mac keeps the folder name `Claude Accounts.app`.
- On Windows the program file keeps its old name, and a second "CCA" shortcut may appear next to the old one.
- The old updater's swap is the real first-upgrade path. It is covered here only by its asset rules; the swap itself is unchanged.

## Release blockers

1. Gate C on a separate macOS user or VM: a fresh install, and an upgrade from 0.1.12.
2. Gate C on a contributor's Windows VM, with their consent: an upgrade from 0.1.12; shortcuts, folder, uninstall entry, launch, CLI.
3. `npm version minor --no-git-tag-version` (0.2.0, which also updates the CLIs). Then `NO_UPDATE_ZIP=1 npm run release -- --prerelease`, testing, and promotion to latest only after both pass.

## Recommended next phase

Gate C (separate approval), then Phase 4 (visual identity and demo). Merge the pull requests in order: #20, then Phase 3, then this branch together with the 0.2.0 release, because the docs here name `CCA-…` files.
