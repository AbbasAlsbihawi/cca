'use strict';
const path = require('path');
const { BrowserWindow, app, shell } = require('electron');
const { ensureCli } = require('./cca');
const { registerIpc } = require('./ipc');
const { buildAppMenu } = require('./menu');
const { createTray } = require('./tray');
const { startAutoUpdate } = require('./updater');

// Electron names its data folder after the app name, which comes from package.json
// "name" (productName is set only for electron-builder): every 0.1.x copy used
// <appData>/claude-accounts. Pin that folder, before anything uses it, so a future
// top-level productName cannot move it: an upgrade keeps what Electron stored there,
// and an old and a new copy share one instance lock.
app.setPath('userData', path.join(app.getPath('appData'), 'claude-accounts'));

let win = null;
let quitting = false;

function showWindow() {
  if (!win || win.isDestroyed()) return;
  if (win.isMinimized()) win.restore();
  win.show();
  win.focus();
}

function quit() {
  quitting = true;
  app.quit();
}

function createWindow() {
  const mac = process.platform === 'darwin';
  win = new BrowserWindow({
    width: 1000,
    height: 680,
    minWidth: 760,
    minHeight: 480,
    show: false,
    // macOS: no separate title bar. The traffic lights sit over a translucent
    // sidebar, as in System Settings; the page leaves room for them.
    ...(mac ? { titleBarStyle: 'hiddenInset', vibrancy: 'sidebar', backgroundColor: '#00000000' } : {}),
    webPreferences: {
      preload: path.join(__dirname, '..', 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.once('ready-to-show', () => win.show());
  win.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));

  // Never let the renderer navigate away or open windows; links go to the browser.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https:\/\//i.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e) => e.preventDefault());

  // Tray app: closing hides the window; only a real quit ends the process.
  win.on('close', (e) => {
    if (!quitting) {
      e.preventDefault();
      win.hide();
    }
  });
  return win;
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', showWindow);
  app.on('before-quit', () => { quitting = true; });
  // The tray keeps the app alive with no window.
  app.on('window-all-closed', () => {});
  app.on('activate', showWindow);

  app.whenReady().then(() => {
    ensureCli();
    createWindow();
    registerIpc(win);
    buildAppMenu({ win, showWindow });
    createTray({ showWindow, quit });
    startAutoUpdate(win);
  });
}
