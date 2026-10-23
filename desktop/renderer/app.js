// Entry point: state, polling, toolbar wiring.
import { initOutput, runLogged, withBusy, logError } from './output.js';
import { renderSidebar } from './sidebar.js';
import { renderDetail } from './detail.js';
import { openAddSheet } from './addSheet.js';
import { openRestoreSheet } from './restoreSheet.js';

const $ = (id) => document.getElementById(id);
const state = { data: null, selected: null, info: null };
let timer = null;
let inflight = false;

function closeSheet() { $('sheet-backdrop').hidden = true; $('sheet').replaceChildren(); }
function showSheet() { $('sheet-backdrop').hidden = false; }
const colors = () => (state.data && Array.isArray(state.data.colors) ? state.data.colors : []);
const accounts = () => (state.data && Array.isArray(state.data.accounts) ? state.data.accounts : []);

function render() {
  const list = accounts();
  if (!list.some((a) => a.name === state.selected)) {
    const d = list.find((a) => a.isDefault) || list[0];
    state.selected = d ? d.name : null;
  }
  renderSidebar($('sidebar'), list, state.selected, (n) => { state.selected = n; render(); });
  // Don't rebuild the detail pane under an open dropdown/sheet-less interaction needlessly.
  if (!document.activeElement || document.activeElement.tagName !== 'SELECT') {
    renderDetail($('detail'), list.find((a) => a.name === state.selected), {
      colors: colors(), refresh, openRestore,
    });
  }
  $('chk-autobackup').checked = !!(state.data && state.data.autobackup);
}

function openRestore(name) {
  openRestoreSheet($('sheet'), name, state.data && state.data.snapshots, closeSheet, refresh);
  showSheet();
}

function openAdd() { openAddSheet($('sheet'), colors(), closeSheet); showSheet(); }

async function refresh() {
  if (inflight) return;
  inflight = true;
  try {
    const r = await window.cca.list();
    if (r && r.ok && r.data) { state.data = r.data; render(); }
    else logError('list failed: ' + ((r && r.error) || 'unknown error'));
  } catch (e) {
    logError('list failed: ' + ((e && e.message) || e));
  } finally { inflight = false; }
}

function schedule() {
  clearTimeout(timer);
  timer = setTimeout(async () => { await refresh(); schedule(); }, document.hasFocus() ? 5000 : 30000);
}

async function init() {
  initOutput();
  try {
    state.info = await window.cca.appInfo();
    if (state.info && state.info.version) $('app-version').textContent = 'v' + state.info.version;
  } catch { /* version is cosmetic */ }
  // Import is deliberately not offered anywhere in this UI (importSupported is false on Windows
  // and restore subsumes it), so there is nothing further to gate.

  $('btn-add').addEventListener('click', openAdd);
  $('btn-backup').addEventListener('click', (e) => withBusy(e.currentTarget, () => runLogged(['backup'])));
  $('btn-refresh').addEventListener('click', (e) => withBusy(e.currentTarget, refresh));
  $('chk-autobackup').addEventListener('change', (e) => withBusy(e.currentTarget, async () => {
    await runLogged(['autobackup', e.currentTarget.checked ? 'on' : 'off']);
    await refresh();
  }));
  $('sheet-backdrop').addEventListener('mousedown', (e) => { if (e.target === $('sheet-backdrop')) closeSheet(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeSheet(); });

  // Application menu: Backup and Refresh are handled in main; import is not offered here, so it is ignored.
  if (window.cca.onMenuAction) {
    window.cca.onMenuAction((action) => {
      if (action === 'add') openAdd();
      else if (action === 'restore' && state.selected) openRestore(state.selected);
    });
  }
  if (window.cca.onChanged) window.cca.onChanged(() => refresh());
  if (window.cca.onUpdateStatus) {
    // `state` is an internal name ('none', 'ready', ...); the user gets a sentence or
    // nothing at all. `message` is kept only where it says something they can act on:
    // the percentage while downloading, and the reason on an error or an arch mismatch.
    // The toolbar already shows the running version, so it is not repeated here.
    const updateText = (s) => {
      if (!s || !s.state) return '';
      const v = s.version ? ' ' + s.version : '';
      switch (s.state) {
        case 'available': return 'Update' + v + ' available';
        case 'downloading': return 'Downloading update' + v + (s.message ? ' ' + s.message : '...');
        case 'ready': return 'Update' + v + ' ready - restart to install';
        case 'error': return s.message || 'Could not check for updates';
        case 'checking': return '';
        default: return s.message || '';
      }
    };
    window.cca.onUpdateStatus((s) => { $('update-status').textContent = updateText(s); });
  }
  window.addEventListener('focus', () => { refresh(); schedule(); });
  window.addEventListener('blur', schedule);

  await refresh();
  schedule();
}
init();
