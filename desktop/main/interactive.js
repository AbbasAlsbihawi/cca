'use strict';
// Commands that prompt the user (cca add, cca login) run in a real terminal.
const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { ccaHome, listAccounts, shimPath } = require('./cca');

const INTERACTIVE_VERBS = new Set(['add', 'login']);
const NAME_RE = /^[a-z0-9][a-z0-9_-]*$/;
const POLL_MS = 2000;
const POLL_FOR_MS = 120000;

function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

// Writes a self-deleting .command file and opens it in Terminal.
function openMacScript(lines) {
  return new Promise((resolve) => {
    const file = path.join(os.tmpdir(), `cca-${crypto.randomUUID()}.command`);
    const body = [
      '#!/bin/zsh -f', 'rm -f -- "$0"', 'unset CLAUDECODE',
      `export CCA_HOME=${q(ccaHome())}`,
      `export PATH=${q((process.env.PATH || '/usr/bin:/bin') + ':/opt/homebrew/bin:/usr/local/bin')}`,
      ...lines,
    ];
    try {
      fs.writeFileSync(file, body.join('\n') + '\n', { mode: 0o700 });
      fs.chmodSync(file, 0o700);
    } catch (err) {
      resolve({ ok: false, error: `could not write ${file}: ${err.message}` });
      return;
    }
    const p = spawn('open', ['-a', 'Terminal', file], { stdio: 'ignore' });
    p.on('error', (err) => { try { fs.unlinkSync(file); } catch (e) { /* gone */ } resolve({ ok: false, error: err.message }); });
    p.on('close', (code) => {
      if (code === 0) { resolve({ ok: true }); return; }
      try { fs.unlinkSync(file); } catch (e) { /* gone */ }
      resolve({ ok: false, error: `could not open Terminal (exit ${code})` });
    });
  });
}

// On Windows `detached` means DETACHED_PROCESS: PowerShell gets no console and exits
// at once without running the script, so only detach elsewhere. With watchExit, a
// child that exits within a second and a half counts as a failed start; the windows
// we open with -NoExit stay up, while `cmd /c start` exits at once by design.
function spawnDetached(file, argv, env, watchExit) {
  return new Promise((resolve) => {
    let p;
    let settled = false;
    const done = (r) => { if (!settled) { settled = true; resolve(r); } };
    try {
      p = spawn(file, argv, { detached: process.platform !== 'win32', stdio: 'ignore', windowsHide: false, env: env || process.env });
    } catch (err) { done({ ok: false, error: err.message }); return; }
    p.on('error', (err) => done({ ok: false, error: err.message }));
    if (watchExit) {
      p.on('exit', (code) => done({ ok: false, error: `the terminal closed straight away (exit code ${code})` }));
    }
    p.on('spawn', () => {
      p.unref();
      if (watchExit) setTimeout(() => done({ ok: true }), 1500); else done({ ok: true });
    });
  });
}

// After a terminal is launched, watch the account list and call onChanged once it differs.
function watchForChange(onChanged, baseline) {
  let before = baseline && baseline.ok ? JSON.stringify(baseline.data) : null;
  const started = Date.now();
  const tick = async () => {
    const r = await listAccounts();
    if (r.ok) {
      const now = JSON.stringify(r.data);
      if (before === null) before = now;
      else if (now !== before) { onChanged(); before = now; }
    }
    if (Date.now() - started < POLL_FOR_MS) setTimeout(tick, POLL_MS);
  };
  tick();
}

async function runInteractive(args, onChanged) {
  if (!Array.isArray(args) || !args.length || !args.every((a) => typeof a === 'string' && !a.includes('\0'))) {
    return { ok: false, error: 'invalid arguments' };
  }
  if (args[0] === 'shell') return args.length === 2 ? openShell(args[1]) : { ok: false, error: 'usage: shell <name>' };
  if (!INTERACTIVE_VERBS.has(args[0])) return { ok: false, error: 'verb not allowed' };

  // Take the baseline list before the terminal can change anything.
  const baseline = await listAccounts();
  let res;
  if (process.platform === 'darwin') {
    res = await openMacScript([
      'source "$CCA_HOME/cca.zsh"',
      'cca ' + args.map(q).join(' '),
      "read -k1 '?Press any key to close…'",
    ]);
  } else if (process.platform === 'win32') {
    // Spawned directly, with no cmd.exe/start hop, so an account name is never re-parsed by a shell.
    res = await spawnDetached('powershell.exe', ['-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', shimPath(), ...args],
      { ...process.env, CCA_HOME: ccaHome() }, true);
  } else {
    return { ok: false, error: `unsupported platform ${process.platform}` };
  }
  if (res.ok && typeof onChanged === 'function') {
    watchForChange(onChanged, baseline);
  }
  return res;
}

// "New Terminal" for one account. Does not call cca; CCA_ACCOUNT picks the account.
async function openShell(name) {
  if (typeof name !== 'string' || !NAME_RE.test(name)) return { ok: false, error: 'invalid account name' };
  if (process.platform === 'darwin') {
    return openMacScript([
      `print -r -- ${q(`This terminal now uses: ${name}  (cca use - to stop)`)}`,
      `export CCA_ACCOUNT=${q(name)}; cd ~; exec /bin/zsh -il`,
    ]);
  }
  if (process.platform === 'win32') {
    return spawnDetached('cmd', ['/c', 'start', 'powershell', '-NoExit'],
      { ...process.env, CCA_HOME: ccaHome(), CCA_ACCOUNT: name });
  }
  return { ok: false, error: `unsupported platform ${process.platform}` };
}

module.exports = { runInteractive, openShell };
