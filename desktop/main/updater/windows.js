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

  autoUpdater.on('update-available', (info) => {
    send({ state: 'available', version: info && info.version });
  });

  autoUpdater.on('update-not-available', () => send({ state: 'none' }));

  autoUpdater.on('download-progress', (p) => {
    const pct = p && Number.isFinite(p.percent) ? Math.round(p.percent) : 0;
    send({ state: 'downloading', message: `${pct}%` });
  });

  // Status only, never a dialog: a failed check is not the user's problem.
  autoUpdater.on('error', (err) => {
    send({ state: 'error', message: (err && (err.message || String(err))) || 'update failed' });
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

function checkForUpdates(win, send) {
  wire(win, send);
  // The 'error' listener above already reports failures; swallow the rejection
  // so an unreachable feed cannot become an unhandled promise.
  return Promise.resolve(autoUpdater.checkForUpdates()).catch(() => null);
}

module.exports = { checkForUpdates };
