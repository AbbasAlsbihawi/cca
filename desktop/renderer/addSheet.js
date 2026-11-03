// Add-account sheet: a macOS form, labels on the left, the default button on the right.
import { logError } from './output.js';
import { el } from './ui.js';

const IS_WINDOWS = /Windows/i.test(navigator.userAgent);

function field(form, label, input, help) {
  const l = el('label', 'lbl', label);
  const id = 'f-' + label.toLowerCase().replace(/\W+/g, '');
  input.id = id;
  l.htmlFor = id;
  form.append(l, input);
  if (help) form.appendChild(help);
}

export function openAddSheet(sheet, close) {
  sheet.replaceChildren();
  const name = el('input'); name.type = 'text'; name.placeholder = 'work'; name.autocomplete = 'off'; name.spellcheck = false;
  const email = el('input'); email.type = 'text'; email.placeholder = 'Optional'; email.autocomplete = 'off'; email.spellcheck = false;
  const sso = el('input'); sso.type = 'checkbox';
  const ssoWrap = el('label', 'check');
  ssoWrap.append(sso, document.createTextNode(' Use SSO'));

  const cancel = el('button', '', 'Cancel'); cancel.type = 'button';
  const go = el('button', 'primary', 'Add in Terminal'); go.type = 'button';
  go.disabled = true;
  // Same rule as cca: lowercase letters, digits, - and _, starting with a letter or digit.
  // Windows only: the macOS interface keeps its old behaviour.
  const NAME_RE = /^[a-z0-9][a-z0-9_-]*$/;
  const hint = el('div', 'help', 'Lowercase letters, digits, - and _ only.');
  name.addEventListener('input', () => {
    const v = name.value.trim();
    if (!IS_WINDOWS) { go.disabled = !v; return; }
    go.disabled = !NAME_RE.test(v);
    hint.classList.toggle('bad', !!v && !NAME_RE.test(v));
  });
  cancel.addEventListener('click', close);
  go.addEventListener('click', async () => {
    const args = ['add', name.value.trim()];
    if (email.value.trim()) args.push('--email', email.value.trim());
    if (sso.checked) args.push('--sso');
    go.disabled = true;
    try {
      const res = await window.cca.interactive(args);
      if (IS_WINDOWS && res && res.ok === false) {
        logError('add failed: ' + (res.error || 'the terminal did not start'));
        go.disabled = false;
        return;
      }
      close();
    } catch (e) {
      logError('add failed: ' + ((e && e.message) || e));
      go.disabled = false;
    }
  });

  const form = el('div', 'form');
  field(form, 'Name:', name, IS_WINDOWS ? hint : null);
  field(form, 'Email:', email);
  form.append(el('span', 'lbl', 'Sign-in:'), ssoWrap);
  const actions = el('div', 'sheet-actions');
  actions.append(cancel, go);
  sheet.append(
    el('h2', null, 'Add Account'),
    el('p', 'sheet-note', 'The login continues in a Terminal window. Pick the account’s colour on its page afterwards.'),
    form,
    actions,
  );
  name.focus();
}
