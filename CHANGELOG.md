# Changelog

All notable changes to CCA are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow the tags in this repository.

Each entry is taken from the Git tags, the GitHub release notes and the merged pull requests. Dates are the GitHub release dates (UTC). One version number, 0.1.7, was never tagged or released; see [0.1.7](#017---not-released).

## [Unreleased]

### Added

- `cca version` and `cca --version` on macOS and Windows. The version comes from `desktop/package.json`; `npm version` writes it into `cca.zsh` and `cca.ps1`, and CI fails if they differ.
- Windows: `cca restore` takes `--dry-run` (`-n`) and `--account <uuid>`, as on macOS. A dry run creates, copies and moves nothing.

### Fixed

- `cca restore --account` without a value is an error instead of being ignored (macOS).

- macOS: `uninstall.sh` also removes the autoupdate job; before, it kept running every minute after an uninstall.
- Windows: the desktop app's *New Terminal* opens PowerShell on the chosen account. `cca.ps1` now takes `CCA_ACCOUNT` from the environment unless `cca use` picked another account.
- macOS: without jq, `cca list` and `cca list --json` read account emails with a simpler pattern, and show a login they cannot read as unknown instead of "not logged in".
- `cca help` calls the desktop app "the desktop app", not "the Mac app".

### Changed

- CI: the workflow token is read-only; CI also syntax-checks `install.sh` and `uninstall.sh` and checks the CLI versions against `desktop/package.json`.
- The desktop app's package description now matches the CCA name. The installed app's name is unchanged.
- Tests: both suites start from a clean environment, keep every file inside the temporary folder, and stub LaunchServices, the process list, `open` and `launchctl`; `uninstall.sh` is now tested in a throwaway folder.
- The project is presented as CCA, a multi-account manager for Claude Code and the Claude desktop app. The repository, the `cca` command and the desktop app's current name are unchanged.

### Added

- Documentation for the public launch: a new README, guides under `docs/`, a contribution guide (`CONTRIBUTING.md`), a security policy (`SECURITY.md`), issue forms, a pull request template and this changelog.

## [0.1.12] - 2026-11-05

### Changed

- `cca login` and `cca remove` take a backup first only while autobackup is on, so `cca autobackup off` stops every automatic snapshot ([#19](https://github.com/AbbasAlsbihawi/cca/pull/19)).

### Fixed

- `cca chrome` works from the desktop app, where macOS blocks access to Chrome's folder: CCA keeps a copy of Chrome's profile list each time it reads it from Terminal ([#18](https://github.com/AbbasAlsbihawi/cca/pull/18)).

## [0.1.11] - 2026-11-03

### Added

- Desktop app: **Check Now** for updates ([#17](https://github.com/AbbasAlsbihawi/cca/pull/17)).

### Fixed

- Desktop app: an interrupted update download is retried ([#17](https://github.com/AbbasAlsbihawi/cca/pull/17)).
- `cca`: after CCA is updated, a new command works on the first call in an open terminal ([#17](https://github.com/AbbasAlsbihawi/cca/pull/17)).

## [0.1.10] - 2026-11-03

### Added

- `cca chrome`: a Chrome profile per account, for Claude in Chrome (macOS) ([#14](https://github.com/AbbasAlsbihawi/cca/pull/14)).

### Changed

- Desktop app (macOS): updates download only the app code when the Electron version is unchanged ([#16](https://github.com/AbbasAlsbihawi/cca/pull/16)).
- Desktop app (macOS): the build keeps only the English language files ([#15](https://github.com/AbbasAlsbihawi/cca/pull/15)).

## [0.1.9] - 2026-11-03

### Changed

- Desktop app: a window laid out like macOS System Settings ([#13](https://github.com/AbbasAlsbihawi/cca/pull/13)).

## [0.1.8] - 2026-11-02

### Added

- Desktop app: progress while an update downloads ([#11](https://github.com/AbbasAlsbihawi/cca/pull/11)). This change was prepared as 0.1.7.
- Windows desktop app: installs its own copy of `cca.ps1`, and reports a failed load ([#12](https://github.com/AbbasAlsbihawi/cca/pull/12), by [mustafaa960](https://github.com/mustafaa960)).

## 0.1.7 - Not released

The version number 0.1.7 was set in [#11](https://github.com/AbbasAlsbihawi/cca/pull/11), but no tag or GitHub release was made for it. Its changes shipped in 0.1.8.

## [0.1.6] - 2026-11-02

### Added

- Desktop app: sign in to an account's MCP servers, and restart Claude app copies ([#10](https://github.com/AbbasAlsbihawi/cca/pull/10)).

## [0.1.5] - 2026-11-01

### Added

- Connector (MCP) sign-ins per account; restarting Claude app copies after a Claude app update (`cca update`, `cca autoupdate`); shared links kept current as files are added to `~/.claude` ([#8](https://github.com/AbbasAlsbihawi/cca/pull/8)).
- Desktop app: an Autoupdate switch next to Autobackup (macOS) ([#9](https://github.com/AbbasAlsbihawi/cca/pull/9)).

## [0.1.4] - 2026-10-25

### Added

- Windows: account colours, with a saved colour and a tinted launcher icon ([#7](https://github.com/AbbasAlsbihawi/cca/pull/7), by [AhmedAbasss](https://github.com/AhmedAbasss)).
- Tests: which exit code wins, with a stub `claude` ([#6](https://github.com/AbbasAlsbihawi/cca/pull/6)).

### Fixed

- Windows: Add and Log in again; a failed start is reported; account names are checked; the login check asks Claude Code for the real state; a signed-out `claude`'s exit code no longer becomes CCA's ([#7](https://github.com/AbbasAlsbihawi/cca/pull/7), by [AhmedAbasss](https://github.com/AhmedAbasss)).

## [0.1.3] - 2026-10-23

### Fixed

- macOS: the desktop app is signed ad-hoc. Before this, macOS treated downloaded copies of 0.1.0 to 0.1.2 as damaged.

## [0.1.2] - 2026-10-23

### Added

- CI: every `.ps1` file is parsed under PowerShell 7 and Windows PowerShell 5.1 ([#4](https://github.com/AbbasAlsbihawi/cca/pull/4)).
- Tests: `cca.ps1`'s commands run on Windows in CI, not just parsed ([#5](https://github.com/AbbasAlsbihawi/cca/pull/5)).

### Changed

- Desktop app: the updater's state is shown as a sentence.

## [0.1.1] - 2026-10-23

### Fixed

- PowerShell: a failed `cca` command exits non-zero ([#3](https://github.com/AbbasAlsbihawi/cca/pull/3)).
- Desktop app: a missing latest release is no longer reported as a GitHub outage.

## [0.1.0] - 2026-10-23

First release.

### Added

- `cca`: switch Claude accounts in Claude Code and the Claude desktop app, with folder bindings, per-terminal accounts and a Claude app launcher per account with an optional icon colour.
- `cca remove`, and automatic reload of CCA in open terminals after an update.
- Backups: `cca backup`, `cca restore` (which absorbed the earlier `cca import`) and a daily autobackup.
- Windows PowerShell port: `cca.ps1`, `install.ps1` and `uninstall.ps1` ([#1](https://github.com/AbbasAlsbihawi/cca/pull/1), by [AhmedAbasss](https://github.com/AhmedAbasss)).
- Claude Accounts: one desktop app for macOS and Windows, with automatic updates ([#2](https://github.com/AbbasAlsbihawi/cca/pull/2)).

[Unreleased]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.12...HEAD
[0.1.12]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.11...v0.1.12
[0.1.11]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.10...v0.1.11
[0.1.10]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.9...v0.1.10
[0.1.9]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.8...v0.1.9
[0.1.8]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.6...v0.1.8
[0.1.6]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/AbbasAlsbihawi/cca/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/AbbasAlsbihawi/cca/releases/tag/v0.1.0
