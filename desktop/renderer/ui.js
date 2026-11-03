// Small builders shared by the pages: grouped rows and controls in the style of
// macOS System Settings. Text always goes in with textContent, never as markup.
import { withBusy } from './output.js';

export function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

// A button that is disabled while its action runs, then calls `after` (a refresh).
export function button(label, fn, cls, after) {
  const b = el('button', cls || '', label);
  b.type = 'button';
  b.addEventListener('click', () => withBusy(b, async () => {
    await fn();
    if (after) await after();
  }));
  return b;
}

// One row of a group: a label with an optional line under it, controls on the right.
export function row(label, sub, ...controls) {
  const r = el('div', 'grow');
  const k = el('div', 'k');
  k.appendChild(el('span', 'k-label', label));
  if (sub) k.appendChild(el('small', null, sub));
  r.appendChild(k);
  for (const c of controls) if (c) r.appendChild(c);
  return r;
}

// A titled box of rows. A null title gives a box with no heading.
export function group(title, rows) {
  const frag = document.createDocumentFragment();
  if (title) frag.appendChild(el('h3', 'group-title', title));
  const box = el('div', 'group');
  for (const r of rows) if (r) box.appendChild(r);
  frag.appendChild(box);
  return frag;
}

// A macOS-style switch: a checkbox drawn as a toggle, announced as a switch.
export function toggle(label, checked, onChange) {
  const s = el('input', 'switch');
  s.type = 'checkbox';
  s.setAttribute('role', 'switch');
  s.setAttribute('aria-label', label);
  s.checked = !!checked;
  s.addEventListener('change', () => withBusy(s, () => onChange(s.checked)));
  return s;
}

export function value(text) {
  const v = el('span', 'v', text);
  v.title = text;
  return v;
}

const SVG = 'http://www.w3.org/2000/svg';
// The gear in a grey rounded square, like the General item in System Settings.
export function gearSymbol(big) {
  const box = el('span', 'symbol' + (big ? ' big' : ''));
  box.setAttribute('aria-hidden', 'true');
  const svg = document.createElementNS(SVG, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  for (const d of ['M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4Z',
    'M19.4 13.5a7.6 7.6 0 0 0 0-3l2-1.6-2-3.4-2.4 1a7.5 7.5 0 0 0-2.6-1.5L14 2.5h-4l-.4 2.5A7.5 7.5 0 0 0 7 6.5l-2.4-1-2 3.4 2 1.6a7.6 7.6 0 0 0 0 3l-2 1.6 2 3.4 2.4-1a7.5 7.5 0 0 0 2.6 1.5l.4 2.5h4l.4-2.5a7.5 7.5 0 0 0 2.6-1.5l2.4 1 2-3.4-2-1.6Z']) {
    const p = document.createElementNS(SVG, 'path');
    p.setAttribute('d', d);
    svg.appendChild(p);
  }
  box.appendChild(svg);
  return box;
}

// Snapshots are named YYYY-MM-DD_HHMMSS; show them as a local date and time.
export function snapshotLabel(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})$/.exec(String(s));
  if (!m) return String(s);
  const d = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]);
  return Number.isNaN(d.getTime()) ? String(s) : d.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
}

// Native confirmation from the main process; window.confirm only if that is missing.
export async function confirmNative(opts) {
  if (window.cca && window.cca.confirm) {
    try { return await window.cca.confirm(opts); } catch (e) { /* fall through */ }
  }
  return window.confirm([opts.message, opts.detail].filter(Boolean).join('\n\n'));
}
