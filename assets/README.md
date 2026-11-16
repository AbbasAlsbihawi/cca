# Images and media

The images used in the README and in `docs/`. Every `git clone` downloads this folder, so all files together stay under 6 MB and each screenshot under 600 KB.

## Windows screenshots

Taken on Windows 11 Pro (build 26300, ARM64) in a test virtual machine, where the x64 installer runs under emulation. They come from two local 0.2.0 candidate builds; neither was published.

| File | What it shows | Build it was taken from (installer SHA-256) | Used in |
|---|---|---|---|
| `screenshots/desktop-windows.png` | The desktop app, light mode | 0.2.0 candidate before #23: `4ce1b2e08b22e0ed5f8fed658d3cee4e5fe03ff7939f3bcff92f9ec1a52270f1` | README, `docs/desktop.md` |
| `screenshots/desktop-windows-dark.png` | The desktop app, dark mode | 0.2.0 candidate before #23: `4ce1b2e08b22e0ed5f8fed658d3cee4e5fe03ff7939f3bcff92f9ec1a52270f1` | README, `docs/desktop.md` |
| `screenshots/first-launch/windows-1-smartscreen.png` | SmartScreen: "Windows protected your PC" | 0.2.0 candidate before #23: `4ce1b2e08b22e0ed5f8fed658d3cee4e5fe03ff7939f3bcff92f9ec1a52270f1` | `docs/desktop.md`, First launch, Windows |
| `screenshots/first-launch/windows-2-run-anyway.png` | SmartScreen after *More info*, with *Run anyway* | 0.2.0 candidate before #23: `4ce1b2e08b22e0ed5f8fed658d3cee4e5fe03ff7939f3bcff92f9ec1a52270f1` | `docs/desktop.md`, First launch, Windows |
| `screenshots/first-launch/windows-3-install-options.png` | The installer's *Choose Installation Options* page | 0.2.0 candidate before #23: `4ce1b2e08b22e0ed5f8fed658d3cee4e5fe03ff7939f3bcff92f9ec1a52270f1` | `docs/desktop.md`, First launch, Windows |
| `screenshots/walkthrough/windows-1-add-account.png` | The *Add Account* sheet | 0.2.0 candidate before #23: `4ce1b2e08b22e0ed5f8fed658d3cee4e5fe03ff7939f3bcff92f9ec1a52270f1` | `docs/desktop.md`, What it does |
| `screenshots/walkthrough/windows-2-account-detail.png` | An account's page, with *Open Terminal* | 0.2.0 candidate before #23: `4ce1b2e08b22e0ed5f8fed658d3cee4e5fe03ff7939f3bcff92f9ec1a52270f1` | `docs/desktop.md`, What it does |
| `screenshots/walkthrough/windows-3-terminal.png` | The terminal from *Open Terminal*, on that account | 0.2.0 candidate after #23: `44bf0bef708918eb61aa9635d322fe1905022591429b663987a0fecc0c7788ab` | `docs/desktop.md`, What it does |

Only `walkthrough/windows-3-terminal.png` shows the behaviour fixed in [pull request #23](https://github.com/AbbasAlsbihawi/cca/pull/23): the terminal uses the chosen account. #23 changes only how the desktop app starts its Windows terminal, so nothing in the other images changed. An image is retaken when a change affects what it shows, not because the build hash changed.

## Other media

| File | What it shows | Source | Used in |
|---|---|---|---|
| `brand/cca-icon-256.png` | The CCA icon, 256 × 256 | Exported from `desktop/build/icon-master.svg` | README header |
| `demo/cca-demo.gif` | Terminal demo, 13.6 s, 1200 × 700: `cca list`, `cca use personal`, `cca list`, `cca bind acme ~/clients/acme` | Recorded on macOS with the CLI (`cca.zsh`) from main 15038c0; no desktop build involved | README |
| `social/social-preview.png` | The repository's social preview, 1280 × 640 | Drawn from the icon and text | Not in the docs. A maintainer uploads it under Settings → General → Social preview |

Not here yet: the desktop app on macOS (`screenshots/desktop.png`, `desktop-dark.png`) and the macOS first-launch steps. Comments in the README and in `docs/desktop.md` mark where they go.

## How they were made

- **Example data only.** Three accounts, `work`, `personal` and `acme`, with `.example` addresses; the Windows user is `demo`; a stub `claude` stands in for Claude Code, and nobody signed in to Claude.
- **Windows screenshots:** a temporary local user, Defender, SmartScreen and UAC on. Window-only captures, so no desktop, taskbar or notifications appear.
- **Terminal demo:** recorded with [VHS](https://github.com/charmbracelet/vhs) in throwaway home folders under `/tmp`. That is why `cca bind` prints `/private/tmp/cca/home/clients/acme`.
- **Checks before commit:** size, no metadata (EXIF, XMP, text chunks, comments), and text recognition on every image and every GIF frame against real names, email addresses, paths and tokens.

## Licences

- **Icon:** original artwork (`desktop/build/icon-master.svg`), MIT like the rest of the repository; see `desktop/build/ICON.md`.
- **Screenshots and demo:** captures of CCA itself, MIT like the rest of the repository. They show Windows dialogs (SmartScreen, the installer, the terminal) as the product in use.
- **Social preview:** its text is set in IBM Plex Sans 1.1.0, under the SIL Open Font License 1.1 (Reserved Font Name "Plex"). The font files are not in this repository.
- No Anthropic or Claude logos, no Anthropic typefaces, no stock photos and no AI-generated images.
