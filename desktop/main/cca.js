'use strict';
// Bridge to the cca CLI. Every call spawns with an argv array: no shell, no
// command string, so account names and folder paths are never interpreted.
const { spawn } = require('child_process');
const { EventEmitter } = require('events');
const fs = require('fs');
const os = require('os');
const path = require('path');

// 'changed' fires whenever the account data may have changed (tray, menu, IPC, terminals).
const bus = new EventEmitter();

const TIMEOUT_MS = 60000;
const MAX_OUTPUT = 10 * 1024 * 1024;

function ccaHome() {
  return process.env.CCA_HOME || path.join(os.homedir(), '.claude-accounts');
}

// PowerShell cannot read a script from inside app.asar, so use the unpacked
// copy when there is one, else copy the shim next to the app data.
let shimCache = null;
function shimPath() {
  if (shimCache) return shimCache;
  const src = path.join(__dirname, 'cca-shim.ps1');
  let out = src;
  if (/app\.asar([\\/]|$)/.test(src)) {
    const unpacked = src.replace(/app\.asar([\\/])/, 'app.asar.unpacked$1');
    if (fs.existsSync(unpacked)) {
      out = unpacked;
    } else {
      let dir = os.tmpdir();
      try { dir = require('electron').app.getPath('userData'); } catch (e) { /* keep tmpdir */ }
      fs.mkdirSync(dir, { recursive: true });
      out = path.join(dir, 'cca-shim.ps1');
      fs.writeFileSync(out, fs.readFileSync(src));
    }
  }
  shimCache = out;
  return out;
}

function command(args) {
  const home = ccaHome();
  if (process.platform === 'win32') {
    return {
      file: 'powershell.exe',
      argv: ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', shimPath(), ...args],
      env: { ...process.env, CCA_HOME: home },
    };
  }
  // A GUI-launched app gets a bare PATH; add where jq, python3 and claude usually live.
  const extra = ['/opt/homebrew/bin', '/usr/local/bin'];
  const have = (process.env.PATH || '/usr/bin:/bin:/usr/sbin:/sbin').split(':');
  const PATH = [...have, ...extra.filter((p) => !have.includes(p))].join(':');
  return {
    file: 'zsh',
    argv: ['-f', '-c', 'source "$CCA_HOME/cca.zsh" && cca "$@"', 'cca', ...args],
    env: { ...process.env, CCA_HOME: home, PATH },
  };
}

function runCca(args) {
  return new Promise((resolve) => {
    if (!Array.isArray(args) || !args.every((a) => typeof a === 'string' && !a.includes('\0'))) {
      resolve({ code: -1, stdout: '', stderr: 'invalid arguments' });
      return;
    }
    let child;
    let stdout = '';
    let stderr = '';
    let done = false;
    const finish = (r) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      resolve(r);
    };
    const timer = setTimeout(() => {
      try { child.kill('SIGKILL'); } catch (e) { /* already gone */ }
      finish({ code: -1, stdout, stderr: 'timed out' });
    }, TIMEOUT_MS);
    try {
      const c = command(args);
      child = spawn(c.file, c.argv, { env: c.env, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (err) {
      finish({ code: -1, stdout: '', stderr: String(err && err.message || err) });
      return;
    }
    child.stdout.on('data', (d) => { if (stdout.length < MAX_OUTPUT) stdout += d.toString('utf8'); });
    child.stderr.on('data', (d) => { if (stderr.length < MAX_OUTPUT) stderr += d.toString('utf8'); });
    child.on('error', (err) => finish({ code: -1, stdout, stderr: String(err && err.message || err) }));
    child.on('close', (code) => finish({ code: code === null ? -1 : code, stdout, stderr }));
  });
}

async function listAccounts() {
  try {
    const r = await runCca(['list', '--json']);
    if (r.code !== 0) return { ok: false, error: r.stderr.trim() || `cca list exited with ${r.code}` };
    return { ok: true, data: JSON.parse(r.stdout) };
  } catch (err) {
    return { ok: false, error: String(err && err.message || err) };
  }
}

module.exports = { runCca, listAccounts, ccaHome, shimPath, bus };
