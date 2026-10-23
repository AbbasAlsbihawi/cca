'use strict';
// electron-builder afterPack hook. On a Windows pack only, writes the exe icon and
// version strings with resedit (pure JS, so no wine is needed when cross-building from
// macOS). Everything else is a no-op, and nothing here may ever fail the build.

const fs = require('fs');
const path = require('path');

module.exports = async function afterPack(context) {
  try {
    if (!context || context.electronPlatformName !== 'win32') return;

    const ResEdit = require('resedit');
    const pkg = require('../package.json');
    const productName = context.packager.appInfo.productFilename;
    const exePath = path.join(context.appOutDir, `${productName}.exe`);
    if (!fs.existsSync(exePath)) {
      console.log(`[afterPack] exe not found, skipping: ${exePath}`);
      return;
    }

    const root = path.join(__dirname, '..');
    const icoCandidates = [
      path.join(root, 'build', 'icon.ico'),
      path.join(context.packager.buildResourcesDir || '', 'icon.ico'),
    ];
    const icoPath = icoCandidates.find((p) => p && fs.existsSync(p));

    const exe = ResEdit.NtExecutable.from(fs.readFileSync(exePath));
    const res = ResEdit.NtExecutableResource.from(exe);

    if (icoPath) {
      const iconFile = ResEdit.Data.IconFile.from(fs.readFileSync(icoPath));
      const groups = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries);
      const groupId = groups.length ? groups[0].id : 1;
      const lang = groups.length ? groups[0].lang : 1033;
      ResEdit.Resource.IconGroupEntry.replaceIconsForResource(
        res.entries,
        groupId,
        lang,
        iconFile.icons.map((i) => i.data)
      );
    } else {
      console.log('[afterPack] no icon.ico found, skipping icon write');
    }

    const version = pkg.version;
    const viList = ResEdit.Resource.VersionInfo.fromEntries(res.entries);
    const vi = viList[0] || ResEdit.Resource.VersionInfo.createEmpty();
    const lang = 1033;
    const codepage = 1200;
    vi.setFileVersion(version, lang);
    vi.setProductVersion(version, lang);
    vi.setStringValues(
      { lang, codepage },
      {
        ProductName: 'Claude Accounts',
        FileDescription: 'Claude Accounts',
        FileVersion: version,
        ProductVersion: version,
        CompanyName: 'Abbas Alsbihawi',
        LegalCopyright: 'Copyright (c) 2026 Abbas Alsbihawi',
        OriginalFilename: `${productName}.exe`,
        InternalName: 'Claude Accounts',
      }
    );
    vi.outputToResourceEntries(res.entries);

    res.outputResource(exe);
    fs.writeFileSync(exePath, Buffer.from(exe.generate()));
    console.log(`[afterPack] updated exe resources: ${exePath}`);
  } catch (err) {
    console.log(`[afterPack] skipped, non-fatal: ${err && err.message ? err.message : err}`);
  }
};
