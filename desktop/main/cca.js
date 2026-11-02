'use strict';
// Bridge to the cca CLI. Every call spawns with an argv array: no shell, no
// command string, so account names and folder paths are never interpreted.
const { spawn } = require('child_process');
const crypto = require('crypto');
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

// Where Claude's own installer puts `claude`.
function localBin() {
  return path.join(os.homedir(), '.local', 'bin');
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

// Windows: the installer carries cca.ps1, so the app works without install.ps1.
// Puts it in CCA_HOME when it is missing, and refreshes it after an app update only
// if this app wrote it: a copy from install.ps1 or edited by hand stays as it is.
// A failure is not fatal here; the shim reports the missing file on the first command.
function ensureCli() {
  if (process.platform !== 'win32') return;
  const sha = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
  const readOr = (file, fallback) => {
    try { return fs.readFileSync(file); } catch (e) { return fallback; }
  };
  try {
    const { app } = require('electron');
    const src = fs.readFileSync(app.isPackaged
      ? path.join(process.resourcesPath, 'cli', 'cca.ps1')
      : path.join(__dirname, '..', '..', 'cca.ps1'));
    const dst = path.join(ccaHome(), 'cca.ps1');
    const mark = path.join(ccaHome(), 'cca.ps1.app-sha256');
    const have = readOr(dst, null);
    if (have && (sha(have) === sha(src) || sha(have) !== String(readOr(mark, '')))) return;
    fs.mkdirSync(path.join(ccaHome(), 'profiles'), { recursive: true });
    fs.writeFileSync(dst, src);
    fs.writeFileSync(mark, sha(src));
  } catch (err) {
    console.error(`could not install cca.ps1: ${err && err.message || err}`);
  }
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
  const extra = [localBin(), '/opt/homebrew/bin', '/usr/local/bin'];
  const have = (process.env.PATH || '/usr/bin:/bin:/usr/sbin:/sbin').split(':');
  const PATH = [...have, ...extra.filter((p) => !have.includes(p))].join(':');
  return {
    file: 'zsh',
    argv: ['-f', '-c', 'source "$CCA_HOME/cca.zsh" && cca "$@"', 'cca', ...args],
    env: { ...process.env, CCA_HOME: home, PATH },
  };
}

function runCca(args, timeoutMs = TIMEOUT_MS) {
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
    }, timeoutMs);
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
    if (!r.stdout.trim()) return { ok: false, error: r.stderr.trim() || 'cca list printed nothing' };
    return { ok: true, data: JSON.parse(r.stdout) };
  } catch (err) {
    return { ok: false, error: String(err && err.message || err) };
  }
}

module.exports = { runCca, listAccounts, ccaHome, localBin, shimPath, ensureCli, bus };
