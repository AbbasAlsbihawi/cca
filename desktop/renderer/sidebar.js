// Sidebar: the accounts, then the General page, in the style of System Settings.
import { el, gearSymbol } from './ui.js';

export const COLORS = {
  red:'#e5534b', orange:'#e08a3c', yellow:'#d4b13a', green:'#3fb360', teal:'#2fb5a8',
  blue:'#4a8fe7', indigo:'#5b63d6', purple:'#9b6bdc', pink:'#e0629b', brown:'#a07a55',
  gray:'#8a8a92', grey:'#8a8a92', black:'#444', white:'#e8e8e8',
};
export const colorCss = (c) => COLORS[String(c || '').toLowerCase()] || (/^#[0-9a-f]{3,8}$/i.test(c || '') ? c : '');

// A round badge in the account's colour with its first letter.
export function avatar(a, big) {
  const v = el('span', 'avatar' + (big ? ' big' : ''), String(a.name || '?').charAt(0));
  v.setAttribute('aria-hidden', 'true');
  const css = colorCss(a.color);
  if (css) v.style.background = css;
  return v;
}

function item(current, onClick, ...children) {
  const b = el('button', 'side-row');
  b.type = 'button';
  if (current) b.setAttribute('aria-current', 'page');
  b.append(...children);
  b.addEventListener('click', onClick);
  return b;
}

// view: { page: 'account' | 'general', selected }; on: { select(name), general() }
export function renderSidebar(root, accounts, view, on) {
  // Keep keyboard focus in the list when it is rebuilt under it.
  const hadFocus = root.contains(document.activeElement);
  root.replaceChildren();

  root.appendChild(el('div', 'side-sec', 'Accounts'));
  if (!accounts.length) root.appendChild(el('div', 'side-empty', 'No accounts yet'));
  for (const a of accounts) {
    const txt = el('span', 'txt');
    txt.append(el('span', 'name', a.name), el('span', 'sub', a.email || (a.loggedIn === false ? 'Not logged in' : '')));
    const parts = [avatar(a), txt];
    if (a.running) {
      const dot = el('span', 'run-dot');
      dot.title = 'Claude is open';
      parts.push(dot, el('span', 'sr', 'Claude is open'));
    }
    root.appendChild(item(view.page === 'account' && a.name === view.selected, () => on.select(a.name), ...parts));
  }

  root.appendChild(el('div', 'side-sec', 'App'));
  const g = el('span', 'txt');
  g.appendChild(el('span', 'name', 'General'));
  root.appendChild(item(view.page === 'general', on.general, gearSymbol(), g));

  if (hadFocus) {
    const cur = root.querySelector('[aria-current="page"]');
    if (cur) cur.focus();
  }
}

// Up and Down move through the list, as in a macOS source list.
export function wireSidebarKeys(root) {
  root.addEventListener('keydown', (e) => {
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    const rows = [...root.querySelectorAll('.side-row')];
    const at = rows.indexOf(document.activeElement);
    if (at < 0) return;
    const next = rows[at + (e.key === 'ArrowDown' ? 1 : -1)];
    if (!next) return;
    e.preventDefault();
    next.click(); // the list is rebuilt, and focus follows the new current row
  });
}
