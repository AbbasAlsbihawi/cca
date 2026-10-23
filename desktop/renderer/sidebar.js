// Sidebar: account rows.
export const COLORS = {
  red:'#e5534b', orange:'#e08a3c', yellow:'#d4b13a', green:'#3fb360', teal:'#2fb5a8',
  blue:'#4a8fe7', indigo:'#5b63d6', purple:'#9b6bdc', pink:'#e0629b', brown:'#a07a55',
  gray:'#8a8a92', grey:'#8a8a92', black:'#444', white:'#e8e8e8',
};
export const colorCss = (c) => COLORS[String(c || '').toLowerCase()] || (/^#[0-9a-f]{3,8}$/i.test(c || '') ? c : '');

export function renderSidebar(root, accounts, selected, onSelect) {
  root.replaceChildren();
  if (!accounts.length) {
    const e = document.createElement('div');
    e.className = 'empty';
    e.textContent = 'No accounts yet';
    root.appendChild(e);
    return;
  }
  for (const a of accounts) {
    const row = document.createElement('div');
    row.className = 'row' + (a.name === selected ? ' selected' : '');
    const dot = document.createElement('span');
    dot.className = 'dot';
    const css = colorCss(a.color);
    if (css) dot.style.background = css;
    const text = document.createElement('div');
    text.className = 'text';
    const name = document.createElement('div');
    name.className = 'name';
    name.textContent = a.name;
    const email = document.createElement('div');
    email.className = 'email';
    email.textContent = a.email || (a.loggedIn === false ? 'not logged in' : '');
    text.append(name, email);
    row.append(dot, text);
    if (a.isDefault) {
      const d = document.createElement('span');
      d.className = 'badge def';
      d.textContent = 'default';
      row.appendChild(d);
    }
    if (a.running) {
      const r = document.createElement('span');
      r.className = 'badge';
      r.textContent = 'running';
      row.appendChild(r);
    }
    row.addEventListener('click', () => onSelect(a.name));
    root.appendChild(row);
  }
}
