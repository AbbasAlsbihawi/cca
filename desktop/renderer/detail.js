// Detail pane for the selected account.
import { runLogged, withBusy, logError } from './output.js';
import { colorCss } from './sidebar.js';

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

export function renderDetail(root, a, ctx) {
  root.replaceChildren();
  if (!a) { root.appendChild(el('div', 'empty', 'Select an account')); return; }
  const colors = Array.isArray(ctx.colors) ? ctx.colors : [];
  const folders = Array.isArray(a.folders) ? a.folders : [];

  const head = el('div', 'detail-head');
  const dot = el('span', 'dot');
  if (colorCss(a.color)) dot.style.background = colorCss(a.color);
  head.append(dot, el('h2', null, a.name));
  if (a.isDefault) head.appendChild(el('span', 'badge def', 'default'));
  if (a.running) head.appendChild(el('span', 'badge', 'running'));
  root.appendChild(head);
  root.appendChild(el('div', 'kv', a.email || (a.loggedIn === false ? 'Not logged in' : 'No email')));
  if (a.org) root.appendChild(el('div', 'kv', a.org));
  root.appendChild(el('div', 'kv', a.app ? 'App: ' + a.app : 'No Claude app made yet'));

  // Runs a cca command from a button, then refreshes the list.
  const act = (label, fn, cls) => {
    const b = el('button', cls || '', label);
    b.addEventListener('click', () => withBusy(b, async () => { await fn(); ctx.refresh(); }));
    return b;
  };
  const interactive = async (args) => {
    try {
      const res = await window.cca.interactive(args);
      if (res && res.ok === false) logError('terminal failed: ' + (res.error || 'did not start'));
    } catch (e) { logError('interactive failed: ' + ((e && e.message) || e)); }
  };

  const actions = el('div', 'actions');
  const open = act('Open Claude app', () => runLogged(['open', a.name]), 'primary');
  open.disabled = !a.app;
  actions.append(
    open,
    act(a.app ? 'Remake app' : 'Make app', () => runLogged(['app', a.name, a.color || colors[0] || ''].filter(Boolean))),
    act('New Terminal', () => interactive(['shell', a.name])),
    act('Log in again', () => interactive(['login', a.name])),
    act('Restore…', async () => ctx.openRestore(a.name)),
  );
  const rm = act('Remove', async () => {
    if (!window.confirm(`Remove account "${a.name}"? This deletes its login and data.`)) return;
    await runLogged(['remove', a.name]);
  }, 'danger');
  actions.appendChild(rm);
  root.appendChild(actions);

  if (colors.length) {
    root.appendChild(el('h3', null, 'Colour'));
    const sel = el('select');
    const none = el('option', null, '(none)');
    none.value = '';
    sel.appendChild(none);
    for (const c of colors) {
      const o = el('option', null, c);
      o.value = c;
      if (c === a.color) o.selected = true;
      sel.appendChild(o);
    }
    sel.addEventListener('change', () => {
      if (!sel.value) return;
      withBusy(sel, async () => { await runLogged(['app', a.name, sel.value]); ctx.refresh(); });
    });
    root.appendChild(sel);
  }

  root.appendChild(el('h3', null, 'Bound folders'));
  if (!folders.length) root.appendChild(el('div', 'muted', 'None'));
  for (const f of folders) {
    const r = el('div', 'folder');
    const p = el('span', null, String(f));
    p.title = String(f);
    r.append(p, act('Unbind', () => runLogged(['unbind', String(f)])));
    root.appendChild(r);
  }
  const bind = act('Bind folder…', async () => {
    const dir = await window.cca.pickFolder();
    if (dir) await runLogged(['bind', a.name, dir]);
  });
  bind.style.marginTop = '8px';
  root.appendChild(bind);
}
