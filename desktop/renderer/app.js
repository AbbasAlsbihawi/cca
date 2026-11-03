// Entry point: state, polling, the sidebar and the current page, the update status.
import { initOutput, runLogged, logError } from './output.js';
import { renderSidebar, wireSidebarKeys } from './sidebar.js';
import { renderDetail } from './detail.js';
import { renderGeneral } from './general.js';
import { openAddSheet } from './addSheet.js';
import { openRestoreSheet } from './restoreSheet.js';
import { confirmNative } from './ui.js';

const $ = (id) => document.getElementById(id);
// page is 'account' (the selected one) or 'general'. shown is the data last drawn,
// so a poll that changes nothing does not rebuild the page under the user's focus.
const state = { data: null, shown: '', page: 'account', selected: null, info: null, update: null };
let timer = null;
let inflight = false;

// The platform decides the title bar: macOS draws none, so the page leaves room for the traffic lights.
const platform = (window.cca && window.cca.platform) || '';
document.documentElement.classList.add(platform === 'darwin' ? 'mac' : platform === 'win32' ? 'win' : 'other');

function closeSheet() { $('sheet-backdrop').hidden = true; $('sheet').replaceChildren(); }
function showSheet() { $('sheet-backdrop').hidden = false; }
const colors = () => (state.data && Array.isArray(state.data.colors) ? state.data.colors : []);
const accounts = () => (state.data && Array.isArray(state.data.accounts) ? state.data.accounts : []);
const current = () => accounts().find((a) => a.name === state.selected);

function go(page, name) {
  state.page = page;
  if (name) state.selected = name;
  render();
}

function render() {
  const list = accounts();
  if (!list.some((a) => a.name === state.selected)) {
    const d = list.find((a) => a.isDefault) || list[0];
    state.selected = d ? d.name : null;
  }
  renderSidebar($('side-list'), list, { page: state.page, selected: state.selected }, {
    select: (n) => go('account', n),
    general: () => go('general'),
  });
  const a = current();
  if (state.page === 'general') {
    $('page-title').textContent = 'General';
    renderGeneral($('detail'), { data: state.data, info: state.info, refresh });
  } else {
    $('page-title').textContent = a ? a.name : 'Claude Accounts';
    renderDetail($('detail'), a, {
      colors: colors(), snapshots: state.data && state.data.snapshots, chromeProfiles: state.data && state.data.chromeProfiles,
      refresh, openRestore, openAdd, removeAccount,
    });
  }
  $('btn-remove').disabled = state.page !== 'account' || !a;
  showUpdate(state.update);
}

// Shown before it is filled, so the sheet can put focus in its first field.
function openRestore(name) {
  showSheet();
  openRestoreSheet($('sheet'), name, state.data && state.data.snapshots, closeSheet, refresh);
}

function openAdd() { showSheet(); openAddSheet($('sheet'), closeSheet); }

async function removeAccount(a) {
  const ok = await confirmNative({
    message: `Remove the account “${a.name}”?`,
    detail: 'This deletes its login and its data.',
    confirm: 'Remove',
    destructive: true,
  });
  if (!ok) return;
  await runLogged(['remove', a.name]);
  await refresh();
}

// The first `cca list` can take several seconds; say so instead of showing an empty window.
function showPlaceholder(text, busy) {
  const box = document.createElement('div');
  box.className = 'placeholder' + (busy ? ' busy' : '');
  box.setAttribute('role', 'status');
  box.textContent = text;
  $('detail').replaceChildren(box);
}

async function refresh() {
  if (inflight) return;
  inflight = true;
  try {
    const r = await window.cca.list();
    if (r && r.ok && r.data) {
      const json = JSON.stringify(r.data);
      if (json !== state.shown) { state.shown = json; state.data = r.data; render(); }
    } else {
      logError('list failed: ' + ((r && r.error) || 'unknown error'));
      if (!state.data) showPlaceholder('Could not read the accounts.');
    }
  } catch (e) {
    logError('list failed: ' + ((e && e.message) || e));
    if (!state.data) showPlaceholder('Could not read the accounts.');
  } finally { inflight = false; }
}

function schedule() {
  clearTimeout(timer);
  timer = setTimeout(async () => { await refresh(); schedule(); }, document.hasFocus() ? 5000 : 30000);
}

// The system accent colour, so buttons and selection match the rest of the Mac.
async function loadInfo() {
  try {
    state.info = await window.cca.appInfo();
    const accent = state.info && state.info.accent;
    if (/^#[0-9a-f]{6}$/i.test(accent || '')) document.documentElement.style.setProperty('--accent', accent);
  } catch { /* cosmetic: the default accent stays */ }
}

// --- update status ------------------------------------------------------------

// `state` is an internal name ('none', 'ready', ...); the user gets a sentence or
// nothing at all. `message` is kept only where it says something they can act on:
// the reason on an error or an arch mismatch.
const mb = (n) => Math.round(n / 1e6); // as Finder counts them
function updateText(s) {
  if (!s || !s.state) return '';
  const v = s.version ? ' ' + s.version : '';
  switch (s.state) {
    case 'available': return s.message || 'Update' + v + ' available';
    case 'downloading': {
      if (!Number.isFinite(s.percent)) return 'Downloading update' + v + '...';
      const size = s.total > 0 && s.transferred >= 0 ? ` (${mb(s.transferred)} of ${mb(s.total)} MB)` : '';
      return 'Downloading' + v + ': ' + s.percent + '%' + size;
    }
    case 'unpacking': return 'Unpacking update' + v + '...';
    case 'ready': return 'Update' + v + ' ready - restart to install';
    case 'error': return s.message || 'Could not check for updates';
    case 'checking': return 'Checking for updates...';
    default: return s.message || 'Claude Accounts is up to date.';
  }
}

// Fits the sidebar footer; the full sentence is its tooltip and on the General page.
function shortText(s) {
  if (!s || !s.state) return '';
  switch (s.state) {
    case 'available': return s.message ? '' : 'Update ' + (s.version || '');
    case 'downloading': return Number.isFinite(s.percent) ? s.percent + '%' : 'Downloading';
    case 'unpacking': return 'Unpacking';
    case 'ready': return 'Restart to update';
    case 'error': return 'Update failed';
    default: return '';
  }
}

// A bar shows only while an update is on its way; unpacking has no percentage,
// so the bar runs without a value then.
function setBar(bar, s) {
  if (!bar) return;
  const st = s && s.state;
  bar.hidden = st !== 'downloading' && st !== 'unpacking';
  if (st === 'downloading' && Number.isFinite(s.percent)) bar.value = s.percent;
  else bar.removeAttribute('value');
}

function showUpdate(s) {
  state.update = s;
  const text = updateText(s);
  const short = shortText(s);
  $('side-update').hidden = !short;
  $('side-update-text').textContent = short;
  $('side-update').title = text;
  setBar($('side-update-bar'), s);
  const gen = $('gen-update-text');
  if (gen) gen.textContent = text || 'Checks for updates when the app opens, then every 4 hours.';
  setBar($('gen-update-bar'), s);
}

// --- start --------------------------------------------------------------------

async function init() {
  initOutput();
  showPlaceholder('Loading accounts…', true);
  $('btn-remove').disabled = true;
  await loadInfo();

  $('btn-add').addEventListener('click', openAdd);
  $('btn-remove').addEventListener('click', () => { const a = current(); if (a) removeAccount(a); });
  $('side-update').addEventListener('click', () => go('general'));
  wireSidebarKeys($('side-list'));

  $('sheet-backdrop').addEventListener('mousedown', (e) => { if (e.target === $('sheet-backdrop')) closeSheet(); });
  document.addEventListener('keydown', (e) => {
    if ($('sheet-backdrop').hidden) return;
    if (e.key === 'Escape') closeSheet();
    // Return presses the sheet's default button, as on macOS.
    if (e.key === 'Enter' && !/^(SELECT|TEXTAREA|BUTTON)$/.test(e.target.tagName)) {
      const def = $('sheet').querySelector('.sheet-actions .primary:not(:disabled)');
      if (def) { e.preventDefault(); def.click(); }
    }
  });

  // Application menu: Backup and Refresh are handled in main; import is not offered here, so it is ignored.
  if (window.cca.onMenuAction) {
    window.cca.onMenuAction((action) => {
      const a = current();
      if (action === 'add') openAdd();
      else if (action === 'general') go('general');
      else if (action === 'restore' && a) openRestore(a.name);
      else if (action === 'open' && a && a.app) runLogged(['open', a.name]);
    });
  }
  if (window.cca.onChanged) window.cca.onChanged(() => refresh());
  if (window.cca.onUpdateStatus) window.cca.onUpdateStatus(showUpdate);
  // On focus: fresh data, and the accent colour in case it changed in System Settings.
  window.addEventListener('focus', () => { loadInfo(); refresh(); schedule(); });
  window.addEventListener('blur', schedule);

  await refresh();
  schedule();
}
init();
