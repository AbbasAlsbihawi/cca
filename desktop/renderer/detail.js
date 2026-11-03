// Account page: a header, then grouped rows, in the style of System Settings.
import { runLogged, logError } from './output.js';
import { avatar, colorCss } from './sidebar.js';
import { el, button, row, group, value } from './ui.js';

export function renderDetail(root, a, ctx) {
  root.replaceChildren();
  const page = el('div', 'page');
  root.appendChild(page);
  if (!a) {
    const empty = el('div', 'empty');
    empty.append(el('p', null, 'No accounts yet.'), button('Add Account…', async () => ctx.openAdd(), 'primary'));
    page.appendChild(empty);
    return;
  }
  const colors = Array.isArray(ctx.colors) ? ctx.colors : [];
  const folders = Array.isArray(a.folders) ? a.folders : [];
  const act = (label, fn, cls) => button(label, fn, cls, ctx.refresh);
  const interactive = async (args) => {
    try {
      const res = await window.cca.interactive(args);
      if (/Windows/i.test(navigator.userAgent) && res && res.ok === false) logError('terminal failed: ' + (res.error || 'did not start'));
    } catch (e) { logError('interactive failed: ' + ((e && e.message) || e)); }
  };
  const makeApp = (color) => runLogged(['app', a.name, color || a.color || colors[0] || ''].filter(Boolean));

  // Header: who this is, and the one thing most people come here to do.
  const head = el('div', 'page-head');
  const who = el('div', 'who');
  const name = el('h2', null, a.name);
  if (a.running) name.appendChild(el('span', 'pill', 'Running'));
  const meta = [a.email || (a.loggedIn === false ? 'Not logged in' : 'No email'), a.org, a.isDefault ? 'Default account' : '']
    .filter(Boolean).join(' · ');
  who.append(name, el('div', 'meta', meta));
  const main = a.app ? act('Open Claude', () => runLogged(['open', a.name]), 'primary') : act('Make App', () => makeApp(), 'primary');
  main.title = a.app ? 'Open this account\'s Claude app (⌘O)' : 'Make a Claude app for this account';
  head.append(avatar(a, true), who, main);
  page.appendChild(head);

  // Colour swatches: picking one remakes the app with that icon colour.
  let swatches = null;
  if (colors.length) {
    swatches = el('div', 'swatches');
    swatches.setAttribute('role', 'group');
    swatches.setAttribute('aria-label', 'Colour');
    for (const c of colors) {
      const s = act('', () => makeApp(c), 'swatch');
      s.style.background = colorCss(c) || c;
      s.title = c;
      s.setAttribute('aria-label', c);
      s.setAttribute('aria-pressed', String(c === a.color));
      swatches.appendChild(s);
    }
  }

  page.appendChild(group(null, [
    row('Claude app', a.app ? null : 'Not made yet', a.app ? value(a.app) : null, a.app ? act('Remake App', () => makeApp()) : null),
    swatches && row('Colour', 'The colour of its Claude app icon.', swatches),
    row('Sign-in', 'Opens Terminal to log in to this account again.', act('Log In Again…', () => interactive(['login', a.name]))),
    row('MCP servers', 'Opens Claude in Terminal at its list of MCP servers. A sign-in there reaches this account even while other copies are open.',
      act('Sign In…', () => interactive(['mcp', a.name]))),
    row('Terminal', 'A shell that uses this account.', act('Open Terminal', () => interactive(['shell', a.name]))),
  ]));

  // Folders: in each one, and its subfolders, cca always uses this account.
  const folderRows = folders.map((f) => {
    const path = el('span', 'path');
    path.appendChild(el('bdi', null, String(f)));
    path.title = String(f);
    const unbind = act('−', () => runLogged(['unbind', String(f)]), 'square');
    unbind.title = 'Unbind this folder';
    unbind.setAttribute('aria-label', 'Unbind ' + String(f));
    const r = el('div', 'grow');
    r.append(path, unbind);
    return r;
  });
  if (!folders.length) folderRows.push(row('No folders yet', 'In a bound folder and its subfolders, cca always uses this account.'));
  const bind = act('Bind Folder…', async () => {
    const dir = await window.cca.pickFolder();
    if (dir) await runLogged(['bind', a.name, dir]);
  }, 'link');
  const bindRow = el('div', 'grow');
  bindRow.appendChild(bind);
  folderRows.push(bindRow);
  page.appendChild(group('Bound folders', folderRows));

  const restore = act('Restore…', async () => ctx.openRestore(a.name));
  restore.disabled = !(ctx.snapshots && ctx.snapshots.length);
  page.appendChild(group(null, [
    row('Restore conversations', 'From a backup, with a preview first.', restore),
    row('Remove account', 'Deletes its login and its data.', act('Remove…', () => ctx.removeAccount(a), 'destructive')),
  ]));
}
