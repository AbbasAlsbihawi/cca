// Restore sheet: snapshot picker, dry-run preview, restore.
import { runLogged, withBusy, logError } from './output.js';
import { el, snapshotLabel } from './ui.js';

export function openRestoreSheet(sheet, accountName, snapshots, close, onDone) {
  sheet.replaceChildren();
  const sel = el('select');
  sel.id = 'f-snapshot';
  const snaps = Array.isArray(snapshots) ? snapshots.slice().reverse() : [];
  for (const s of snaps) {
    const o = el('option', null, snapshotLabel(s));
    o.value = s;
    sel.appendChild(o);
  }
  const pv = el('pre', 'preview');
  pv.setAttribute('aria-label', 'Preview');
  const cancel = el('button', '', 'Cancel'); cancel.type = 'button';
  const go = el('button', 'primary', 'Restore'); go.type = 'button';
  go.disabled = true;

  let token = 0;
  async function preview() {
    const my = ++token;
    go.disabled = true;
    if (!sel.value) { pv.textContent = 'No backups yet.'; return; }
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

  const form = el('div', 'form');
  const l = el('label', 'lbl', 'Backup:');
  l.htmlFor = sel.id;
  form.append(l, sel);
  const actions = el('div', 'sheet-actions');
  actions.append(cancel, go);
  sheet.append(
    el('h2', null, `Restore “${accountName}”`),
    el('p', 'sheet-note', 'What a restore would change. Nothing changes until you choose Restore.'),
    form,
    pv,
    actions,
  );
  preview();
}
