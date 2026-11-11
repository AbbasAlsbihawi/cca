// Windows installer update mode, run with: node --test desktop/test
// An update (installer run with --updated by electron-updater) must keep the
// existing install scope. desktop/build/installer.nsh hooks electron-builder's
// customInstallMode macro so the assisted installer's "Choose Installation
// Options" page is skipped on updates; Phase 3D Gate C found that a
// "Restart now" update could otherwise move a per-user copy to Program Files.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const desktop = path.join(__dirname, '..');
const pkg = JSON.parse(fs.readFileSync(path.join(desktop, 'package.json'), 'utf8'));
const nsis = pkg.build.nsis;
const includePath = path.join(desktop, nsis.include || '');
const template = path.join(desktop, 'node_modules', 'app-builder-lib', 'templates', 'nsis', 'multiUserUi.nsh');

// Script text without comments, so the checks look at directives only.
const script = () => fs.readFileSync(includePath, 'utf8')
  .split('\n').map((l) => l.replace(/;.*$/, '').trim()).filter(Boolean).join('\n');

test('the assisted per-user installer includes the update-mode script', () => {
  assert.strictEqual(nsis.oneClick, false, 'the hook targets the assisted installer');
  assert.notStrictEqual(nsis.perMachine, true, 'per-user is the default scope');
  assert.strictEqual(nsis.include, 'build/installer.nsh');
  assert.ok(fs.existsSync(includePath), 'desktop/build/installer.nsh exists');
});

test('customInstallMode keeps the existing scope, only on updates and only in the installer', () => {
  const s = script();
  assert.strictEqual((s.match(/^!macro customInstallMode$/gm) || []).length, 1, 'one customInstallMode definition');
  const body = s.slice(s.indexOf('!macro customInstallMode'), s.indexOf('!macroend'));
  assert.match(body, /^!ifndef BUILD_UNINSTALLER$/m, 'the uninstaller keeps its own logic');
  assert.match(body, /^\$\{if\} \$\{isUpdated\}$/m, 'only an update (--updated) skips the page');
  assert.match(body,
    /\$\{if\} \$hasPerUserInstallation == "1"\n\$\{andIf\} \$hasPerMachineInstallation == "0"\nStrCpy \$isForceCurrentInstall "1"/,
    'an existing per-user install stays per-user');
  assert.match(body,
    /\$\{elseIf\} \$hasPerMachineInstallation == "1"\n\$\{andIf\} \$hasPerUserInstallation == "0"\nStrCpy \$isForceMachineInstall "1"/,
    'an existing per-machine install stays per-machine');
  assert.strictEqual((body.match(/StrCpy \$isForce/g) || []).length, 2, 'no other forced scope (fresh or mixed installs unchanged)');
});

test('the hook is reachable under the guard electron-builder 26 uses (customInstallmode)', () => {
  const s = script();
  assert.match(s, /^!ifmacrondef customInstallmode\n!macro customInstallmode\n!macroend\n!endif$/m,
    'a lowercase fallback, defined only when the documented name is not visible to that guard');
});

test('the electron-builder template still calls customInstallMode', { skip: !fs.existsSync(template) && 'desktop/node_modules not installed' }, () => {
  const t = fs.readFileSync(template, 'utf8');
  assert.match(t, /!ifmacrodef customInstall[mM]ode\s*\n\s*!insertmacro customInstallMode/,
    'electron-builder changed the install-mode hook; recheck desktop/build/installer.nsh');
  assert.match(t, /Var isForceMachineInstall/);
  assert.match(t, /Var isForceCurrentInstall/);
});
