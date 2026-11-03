// Activity: every command with its stdout/stderr, in a panel kept out of the way.
// A failure shows as a banner over the page instead of opening the panel.
const panel = () => document.getElementById('output-panel');
const logEl = () => document.getElementById('output-log');
let bannerTimer = null;

function line(cls, text) {
  const s = document.createElement('span');
  s.className = cls;
  s.textContent = text.endsWith('\n') ? text : text + '\n';
  logEl().appendChild(s);
  logEl().scrollTop = logEl().scrollHeight;
}

export function showActivity() {
  panel().hidden = false;
  logEl().scrollTop = logEl().scrollHeight;
}

export function hideBanner() {
  clearTimeout(bannerTimer);
  document.getElementById('banner').hidden = true;
}

// kind 'error' stays until dismissed; 'ok' goes away by itself.
export function showBanner(text, kind = 'error') {
  const b = document.getElementById('banner');
  clearTimeout(bannerTimer);
  document.getElementById('banner-text').textContent = text;
  b.className = kind === 'ok' ? 'ok' : 'error';
  document.getElementById('banner-details').hidden = kind === 'ok';
  b.hidden = false;
  if (kind === 'ok') bannerTimer = setTimeout(hideBanner, 4000);
}

export function initOutput() {
  document.getElementById('output-close').addEventListener('click', () => { panel().hidden = true; });
  document.getElementById('output-clear').addEventListener('click', () => { logEl().textContent = ''; });
  document.getElementById('banner-details').addEventListener('click', () => { showActivity(); hideBanner(); });
  document.getElementById('banner-close').addEventListener('click', hideBanner);
}

export function logCommand(args) { line('cmd', '$ cca ' + args.join(' ')); }
export function logError(msg) { line('stderr', String(msg)); showBanner(String(msg)); }

// The first line that says what went wrong, for the banner; the full text stays in Activity.
function firstLine(text) {
  return String(text || '').split('\n').map((s) => s.trim()).find(Boolean) || '';
}

// Runs window.cca.run(args), logging command and output. Returns the result (never throws).
export async function runLogged(args) {
  logCommand(args);
  let res;
  try {
    res = await window.cca.run(args);
  } catch (e) {
    res = { code: -1, stdout: '', stderr: String((e && e.message) || e) };
  }
  res = res || { code: -1, stdout: '', stderr: 'no result' };
  if (res.stdout) line('stdout', String(res.stdout));
  if (res.stderr) line('stderr', String(res.stderr));
  if (res.code !== 0) {
    line('stderr', `(exit ${res.code})`);
    showBanner(`cca ${args[0]} failed: ${firstLine(res.stderr) || firstLine(res.stdout) || 'exit ' + res.code}`);
  }
  return res;
}

// Wraps an async action so the control is disabled, and shows as busy, while it runs.
export async function withBusy(btn, fn) {
  if (btn) { btn.disabled = true; btn.setAttribute('aria-busy', 'true'); }
  try { return await fn(); } finally { if (btn) { btn.disabled = false; btn.removeAttribute('aria-busy'); } }
}
