// Output panel: logs every command with its stdout/stderr.
const panel = () => document.getElementById('output-panel');
const logEl = () => document.getElementById('output-log');

function line(cls, text) {
  const s = document.createElement('span');
  s.className = cls;
  s.textContent = text.endsWith('\n') ? text : text + '\n';
  logEl().appendChild(s);
  logEl().scrollTop = logEl().scrollHeight;
}

export function initOutput() {
  document.getElementById('output-toggle').addEventListener('click', () => panel().classList.toggle('collapsed'));
  document.getElementById('output-clear').addEventListener('click', () => { logEl().textContent = ''; });
}

export function logCommand(args) { line('cmd', '$ cca ' + args.join(' ')); }
export function logError(msg) { line('stderr', String(msg)); panel().classList.remove('collapsed'); }

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
    panel().classList.remove('collapsed');
  }
  return res;
}

// Wraps an async action so the button is disabled while it runs.
export async function withBusy(btn, fn) {
  if (btn) btn.disabled = true;
  try { return await fn(); } finally { if (btn) btn.disabled = false; }
}
