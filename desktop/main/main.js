'use strict';
const path = require('path');
const { BrowserWindow, app, shell } = require('electron');
const { registerIpc } = require('./ipc');
const { buildAppMenu } = require('./menu');
const { createTray } = require('./tray');
const { startAutoUpdate } = require('./updater');

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
  win = new BrowserWindow({
    width: 1000,
    height: 680,
    show: false,
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
    createWindow();
    registerIpc(win);
    buildAppMenu({ win, showWindow });
    createTray({ showWindow, quit });
    startAutoUpdate(win);
  });
}
