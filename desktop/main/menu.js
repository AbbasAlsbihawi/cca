'use strict';
// Application menu. Items that need the UI (a name, a snapshot) tell the renderer via 'menu:action'.
const { Menu, app, dialog } = require('electron');
const { runCca, bus } = require('./cca');

async function backup() {
  const r = await runCca(['backup']);
  if (r.code === 0) bus.emit('changed');
  else dialog.showErrorBox('Backup failed', (r.stderr || r.stdout || `exit ${r.code}`).trim());
}

// actions: { win, showWindow() }
function buildAppMenu(actions) {
  const isMac = process.platform === 'darwin';
  const toUi = (name) => () => {
    actions.showWindow();
    if (actions.win && !actions.win.isDestroyed()) actions.win.webContents.send('menu:action', name);
  };

  const account = [
    { label: 'Add Account…', accelerator: 'CmdOrCtrl+N', click: toUi('add') },
    { label: 'Open Claude', accelerator: 'CmdOrCtrl+O', click: toUi('open') },
    { type: 'separator' },
    { label: 'Backup', accelerator: 'CmdOrCtrl+B', click: backup },
    { label: 'Restore…', click: toUi('restore') },
  ];
  account.push({ type: 'separator' }, { label: 'Refresh', accelerator: 'CmdOrCtrl+R', click: () => bus.emit('changed') });

  const template = [];
  // The standard macOS app menu, plus Settings… (⌘,) for the General page.
  if (isMac) {
    template.push({
      label: app.name,
      submenu: [
        { role: 'about' },
        { label: 'Check for Updates…', click: toUi('check-updates') },
        { type: 'separator' },
        { label: 'Settings…', accelerator: 'Cmd+,', click: toUi('general') },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' },
      ],
    });
  }
  template.push(
    { label: 'Account', submenu: account },
    { role: 'editMenu' },
    { role: 'windowMenu' },
  );
  if (!isMac) {
    template.unshift({
      label: 'File',
      submenu: [
        { label: 'Check for Updates', click: toUi('check-updates') },
        { type: 'separator' },
        { label: 'Quit', accelerator: 'Alt+F4', click: () => app.quit() },
      ],
    });
  }
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

module.exports = { buildAppMenu };
