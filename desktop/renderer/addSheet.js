// Add-account sheet.
import { colorCss } from './sidebar.js';
import { logError } from './output.js';

function field(label, input) {
  const d = document.createElement('div');
  d.className = 'field';
  const l = document.createElement('label');
  l.textContent = label;
  d.append(l, input);
  return d;
}

export function openAddSheet(sheet, colors, close) {
  sheet.replaceChildren();
  const h = document.createElement('h2');
  h.textContent = 'Add account';
  const name = document.createElement('input'); name.type = 'text'; name.placeholder = 'work';
  const email = document.createElement('input'); email.type = 'text'; email.placeholder = 'optional';
  const sso = document.createElement('input'); sso.type = 'checkbox';
  const ssoWrap = document.createElement('label');
  ssoWrap.className = 'toggle';
  ssoWrap.append(sso, document.createTextNode(' Use SSO'));
  const col = document.createElement('select');
  const none = document.createElement('option'); none.value = ''; none.textContent = '(none)';
  col.appendChild(none);
  for (const c of colors) {
    const o = document.createElement('option'); o.value = c; o.textContent = c;
    col.appendChild(o);
  }
  const note = document.createElement('div');
  note.className = 'muted';
  note.textContent = 'Login continues in a Terminal window.';

  const cancel = document.createElement('button'); cancel.textContent = 'Cancel';
  const go = document.createElement('button'); go.textContent = 'Add in Terminal'; go.className = 'primary';
  go.disabled = true;
  // Same rule as cca: lowercase letters, digits, - and _, starting with a letter or digit.
  const NAME_RE = /^[a-z0-9][a-z0-9_-]*$/;
  const hint = document.createElement('div');
  hint.className = 'muted';
  hint.textContent = 'Name: lowercase letters, digits, - and _ only.';
  name.addEventListener('input', () => {
    const v = name.value.trim();
    go.disabled = !NAME_RE.test(v);
    hint.style.color = v && !NAME_RE.test(v) ? '#ff6b6b' : '';
  });
  cancel.addEventListener('click', close);
  go.addEventListener('click', async () => {
    const args = ['add', name.value.trim()];
    if (email.value.trim()) args.push('--email', email.value.trim());
    if (sso.checked) args.push('--sso');
    go.disabled = true;
    try {
      const res = await window.cca.interactive(args);
      if (res && res.ok === false) {
        logError('add failed: ' + (res.error || 'the terminal did not start'));
        go.disabled = false;
        return;
      }
      // Colour is applied by making the app once the account exists.
      if (col.value && colorCss(col.value) !== undefined) {
        note.textContent = `After login, pick colour "${col.value}" from the account's detail pane.`;
      }
      close();
    } catch (e) {
      logError('add failed: ' + ((e && e.message) || e));
      go.disabled = false;
    }
  });
  const actions = document.createElement('div');
  actions.className = 'sheet-actions';
  actions.append(cancel, go);
  sheet.append(h, field('Name', name), hint, field('Email', email), field('SSO', ssoWrap), field('Colour', col), note, actions);
  name.focus();
}
