// "Open Terminal" / "New Terminal" on Windows, run with: node --test desktop/test
// The shell must load cca.ps1 itself: CCA_ACCOUNT is read only by cca.ps1, and a
// user who never ran install.ps1 has no profile line that loads it. Without it,
// `claude` in that window silently used the default account.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const childProcess = require('child_process');
const { EventEmitter } = require('events');
const fs = require('fs');
const os = require('os');
const path = require('path');

const desktop = path.join(__dirname, '..');
const repo = path.join(desktop, '..');
const FAKE_HOME = path.join(os.tmpdir(), 'cca-open-shell-test-home');

// interactive.js takes spawn from child_process when it loads, so swap it in first.
const calls = [];
const realSpawn = childProcess.spawn;
childProcess.spawn = (file, argv, opts) => {
  calls.push({ file, argv, opts });
  const p = new EventEmitter();
  p.unref = () => {};
  setImmediate(() => p.emit('spawn'));
  return p;
};
const ccaPath = require.resolve(path.join(desktop, 'main', 'cca.js'));
require.cache[ccaPath] = {
  id: ccaPath, filename: ccaPath, loaded: true,
  exports: { ccaHome: () => FAKE_HOME, listAccounts: async () => ({ ok: false }), localBin: () => '', shimPath: () => '' },
};
const { openShell } = require(path.join(desktop, 'main', 'interactive.js'));
childProcess.spawn = realSpawn;

async function openOnWindows(name) {
  const saved = Object.getOwnPropertyDescriptor(process, 'platform');
  Object.defineProperty(process, 'platform', { value: 'win32' });
  calls.length = 0;
  try { return { res: await openShell(name), call: calls[0] }; } finally { Object.defineProperty(process, 'platform', saved); }
}

function decoded(argv) {
  const i = argv.indexOf('-EncodedCommand');
  assert.ok(i >= 0 && argv[i + 1], 'PowerShell gets its startup script as -EncodedCommand');
  return Buffer.from(argv[i + 1], 'base64').toString('utf16le');
}

test('the Windows terminal loads cca.ps1 from CCA_HOME and keeps CCA_ACCOUNT', async () => {
  const { res, call } = await openOnWindows('acme');
  assert.deepStrictEqual(res, { ok: true });
  assert.strictEqual(call.file, 'cmd');
  assert.deepStrictEqual(call.argv.slice(0, 7), ['/c', 'start', 'powershell', '-NoExit', '-ExecutionPolicy', 'Bypass', '-EncodedCommand']);
  assert.strictEqual(call.opts.env.CCA_ACCOUNT, 'acme');
  assert.strictEqual(call.opts.env.CCA_HOME, FAKE_HOME);
  const script = decoded(call.argv);
  assert.match(script, /Join-Path \$env:CCA_HOME 'cca\.ps1'/);
  assert.match(script, /Get-Command cca -CommandType Function/, 'a profile that already loads cca.ps1 is not loaded twice');
  assert.match(script, /This terminal now uses: acme {2}\(cca use - to stop\)/);
});

test('nothing reaches cmd.exe that it could re-parse', async () => {
  const { call } = await openOnWindows('client_2-x');
  for (const a of call.argv) assert.doesNotMatch(a, /[\s"'&|<>^%!()]/, `argument ${a.slice(0, 40)} is safe for cmd /c start`);
});

test('an invalid account name opens nothing', async () => {
  for (const bad of ['', 'Acme', "a'b", 'a b', '-x', 'a&calc']) {
    const { res, call } = await openOnWindows(bad);
    assert.strictEqual(res.ok, false, `refused: ${JSON.stringify(bad)}`);
    assert.strictEqual(call, undefined);
  }
});

// Runs the real startup script in pwsh against the real cca.ps1, where pwsh exists.
function pwsh() {
  for (const p of ['/opt/homebrew/bin/pwsh', '/usr/local/bin/pwsh', '/usr/bin/pwsh']) if (fs.existsSync(p)) return p;
  try { childProcess.execFileSync('pwsh', ['-NoProfile', '-Command', '1'], { stdio: 'ignore' }); return 'pwsh'; } catch (e) { return null; }
}

test('in PowerShell the script loads cca and sets this terminal\'s account', { skip: pwsh() ? false : 'pwsh not installed' }, async () => {
  const { call } = await openOnWindows('acme');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'cca-open-shell-'));
  try {
    fs.mkdirSync(path.join(home, '.claude-accounts'));
    fs.copyFileSync(path.join(repo, 'cca.ps1'), path.join(home, '.claude-accounts', 'cca.ps1'));
    const check = decoded(call.argv) + "\n'loaded=' + [bool](Get-Command cca -CommandType Function -EA 0); 'account=' + $global:CCA_ACCOUNT; 'env=' + $env:CCA_ACCOUNT";
    const out = childProcess.execFileSync(pwsh(), ['-NoProfile', '-NonInteractive', '-Command', check], {
      env: { PATH: process.env.PATH, HOME: home, APPDATA: path.join(home, 'AppData'), CCA_HOME: path.join(home, '.claude-accounts'), CCA_ACCOUNT: 'acme' },
      encoding: 'utf8', timeout: 60000,
    });
    assert.match(out, /This terminal now uses: acme/);
    assert.match(out, /loaded=True/);
    assert.match(out, /account=acme/);
    assert.match(out, /env=\s*$/m, 'CCA_ACCOUNT leaves the environment, as cca.ps1 does');
  } finally { fs.rmSync(home, { recursive: true, force: true }); }
});

function runScript(prefix, withCcaPs1) {
  return openOnWindows('acme').then(({ call }) => {
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'cca-open-shell-'));
    try {
      fs.mkdirSync(path.join(home, '.claude-accounts'));
      if (withCcaPs1) fs.copyFileSync(path.join(repo, 'cca.ps1'), path.join(home, '.claude-accounts', 'cca.ps1'));
      return childProcess.execFileSync(pwsh(), ['-NoProfile', '-NonInteractive', '-Command', prefix + '\n' + decoded(call.argv) + "\n'cca says: ' + (cca)"], {
        env: { PATH: process.env.PATH, HOME: home, APPDATA: path.join(home, 'AppData'), CCA_HOME: path.join(home, '.claude-accounts'), CCA_ACCOUNT: 'acme' },
        encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (e) { return String(e.stdout || '') + String(e.stderr || ''); } finally { fs.rmSync(home, { recursive: true, force: true }); }
  });
}

test('a cca already loaded by the profile is kept, not loaded again', { skip: pwsh() ? false : 'pwsh not installed' }, async () => {
  const out = await runScript("function global:cca { 'from the profile' }", true);
  assert.match(out, /cca says: from the profile/);
  assert.match(out, /This terminal now uses: acme/);
});

test('without cca.ps1 the window warns instead of claiming an account', { skip: pwsh() ? false : 'pwsh not installed' }, async () => {
  const out = await runScript('', false);
  assert.match(out, /cca\.ps1 is missing from .* uses the default account/);
  assert.doesNotMatch(out, /This terminal now uses/);
});
