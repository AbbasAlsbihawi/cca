// Release file choice for the macOS updater, run with: node --test desktop/test
// Covers the current rules (desktop/main/updater/assets.js) and the rules of the
// installed 0.1.12 updater, which performs the first update to a CCA release.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { pickAsset, pickUpdateAsset } = require('../main/updater/assets');

// Copied unchanged from v0.1.12 desktop/main/updater/mac.js, with arch and the
// Electron version passed in instead of read from process.
function releaseAssets012(release) {
  return (Array.isArray(release.assets) ? release.assets : [])
    .filter((a) => a && typeof a.name === 'string' && a.browser_download_url);
}
function pickAsset012(release, version, arch) {
  if (arch !== 'arm64' && arch !== 'x64') return null;
  const assets = releaseAssets012(release);
  const exact = `claudeaccounts-${version}-${arch}-mac.zip`;
  const name = (a) => a.name.toLowerCase();
  return assets.find((a) => name(a) === exact)
    || assets.find((a) => name(a).endsWith('.zip') && name(a).includes(`-${arch}-mac`))
    || null;
}
function pickUpdateAsset012(release, version, arch, electron) {
  if ((arch !== 'arm64' && arch !== 'x64') || !electron) return null;
  const exact = `claudeaccounts-${version}-${arch}-update-electron-${electron}.zip`.toLowerCase();
  return releaseAssets012(release).find((a) => a.name.toLowerCase() === exact) || null;
}

const asset = (name) => ({ name, browser_download_url: `https://example.invalid/${name}` });
const EV = '44.4.5';
const cca = { assets: [
  'CCA-0.2.0-arm64-mac.dmg', 'CCA-0.2.0-x64-mac.dmg',
  'CCA-0.2.0-arm64-mac.zip', 'CCA-0.2.0-x64-mac.zip',
  `CCA-0.2.0-arm64-update-electron-${EV}.zip`, `CCA-0.2.0-x64-update-electron-${EV}.zip`,
  'CCA-Setup-0.2.0.exe', 'CCA-Setup-0.2.0.exe.blockmap', 'latest.yml',
].map(asset) };
const old = { assets: [
  'ClaudeAccounts-0.1.12-arm64-mac.dmg', 'ClaudeAccounts-0.1.12-arm64-mac.zip', 'ClaudeAccounts-0.1.12-x64-mac.zip',
  `ClaudeAccounts-0.1.12-arm64-update-electron-${EV}.zip`, 'ClaudeAccounts-Setup-0.1.12.exe', 'latest.yml',
].map(asset) };
const fullOnly = { assets: cca.assets.filter((a) => !a.name.includes('update-electron')) };

test('the 0.1.12 updater finds the full CCA zip for its architecture', () => {
  assert.strictEqual(pickAsset012(cca, '0.2.0', 'arm64').name, 'CCA-0.2.0-arm64-mac.zip');
  assert.strictEqual(pickAsset012(cca, '0.2.0', 'x64').name, 'CCA-0.2.0-x64-mac.zip');
});

test('the 0.1.12 updater never takes a CCA update-only zip, so it downloads the full app', () => {
  assert.strictEqual(pickUpdateAsset012(cca, '0.2.0', 'arm64', EV), null);
  assert.strictEqual(pickUpdateAsset012(fullOnly, '0.2.0', 'arm64', EV), null);
});

test('the current updater picks the CCA full zip, and the update-only zip by exact name', () => {
  assert.strictEqual(pickAsset(cca, '0.2.0', 'arm64').name, 'CCA-0.2.0-arm64-mac.zip');
  assert.strictEqual(pickAsset(cca, '0.2.0', 'x64').name, 'CCA-0.2.0-x64-mac.zip');
  assert.strictEqual(pickUpdateAsset(cca, '0.2.0', 'arm64', EV).name, `CCA-0.2.0-arm64-update-electron-${EV}.zip`);
  assert.strictEqual(pickUpdateAsset(cca, '0.2.0', 'arm64', '45.0.0'), null);
  assert.strictEqual(pickUpdateAsset(fullOnly, '0.2.0', 'arm64', EV), null);
});

test('the current updater still reads releases with the old names', () => {
  assert.strictEqual(pickAsset(old, '0.1.12', 'arm64').name, 'ClaudeAccounts-0.1.12-arm64-mac.zip');
  assert.strictEqual(pickUpdateAsset(old, '0.1.12', 'arm64', EV).name, `ClaudeAccounts-0.1.12-arm64-update-electron-${EV}.zip`);
});

test('dmg, exe, blockmap and yml files are never picked; other architectures get nothing', () => {
  const noZip = { assets: cca.assets.filter((a) => !a.name.endsWith('.zip')) };
  assert.strictEqual(pickAsset(noZip, '0.2.0', 'arm64'), null);
  assert.strictEqual(pickAsset012(noZip, '0.2.0', 'arm64'), null);
  assert.strictEqual(pickAsset(cca, '0.2.0', 'ia32'), null);
  assert.strictEqual(pickAsset(null, '0.2.0', 'arm64'), null);
  assert.strictEqual(pickAsset({ assets: [{ name: 'CCA-0.2.0-arm64-mac.zip' }] }, '0.2.0', 'arm64'), null);
});
