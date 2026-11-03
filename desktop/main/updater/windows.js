'use strict';
// Windows: electron-updater does the work. The feed is whatever electron-builder
// baked into app-update.yml from its publish block (provider github, owner
// AbbasAlsbihawi, repo cca, public), so no feed URL and no token belong here -
// setting either would override the shipped file, and a public repo needs none.
const { dialog } = require('electron');
const { autoUpdater } = require('electron-updater');

let wired = false;
let prompted = false; // one restart prompt per run; "Later" must not nag

function wire(win, send) {
  if (wired) return;
  wired = true;

  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;
  autoUpdater.logger = null;

  autoUpdater.on('checking-for-update', () => send({ state: 'checking' }));

  let version; // progress events do not carry it
  autoUpdater.on('update-available', (info) => {
    version = info && info.version;
    send({ state: 'available', version });
  });

  autoUpdater.on('update-not-available', () => send({ state: 'none' }));

  autoUpdater.on('download-progress', (p) => {
    const pct = p && Number.isFinite(p.percent) ? Math.floor(p.percent) : 0;
    send({ state: 'downloading', version, percent: pct, transferred: p && p.transferred, total: p && p.total });
  });

  // Status only, never a dialog: a failed check is not the user's problem. A dropped
  // or missing connection is marked transient, so the check runs again soon.
  autoUpdater.on('error', (err) => {
    const msg = (err && (err.message || String(err))) || 'update failed';
    const transient = /net::ERR_|ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN|socket hang up|aborted/i.test(`${msg} ${err && err.code}`);
    if (transient) send({ state: 'error', transient: true, message: 'The download was interrupted: the connection dropped.' });
    else send({ state: 'error', message: msg });
  });

  autoUpdater.on('update-downloaded', async (info) => {
    const version = (info && info.version) || '';
    send({ state: 'ready', version });
    if (prompted) return;
    prompted = true;
    try {
      const { response } = await dialog.showMessageBox(win && !win.isDestroyed() ? win : null, {
        type: 'question',
        buttons: ['Restart now', 'Later'],
        defaultId: 0,
        cancelId: 1,
        title: 'Update ready',
        message: version ? `Claude Accounts ${version} is ready to install.` : 'An update is ready to install.',
        // Say what "Later" does, so the install on quit is not a surprise.
        detail: 'Restart now to use it right away, or choose Later - it will be installed automatically the next time you quit Claude Accounts.',
      });
      if (response === 0) setImmediate(() => autoUpdater.quitAndInstall());
    } catch (err) {
      send({ state: 'error', message: (err && err.message) || 'could not show the update prompt' });
    }
  });
}

// opts.manual: the user asked (Check Now), so a put-off update may prompt again.
function checkForUpdates(win, send, opts = {}) {
  wire(win, send);
  if (opts.manual) prompted = false;
  // The 'error' listener above already reports failures; swallow the rejection
  // so an unreachable feed cannot become an unhandled promise.
  return Promise.resolve(autoUpdater.checkForUpdates()).catch(() => null);
}

module.exports = { checkForUpdates };
