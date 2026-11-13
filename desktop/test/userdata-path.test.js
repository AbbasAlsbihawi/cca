// Electron data folder (userData), run with: node --test desktop/test
// Electron names it after the app name, which is package.json "name" unless a
// top-level productName exists. Every 0.1.x copy used <appData>/claude-accounts,
// and main.js pins that folder so an upgrade keeps it and an old and a new copy
// share one single-instance lock.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const desktop = path.join(__dirname, '..');
const pkg = JSON.parse(fs.readFileSync(path.join(desktop, 'package.json'), 'utf8'));
const main = fs.readFileSync(path.join(desktop, 'main', 'main.js'), 'utf8');

// The folder every released 0.1.x copy used (package "name", no top-level productName).
const LEGACY_FOLDER = 'claude-accounts';

const PIN = /app\.setPath\(\s*'userData'\s*,\s*path\.join\(\s*app\.getPath\(\s*'appData'\s*\)\s*,\s*'([^']+)'\s*\)\s*\)/g;

test('main.js pins userData to the folder 0.1.x used', () => {
  const pins = [...main.matchAll(PIN)];
  assert.strictEqual(pins.length, 1, 'exactly one userData pin of the form path.join(appData, "<folder>")');
  assert.strictEqual(pins[0][1], LEGACY_FOLDER);
  assert.strictEqual((main.match(/setPath\(\s*'userData'/g) || []).length, 1, 'no other userData setPath');
});

test('the pinned folder equals package.json name, which Electron used before the pin', () => {
  assert.strictEqual(pkg.name, LEGACY_FOLDER,
    'package.json "name" also names the electron-updater cache and the NSIS package; changing it needs a migration');
  assert.strictEqual(pkg.productName, undefined,
    'a top-level productName changes the app name Electron sees; the pin keeps the folder, but check the other uses');
});

test('userData is pinned before the single-instance lock and before the app is ready', () => {
  const pinAt = main.search(/app\.setPath\(\s*'userData'/);
  const lockAt = main.indexOf('requestSingleInstanceLock');
  const readyAt = main.search(/app\.(whenReady|on\(\s*'ready')/);
  assert.ok(pinAt >= 0 && lockAt > pinAt, 'setPath(userData) must come before requestSingleInstanceLock');
  assert.ok(readyAt < 0 || readyAt > pinAt, 'setPath(userData) must come before ready');
  const firstUse = main.search(/getPath\(\s*'userData'\s*\)/);
  assert.ok(firstUse < 0 || firstUse > pinAt, 'nothing in main.js reads userData before the pin');
});
