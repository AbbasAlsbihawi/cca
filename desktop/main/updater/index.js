'use strict';
// The updater's only entry point: main.js calls startAutoUpdate(win) once, after
// the window exists. Windows uses electron-updater. macOS cannot - the app is
// deliberately unsigned and Squirrel.Mac refuses an unsigned bundle - so darwin
// has its own download-and-swap path in ./mac.
const { app } = require('electron');

const FIRST_CHECK_MS = 15 * 1000; // let the window finish loading first
const CHECK_INTERVAL_MS = 4 * 60 * 60 * 1000; // then every 4 hours
const RETRY_SOON_MS = 10 * 60 * 1000; // after a dropped download, instead of the next 4-hour check

let started = false;
let firstCheck = null;
let interval = null;
let retrySoon = null;
let runCheck = null; // set once started; Check Now calls it with { manual: true }

function reason(err) {
  return (err && (err.message || String(err))) || 'unknown error';
}

// The Dock (macOS) or taskbar (Windows) icon shows the download too, so it can be
// followed with the window hidden. Any other state removes the bar.
function showProgress(win, payload) {
  let value = -1;
  if (payload.state === 'downloading' && Number.isFinite(payload.percent)) value = payload.percent / 100;
  else if (payload.state === 'unpacking') value = 1; // the download is done
  win.setProgressBar(value);
}

function send(win, payload) {
  try {
    if (!win || win.isDestroyed()) return;
    try { showProgress(win, payload); } catch (e) { /* the icon is extra; the window still gets told */ }
    const wc = win.webContents;
    if (wc && !wc.isDestroyed()) wc.send('update:status', payload);
  } catch (e) { /* the window went away mid-check: no one left to tell */ }
}

function stop() {
  if (firstCheck) { clearTimeout(firstCheck); firstCheck = null; }
  if (interval) { clearInterval(interval); interval = null; }
  if (retrySoon) { clearTimeout(retrySoon); retrySoon = null; }
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

  // A dropped connection is retried in 10 minutes, and the status says so.
  const report = (payload) => {
    if (payload && payload.state === 'error' && payload.transient && !retrySoon) {
      retrySoon = setTimeout(() => { retrySoon = null; check(); }, RETRY_SOON_MS);
      payload = { ...payload, message: `${payload.message} Trying again in 10 minutes.` };
    }
    send(win, payload);
  };

  // A failed check must never take the app down: report it and wait for the next.
  const check = (opts = {}) => {
    if (opts.manual && retrySoon) { clearTimeout(retrySoon); retrySoon = null; }
    try {
      const r = backend.checkForUpdates(win, report, opts);
      if (r && typeof r.catch === 'function') {
        r.catch((err) => report({ state: 'error', message: reason(err) }));
      }
    } catch (err) {
      report({ state: 'error', message: reason(err) });
    }
  };
  runCheck = check;

  firstCheck = setTimeout(check, FIRST_CHECK_MS);
  interval = setInterval(check, CHECK_INTERVAL_MS);
  // Stop checking once the app is on its way out.
  app.on('before-quit', stop);
  app.on('will-quit', stop);
}

// Check Now, from the General page or the menu. False when this build has no
// updater (development, or a platform without a feed).
function checkNow() {
  if (!runCheck) return false;
  runCheck({ manual: true });
  return true;
}

module.exports = { startAutoUpdate, checkNow, updatesEnabled: () => started };
