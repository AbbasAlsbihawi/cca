'use strict';
// Every renderer -> main channel. The renderer only ever sees these results.
const { app, dialog, ipcMain } = require('electron');
const { runCca, listAccounts, bus } = require('./cca');
const { runInteractive } = require('./interactive');

const RUN_VERBS = new Set(['open', 'app', 'bind', 'unbind', 'backup', 'autobackup', 'remove', 'restore']);

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
    const r = await runCca(args);
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

  ipcMain.handle('app:info', () => ({
    version: app.getVersion(),
    platform: process.platform,
    importSupported: process.platform === 'darwin',
  }));

  ipcMain.handle('dialog:pickFolder', async () => {
    const opts = { properties: ['openDirectory', 'createDirectory'] };
    const r = win && !win.isDestroyed() ? await dialog.showOpenDialog(win, opts) : await dialog.showOpenDialog(opts);
    return r.canceled || !r.filePaths.length ? null : r.filePaths[0];
  });
}

module.exports = { registerIpc };
