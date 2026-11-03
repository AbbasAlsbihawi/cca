'use strict';
// Every renderer -> main channel. The renderer only ever sees these results.
const { app, dialog, ipcMain, systemPreferences } = require('electron');
const { runCca, listAccounts, bus } = require('./cca');
const { runInteractive } = require('./interactive');

const RUN_VERBS = new Set(['open', 'app', 'chrome', 'bind', 'unbind', 'backup', 'autobackup', 'autoupdate', 'update', 'remove', 'restore']);
// `update` waits up to a minute for each open Claude copy to quit; killing it half way
// would leave the copies it already quit closed.
const SLOW_MS = { update: 15 * 60 * 1000 };

function isArgs(a) {
  return Array.isArray(a) && a.every((x) => typeof x === 'string');
}

function registerIpc(win) {
  // One listener forwards every change (from any source) to the window.
  bus.on('changed', () => {
    if (win && !win.isDestroyed()) win.webContents.send('cca:changed');
  });
  const changed = () => bus.emit('changed');

  ipcMain.handle('cca:list', () => listAccounts());

  ipcMain.handle('cca:run', async (_e, args) => {
    if (!isArgs(args) || !RUN_VERBS.has(args[0])) return { code: -1, stdout: '', stderr: 'verb not allowed' };
    const r = await runCca(args, SLOW_MS[args[0]]);
    if (r.code === 0) changed();
    return r;
  });

  ipcMain.handle('cca:interactive', (_e, args) => {
    if (!isArgs(args)) return { ok: false, error: 'invalid arguments' };
    return runInteractive(args, changed);
  });

  ipcMain.handle('cca:restore-preview', (_e, args) => {
    if (!isArgs(args)) return { code: -1, stdout: '', stderr: 'invalid arguments' };
    // The renderer sends ['restore','-n',name,snap]; drop the verb and the flag so they are not doubled.
    const rest = args.slice(args[0] === 'restore' ? 1 : 0).filter((a) => a !== '-n' && a !== '--dry-run');
    return runCca(['restore', '-n', ...rest]);
  });

  ipcMain.handle('app:info', () => {
    // The accent colour chosen in System Settings (macOS) or Personalization (Windows), as RRGGBBAA.
    let accent = '';
    try { accent = systemPreferences.getAccentColor ? systemPreferences.getAccentColor() : ''; } catch (e) { /* use the page's default */ }
    return {
      version: app.getVersion(),
      platform: process.platform,
      importSupported: process.platform === 'darwin',
      accent: /^[0-9a-f]{6,8}$/i.test(accent || '') ? '#' + accent.slice(0, 6) : '',
    };
  });

  // A native confirmation instead of window.confirm. For a destructive action the
  // safe choice, Cancel, is the default button, as the macOS guidelines ask.
  ipcMain.handle('dialog:confirm', async (_e, opts) => {
    const o = opts && typeof opts === 'object' ? opts : {};
    const str = (v, max) => (typeof v === 'string' ? v.slice(0, max) : '');
    const ok = str(o.confirm, 40) || 'OK';
    const destructive = o.destructive === true;
    const box = {
      type: destructive ? 'warning' : 'question',
      buttons: [ok, 'Cancel'],
      defaultId: destructive ? 1 : 0,
      cancelId: 1,
      message: str(o.message, 300) || 'Are you sure?',
      detail: str(o.detail, 1000) || undefined,
    };
    const r = win && !win.isDestroyed() ? await dialog.showMessageBox(win, box) : await dialog.showMessageBox(box);
    return r.response === 0;
  });

  ipcMain.handle('dialog:pickFolder', async () => {
    const opts = { properties: ['openDirectory', 'createDirectory'] };
    const r = win && !win.isDestroyed() ? await dialog.showOpenDialog(win, opts) : await dialog.showOpenDialog(opts);
    return r.canceled || !r.filePaths.length ? null : r.filePaths[0];
  });
}

module.exports = { registerIpc };
