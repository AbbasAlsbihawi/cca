'use strict';
// The only bridge into the renderer: plain functions, no ipcRenderer, no Node.
const { contextBridge, ipcRenderer } = require('electron');

function subscribe(channel, cb) {
  if (typeof cb !== 'function') return () => {};
  const handler = (_e, payload) => cb(payload);
  ipcRenderer.on(channel, handler);
  return () => ipcRenderer.removeListener(channel, handler);
}

contextBridge.exposeInMainWorld('cca', {
  // Known before the first paint, so the layout does not jump once appInfo arrives.
  platform: process.platform,
  list: () => ipcRenderer.invoke('cca:list'),
  run: (args) => ipcRenderer.invoke('cca:run', args),
  interactive: (args) => ipcRenderer.invoke('cca:interactive', args),
  restorePreview: (args) => ipcRenderer.invoke('cca:restore-preview', args),
  appInfo: () => ipcRenderer.invoke('app:info'),
  pickFolder: () => ipcRenderer.invoke('dialog:pickFolder'),
  confirm: (opts) => ipcRenderer.invoke('dialog:confirm', opts),
  checkUpdates: () => ipcRenderer.invoke('update:check'),
  onChanged: (cb) => subscribe('cca:changed', () => cb()),
  onUpdateStatus: (cb) => subscribe('update:status', cb),
  onMenuAction: (cb) => subscribe('menu:action', cb),
});
