'use strict';
// Tray / menu-bar dropdown: accounts, per-account actions, Backup now, Open window, Quit.
const path = require('path');
const { Menu, Tray, dialog, nativeImage } = require('electron');
const { runCca, listAccounts, bus } = require('./cca');
const { openShell } = require('./interactive');

let tray = null;
let accounts = [];
let failed = false;

function trayIcon() {
  const img = nativeImage.createFromPath(path.join(__dirname, '..', 'build', 'icon.png'));
  if (img.isEmpty()) return img;
  const size = process.platform === 'darwin' ? 18 : 16;
  return img.resize({ width: size, height: size });
}

async function act(args, what) {
  const r = await runCca(args);
  if (r.code === 0) bus.emit('changed');
  else dialog.showErrorBox(`${what} failed`, (r.stderr || r.stdout || `exit ${r.code}`).trim());
}

async function shell(name) {
  const r = await openShell(name);
  if (!r.ok) dialog.showErrorBox('New Terminal failed', r.error || 'unknown error');
}

function label(a) {
  return a.name + (a.email ? ` — ${a.email}` : '') + (a.running ? ' ●' : '');
}

function buildMenu(actions) {
  const items = [];
  if (!accounts.length) items.push({ label: failed ? 'cca unavailable' : 'No accounts', enabled: false });
  for (const a of accounts) {
    items.push({ label: label(a), click: () => act(['open', a.name], 'Open Claude') });
  }
  if (accounts.length) {
    items.push({ type: 'separator' });
    items.push({
      label: 'Account actions',
      submenu: accounts.map((a) => ({
        label: a.name,
        submenu: [
          { label: 'Open', click: () => act(['open', a.name], 'Open Claude') },
          { label: 'New Terminal', click: () => shell(a.name) },
          { label: 'Make app', click: () => act(['app', a.name], 'Make app') },
        ],
      })),
    });
  }
  items.push(
    { type: 'separator' },
    { label: 'Backup now', click: () => act(['backup'], 'Backup') },
    { label: 'Open window', click: () => actions.showWindow() },
    { type: 'separator' },
    { label: 'Quit', click: () => actions.quit() },
  );
  return Menu.buildFromTemplate(items);
}

async function refresh(actions) {
  const r = await listAccounts();
  failed = !r.ok;
  accounts = r.ok && r.data && Array.isArray(r.data.accounts) ? r.data.accounts : [];
  if (tray && !tray.isDestroyed()) tray.setContextMenu(buildMenu(actions));
}

// actions: { showWindow(), quit() }
function createTray(actions) {
  const icon = trayIcon();
  tray = new Tray(icon);
  tray.setToolTip('Claude Accounts');
  if (icon.isEmpty() && process.platform === 'darwin') tray.setTitle('cca');
  tray.setContextMenu(buildMenu(actions));
  if (process.platform !== 'darwin') tray.on('click', () => actions.showWindow());
  bus.on('changed', () => { refresh(actions); });
  refresh(actions);
  return tray;
}

module.exports = { createTray };
