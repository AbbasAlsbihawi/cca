'use strict';
// The updater's only entry point: main.js calls startAutoUpdate(win) once, after
// the window exists. Windows uses electron-updater. macOS cannot - the app is
// deliberately unsigned and Squirrel.Mac refuses an unsigned bundle - so darwin
// has its own download-and-swap path in ./mac.
const { app } = require('electron');

const FIRST_CHECK_MS = 15 * 1000; // let the window finish loading first
const CHECK_INTERVAL_MS = 4 * 60 * 60 * 1000; // then every 4 hours

let started = false;
let firstCheck = null;
let interval = null;

function reason(err) {
  return (err && (err.message || String(err))) || 'unknown error';
}

function send(win, payload) {
  try {
    if (!win || win.isDestroyed()) return;
    const wc = win.webContents;
    if (wc && !wc.isDestroyed()) wc.send('update:status', payload);
  } catch (e) { /* the window went away mid-check: no one left to tell */ }
}

function stop() {
  if (firstCheck) { clearTimeout(firstCheck); firstCheck = null; }
  if (interval) { clearInterval(interval); interval = null; }
}

function startAutoUpdate(win) {
  // Never in development: there is no packaged bundle to replace.
  if (!app.isPackaged || started) return;

  let backend = null;
  try {
    if (process.platform === 'win32') backend = require('./windows');
    else if (process.platform === 'darwin') backend = require('./mac');
  } catch (err) {
    send(win, { state: 'error', message: `Updater unavailable: ${reason(err)}` });
    return;
  }
  if (!backend) return; // every other platform: no feed, nothing to do
  started = true;

  // A failed check must never take the app down: report it and wait for the next.
  const check = () => {
    try {
      const r = backend.checkForUpdates(win, (payload) => send(win, payload));
      if (r && typeof r.catch === 'function') {
        r.catch((err) => send(win, { state: 'error', message: reason(err) }));
      }
    } catch (err) {
      send(win, { state: 'error', message: reason(err) });
    }
  };

  firstCheck = setTimeout(check, FIRST_CHECK_MS);
  interval = setInterval(check, CHECK_INTERVAL_MS);
  // Stop checking once the app is on its way out.
  app.on('before-quit', stop);
  app.on('will-quit', stop);
}

module.exports = { startAutoUpdate };
