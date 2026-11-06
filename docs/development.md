# Development

[← Back to README](../README.md)

How to contribute, coding guidelines and pull request rules: [CONTRIBUTING.md](../CONTRIBUTING.md).

## Repository layout

| Path | What it is |
|---|---|
| `cca.zsh` | The macOS CLI |
| `cca.ps1` | The Windows CLI (Windows PowerShell 5.1 and PowerShell 7) |
| `install.sh`, `uninstall.sh` | macOS installer and uninstaller |
| `install.ps1`, `uninstall.ps1` | Windows installer and uninstaller |
| `tests/run.sh` | zsh test suite |
| `tests/run.ps1` | PowerShell test suite (Windows only) |
| `tests/parse-ps1.ps1` | Parse check of every `.ps1` file |
| `desktop/` | The Claude Accounts Electron app |
| `.github/workflows/test.yml` | CI |

## Tests

```sh
zsh tests/run.sh
```

The zsh suite restarts itself in a clean environment (only `PATH`, `TMPDIR` and the locale come through), runs every test in a throwaway folder inside `TMPDIR` with a stub `claude`, and puts safety stubs for `ps`, `open` and `launchctl` first on the `PATH`, so it never touches your real accounts, processes or launchd jobs. It stops before running anything if a path would still point outside the throwaway folder. The PowerShell suite drops every inherited `CCA_*` variable and `CLAUDE_CONFIG_DIR` before its first test.

On Windows:

```powershell
powershell -NoProfile -File tests\run.ps1
.\tests\parse-ps1.ps1
```

Keep `cca.ps1` and the PowerShell tests to Windows PowerShell 5.1 syntax.

CI runs both suites on every push and pull request; see [Platform support → Evidence](platform-support.md#evidence).

## Desktop app

The app needs Node.js 22 (see `.nvmrc`).

```sh
cd desktop
npm install
npm start        # or: npm run dev
```

On macOS the app runs `~/.claude-accounts/cca.zsh`, so install the CLI first.

## Releasing

For maintainers. Releases are built and published from a local machine; there is no CI release job.

```sh
cd desktop && npm install
npm version patch --no-git-tag-version
npm run dist:all
npm run release
```

To publish a version whose installer has not been tried on its own platform yet, add `-- --prerelease`. GitHub then marks the release as not production ready; the tag and the assets are the same.

Both platforms are unsigned (macOS builds are ad-hoc signed). The Windows artifacts are cross-built from macOS.
