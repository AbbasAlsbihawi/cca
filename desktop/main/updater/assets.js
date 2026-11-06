// Which release file the macOS updater downloads. Kept apart from mac.js, which
// needs Electron, so the rules can be tested with plain Node.
//
// Release files are named CCA-<version>-... from 0.2.0 and ClaudeAccounts-<version>-...
// before; both are accepted. The 0.1.x updater looks for claudeaccounts-<version>-
// <arch>-mac.zip and otherwise takes any .zip containing -<arch>-mac, which the CCA
// names also match (see desktop/test/updater-assets.test.js).
'use strict';

const PREFIXES = ['cca', 'claudeaccounts'];

function releaseAssets(release) {
  return (release && Array.isArray(release.assets) ? release.assets : [])
    .filter((a) => a && typeof a.name === 'string' && a.browser_download_url);
}

// Keyed on the running architecture: installing an x64 build on arm64 (or the
// reverse) produces an app that cannot launch, so no match means no update.
function pickAsset(release, version, arch) {
  if (arch !== 'arm64' && arch !== 'x64') return null;
  const assets = releaseAssets(release);
  const name = (a) => a.name.toLowerCase();
  for (const p of PREFIXES) {
    const exact = `${p}-${version}-${arch}-mac.zip`;
    const hit = assets.find((a) => name(a) === exact);
    if (hit) return hit;
  }
  return assets.find((a) => name(a).endsWith('.zip') && name(a).includes(`-${arch}-mac`)) || null;
}

// The update-only zip names the Electron it was built with. Only an exact match
// with the running one is worth downloading; any other release, or one published
// without it, goes straight to the full zip.
function pickUpdateAsset(release, version, arch, electron) {
  if ((arch !== 'arm64' && arch !== 'x64') || !electron) return null;
  const assets = releaseAssets(release);
  for (const p of PREFIXES) {
    const exact = `${p}-${version}-${arch}-update-electron-${electron}.zip`.toLowerCase();
    const hit = assets.find((a) => a.name.toLowerCase() === exact);
    if (hit) return hit;
  }
  return null;
}

module.exports = { releaseAssets, pickAsset, pickUpdateAsset };
