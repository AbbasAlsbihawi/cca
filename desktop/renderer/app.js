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
  // Only cca.zsh reports autoupdate and has `cca update`: Windows and an older cca have neither.
  const autoupdate = state.data && state.data.autoupdate;
  $('autoupdate').hidden = typeof autoupdate !== 'boolean';
  $('btn-restart').hidden = typeof autoupdate !== 'boolean';
  $('chk-autoupdate').checked = !!autoupdate;
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
  $('btn-restart').addEventListener('click', (e) => {
    const b = e.currentTarget;
    if (!window.confirm('Quit and reopen every open Claude copy? If work is running in one, Claude may ask first.')) return;
    withBusy(b, async () => { await runLogged(['update']); await refresh(); });
  });
  for (const verb of ['autobackup', 'autoupdate']) {
    $('chk-' + verb).addEventListener('change', (e) => withBusy(e.currentTarget, async () => {
      await runLogged([verb, e.currentTarget.checked ? 'on' : 'off']);
      await refresh();
    }));
  }
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
    // the reason on an error or an arch mismatch. The toolbar already shows the
    // running version, so it is not repeated here.
    const mb = (n) => Math.round(n / 1e6); // as Finder counts them
    const updateText = (s) => {
      if (!s || !s.state) return '';
      const v = s.version ? ' ' + s.version : '';
      switch (s.state) {
        case 'available': return 'Update' + v + ' available';
        case 'downloading': {
          if (!Number.isFinite(s.percent)) return 'Downloading update' + v + '...';
          const size = s.total > 0 && s.transferred >= 0 ? ` (${mb(s.transferred)} of ${mb(s.total)} MB)` : '';
          // Short enough to fit beside the bar in the default window width.
          return 'Downloading' + v + ': ' + s.percent + '%' + size;
        }
        case 'unpacking': return 'Unpacking update' + v + '...';
        case 'ready': return 'Update' + v + ' ready - restart to install';
        case 'error': return s.message || 'Could not check for updates';
        case 'checking': return '';
        default: return s.message || '';
      }
    };
    // The bar shows only while an update is on its way; unpacking has no
    // percentage, so the bar runs without a value then.
    const updateBar = (s) => {
      const bar = $('update-progress');
      const state = s && s.state;
      bar.hidden = state !== 'downloading' && state !== 'unpacking';
      if (state === 'downloading' && Number.isFinite(s.percent)) bar.value = s.percent;
      else bar.removeAttribute('value');
    };
    window.cca.onUpdateStatus((s) => {
      const text = updateText(s);
      $('update-status').textContent = text;
      $('update-status').title = text;
      updateBar(s);
    });
  }
  window.addEventListener('focus', () => { refresh(); schedule(); });
  window.addEventListener('blur', schedule);

  await refresh();
  schedule();
}
init();
