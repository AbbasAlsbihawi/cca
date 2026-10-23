// Restore sheet: snapshot picker, dry-run preview, restore.
import { runLogged, withBusy, logError } from './output.js';

export function openRestoreSheet(sheet, accountName, snapshots, close, onDone) {
  sheet.replaceChildren();
  const h = document.createElement('h2');
  h.textContent = `Restore "${accountName}"`;
  const sel = document.createElement('select');
  const snaps = Array.isArray(snapshots) ? snapshots.slice().reverse() : [];
  for (const s of snaps) {
    const o = document.createElement('option'); o.value = s; o.textContent = s;
    sel.appendChild(o);
  }
  const pv = document.createElement('pre');
  pv.className = 'preview';
  const cancel = document.createElement('button'); cancel.textContent = 'Cancel';
  const go = document.createElement('button'); go.textContent = 'Restore'; go.className = 'primary';
  go.disabled = true;

  let token = 0;
  async function preview() {
    const my = ++token;
    go.disabled = true;
    if (!sel.value) { pv.textContent = 'No snapshots available.'; return; }
    pv.textContent = 'Loading preview…';
    try {
      const r = await window.cca.restorePreview(['restore', '-n', accountName, sel.value]);
      if (my !== token) return;
      pv.textContent = [r && r.stdout, r && r.stderr].filter(Boolean).join('\n') || '(nothing to show)';
      go.disabled = !r || r.code !== 0;
    } catch (e) {
      if (my !== token) return;
      pv.textContent = 'Preview failed: ' + ((e && e.message) || e);
      logError(pv.textContent);
    }
  }
  sel.addEventListener('change', preview);
  cancel.addEventListener('click', close);
  go.addEventListener('click', () => withBusy(go, async () => {
    const r = await runLogged(['restore', accountName, sel.value]);
    if (r.code === 0) { close(); onDone(); }
  }));

  const actions = document.createElement('div');
  actions.className = 'sheet-actions';
  actions.append(cancel, go);
  const f = document.createElement('div'); f.className = 'field';
  const l = document.createElement('label'); l.textContent = 'Snapshot';
  f.append(l, sel);
  const l2 = document.createElement('label'); l2.className = 'muted'; l2.textContent = 'Dry-run preview';
  sheet.append(h, f, l2, pv, actions);
  preview();
}
