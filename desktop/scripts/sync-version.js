#!/usr/bin/env node
// Keeps the version lines in cca.zsh and cca.ps1 equal to desktop/package.json,
// the one place the CCA version is set. `npm version` runs this as the
// "version" lifecycle script; `--check` (CI, and `npm run check:version`)
// changes nothing and fails when a line differs.
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const check = process.argv.includes('--check');

let version;
try {
  version = JSON.parse(fs.readFileSync(path.join(root, 'desktop', 'package.json'), 'utf8')).version;
} catch (err) {
  console.error(`sync-version: cannot read desktop/package.json: ${err.message}`);
  process.exit(1);
}
if (typeof version !== 'string' || !/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/.test(version)) {
  console.error(`sync-version: desktop/package.json has no valid version (${JSON.stringify(version)})`);
  process.exit(1);
}

const targets = [
  { file: 'cca.zsh', re: /^typeset -g CCA_VERSION=(.*?)\r?$/m, line: (v) => `typeset -g CCA_VERSION=${v}` },
  { file: 'cca.ps1', re: /^\$script:CCA_VERSION = '(.*?)'\r?$/m, line: (v) => `$script:CCA_VERSION = '${v}'` },
];

let failed = 0;
for (const t of targets) {
  const file = path.join(root, t.file);
  const text = fs.readFileSync(file, 'utf8');
  const count = (text.match(new RegExp(t.re.source, 'gm')) || []).length;
  if (count !== 1) {
    console.error(`sync-version: ${t.file} must have exactly one version line, found ${count}`);
    failed++;
    continue;
  }
  const current = text.match(t.re)[1];
  if (current === version) {
    console.log(`${t.file}: ${version}`);
    continue;
  }
  if (check) {
    console.error(`sync-version: ${t.file} says ${current}, desktop/package.json says ${version}. Run: cd desktop && npm run sync:version`);
    failed++;
    continue;
  }
  // Keep the line ending the file already uses.
  fs.writeFileSync(file, text.replace(t.re, (m) => t.line(version) + (m.endsWith('\r') ? '\r' : '')));
  console.log(`${t.file}: ${current} -> ${version}`);
}
process.exit(failed ? 1 : 0);
