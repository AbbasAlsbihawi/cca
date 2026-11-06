# Contributing to CCA

Thanks for helping improve CCA. Bug reports, testing on your platform, documentation fixes and code are all welcome. CCA is an independent project and is not affiliated with Anthropic.

## Ways to contribute

- **Report a bug** with the [bug report form](https://github.com/AbbasAlsbihawi/cca/issues/new/choose).
- **Test on your platform.** Reports from real macOS and Windows setups are valuable, especially for the desktop features. Use the Windows test report form for Windows.
- **Improve the documentation.** If something in the README or `docs/` is wrong or unclear, a small pull request is the fastest fix.
- **Propose a feature** with the feature request form. For larger changes, open an issue first so we can agree on the approach before you write code.
- **Fix a bug or add tests.** Issues labelled `good first issue` or `help wanted` are good starting points.
- **Report a security problem** privately, as described in [SECURITY.md](SECURITY.md). Do not open a public issue for it.

## Getting started

1. Fork the repository on GitHub and clone your fork:

   ```sh
   git clone https://github.com/<your-user>/cca.git
   cd cca
   ```

2. Create a branch for your change:

   ```sh
   git checkout -b fix/short-description
   ```

3. Make your change, run the tests (below), and update the docs if behaviour changed.
4. Push the branch to your fork and open a pull request against `main`. The pull request template lists what to include.

## Development setup

| Part | What you need |
|---|---|
| macOS CLI (`cca.zsh`) | macOS with zsh, and jq (`brew install jq`; the test suite uses it) |
| Windows CLI (`cca.ps1`) | Windows with Windows PowerShell 5.1 (the version `cca.ps1` targets); PowerShell 7 for extra checking |
| Desktop app (`desktop/`) | Node.js 22 (see `.nvmrc`), then `cd desktop && npm install && npm start` |

Claude Code is not needed to run the test suites: they use a stub `claude`. Repository layout, desktop development and releasing: [docs/development.md](docs/development.md).

## Running the tests

```sh
zsh tests/run.sh                                  # macOS
```

```powershell
powershell -NoProfile -File tests\run.ps1         # Windows
.\tests\parse-ps1.ps1                             # Windows: parse every .ps1
```

Both suites run every command in a throwaway home folder and never touch your real accounts. Do not change that: a test must never read or write `~/.claude`, `~/.claude-accounts` or the real Trash, Recycle Bin, Start menu or launchd jobs.

CI runs the macOS suite on macOS and the PowerShell suite under Windows PowerShell 5.1 on Windows for every push and pull request ([test workflow](.github/workflows/test.yml)). If you change Windows behaviour, please also try it on a real Windows machine where you can, and say in the pull request what you tested.

## How the code is organized

CCA has two implementations of the same CLI and one desktop app that calls them:

- `cca.zsh` (macOS) and `cca.ps1` (Windows) should behave the same where both platforms allow it. When you change one, change the other in the same pull request, or say why not. Keep messages, exit codes and the `cca list --json` format in step: the desktop app reads that format on both platforms.
- The desktop app never reimplements CCA. It runs the CLI and reads `cca list --json`.

## Coding guidelines

There is no linter or formatter configured. Match the style of the code around your change. These rules come from how the code is already written:

**Both CLIs**

- Validate input before using it: account names must match `^[a-z0-9][a-z0-9_-]*$`, snapshot names their date pattern.
- Never destroy user data. Removals go to the Trash (macOS) or Recycle Bin (Windows), and restore never overwrites a file. Keep those guarantees.
- A failing command prints an error to stderr starting with `cca:` and exits non-zero.

**zsh (`cca.zsh`)**

- Helper functions are named `_cca_<name>` and start with `emulate -L zsh`.
- Report errors with `_cca_err` and `return 1`.
- Quote and expand carefully: paths can contain spaces.

**PowerShell (`cca.ps1`)**

- Keep to Windows PowerShell 5.1 syntax: no `??`, `?.` or ternary operators. Keep the test files to plain ASCII.
- Report a failing command with `Write-CcaFail`, so `cca` sets a non-zero exit code.

**Desktop app (`desktop/`)**

- Run the CLI with an argument array, never a shell command string, so account names and paths are never interpreted by a shell.
- Do not let the renderer navigate away or open new windows.
- Discuss new runtime dependencies in an issue first.

**Comments and text**

- Write code comments, docs and commit messages in plain English.
- Comments explain why the code does something, not what it does.

## Documentation

If your change affects what users see or do, update the docs in the same pull request:

- commands and options: [docs/cli-reference.md](docs/cli-reference.md) and the command table in [README.md](README.md)
- platform differences: [docs/platform-support.md](docs/platform-support.md)
- anything about stored data, shared files or backups: [docs/privacy-security.md](docs/privacy-security.md), [docs/architecture.md](docs/architecture.md) or [docs/backup-restore.md](docs/backup-restore.md)

Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).

## Pull requests

- Keep each pull request to one change, with a clear description of what changed and why.
- Link the issue it fixes, if there is one.
- Show how you tested it: the commands you ran, and which platforms you tried.
- Call out anything you could not test, for example "Windows not tested".
- Never include credentials, tokens, real account emails, transcripts or other personal data in code, tests, screenshots or logs.

Commit messages in this repository start with the area they touch, then a short description, for example `cca chrome: …`, `Desktop app: …`, `Windows: …`, `Tests: …` or `CI: …`.

## Releases

Releases are built and published by the maintainer; see [docs/development.md](docs/development.md#releasing).

## Be kind

Be respectful and constructive in issues, pull requests and reviews. Assume good intent, and focus feedback on the work.

## License

CCA is released under the [MIT License](LICENSE). By contributing, you agree that your contributions are released under the same license.
