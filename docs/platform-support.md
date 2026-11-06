# Platform support

[← Back to README](../README.md)

## Status

| Area | macOS | Windows |
|---|---|---|
| CLI: `add`, `login`, `use`, `bind`, `unbind`, `run`, `list`, `remove` | Supported | Supported |
| Backup and restore | Supported | Supported |
| Daily autobackup | Supported (launchd) | Supported (Task Scheduler) |
| Claude app copy per account (`cca app`, `cca open`) | Supported | Supported |
| Claude Accounts desktop app | Supported (Apple silicon and Intel) | Supported (x64) |
| Claude Accounts self-update | Supported | Supported |
| Claude in Chrome per account (`cca chrome`) | Supported | Not available |
| Restart after Claude app updates (`cca update`, `cca autoupdate`) | Supported | Not available |
| `cca import` (old name of `restore`) | Supported | Not available |
| Linux | Not supported | — |

What the statuses mean:

- **Supported:** implemented, covered by the automated tests where they reach, and used on real installs: on macOS by the maintainer, on Windows by contributors (see below).
- **Not available:** not implemented on that platform.

## Evidence

The [test workflow](../.github/workflows/test.yml) runs on every push and pull request:

| Job | Runner | What it checks |
|---|---|---|
| `test` | macOS | `zsh -n cca.zsh`; the zsh test suite (`tests/run.sh`), which runs real `cca` commands in a throwaway home folder with a stub `claude`; a parse check of every `.ps1` file under PowerShell 7; `node --check` on every desktop app source file |
| `windows-powershell` | Windows | a parse check of every `.ps1` file under Windows PowerShell 5.1; the PowerShell test suite (`tests/run.ps1`), which runs real `cca` commands and the desktop app's PowerShell shim in a throwaway home folder with a stub `claude` |

Neither suite signs in to a real Claude account or starts the real Claude desktop app. The desktop app's own window, menus and updater have no automated tests; they are checked by hand.

Real-install use on Windows: the Windows port itself ([#1](https://github.com/AbbasAlsbihawi/cca/pull/1)) and later Windows fixes to `cca add`, account colours and the login check ([#7](https://github.com/AbbasAlsbihawi/cca/pull/7)) and to the Windows desktop app ([#12](https://github.com/AbbasAlsbihawi/cca/pull/12)) came from contributors who run CCA on Windows.

## Differences between macOS and Windows

| | macOS | Windows |
|---|---|---|
| Shell | zsh | Windows PowerShell 5.1 or PowerShell 7 |
| Shared files | symlinks | symlinks; falls back to junctions (folders) and hard links (files). Turn on Developer Mode for full symlink support. |
| `cca app` launcher | `~/Applications/Claude <Name>.app` | Start menu shortcut `Claude <Name>` |
| Finding the Claude desktop app | `/Applications/Claude.app` | usual install folders under `%LOCALAPPDATA%` or an installed app package; `CCA_CLAUDE_EXE` overrides |
| Removed accounts go to | the Trash | the Recycle Bin |
| Backups | APFS clones | plain copies |
| `cca list` sign-in check | reads `.claude.json` (with jq, or a simpler pattern without it) | reads `.claude.json` and asks `claude auth status` |
| Claude Accounts app and the CLI | needs `install.sh` first | carries its own `cca.ps1` |

## Known gaps

- Linux is not supported: the script relies on macOS paths and tools.
- The desktop features depend on undocumented Claude desktop app behaviour.
