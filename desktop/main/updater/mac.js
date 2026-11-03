'use strict';
// macOS, hand written on purpose. The app is unsigned, and electron-updater's
// darwin path is Squirrel.Mac, which refuses to install an unsigned bundle. So
// this reads the GitHub releases feed, downloads the matching zip, unpacks it
// with ditto, and hands a detached script the one thing the running app cannot
// do itself: replace its own bundle. Every failure cleans up and reports.
// When the release was built with the Electron this app runs, it first tries the
// update-only zip (about 1 MB instead of over 100 MB) and fills in the Electron
// frameworks from the installed bundle; see stageFromUpdateZip.
const { app, dialog } = require('electron');
const { execFile, spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const https = require('https');
const os = require('os');
const path = require('path');
const { pipeline } = require('stream/promises');

const RELEASE_URL = 'https://api.github.com/repos/AbbasAlsbihawi/cca/releases/latest';
const NET_TIMEOUT_MS = 20 * 1000;
const DITTO_TIMEOUT_MS = 5 * 60 * 1000;
const CODESIGN_TIMEOUT_MS = 2 * 60 * 1000;
const MAX_FEED_BYTES = 2 * 1024 * 1024;
const MIN_ZIP_BYTES = 1024 * 1024; // a real app zip is tens of MB; less means an error page or a truncated body
const MIN_UPDATE_ZIP_BYTES = 64 * 1024; // the update-only zip is about 1 MB: the app code and no Electron
const MAX_ZIP_BYTES = 600 * 1024 * 1024;
const MAX_REDIRECTS = 4;

let busy = false; // one check at a time: the 4h timer must not stack downloads
const deferred = new Set(); // versions the user answered "Later" to this run

function userAgent() {
  let v = '0.0.0';
  try { v = app.getVersion(); } catch (e) { /* keep the placeholder */ }
  // GitHub rejects API requests without a User-Agent.
  return `ClaudeAccounts/${v} (+https://github.com/AbbasAlsbihawi/cca)`;
}

// --- network ---------------------------------------------------------------

// GET with redirects followed by hand (the asset URL redirects to S3).
function open(url, headers, depth = 0) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers }, (res) => {
      const code = res.statusCode || 0;
      const to = res.headers && res.headers.location;
      if (code >= 300 && code < 400 && to) {
        res.resume();
        if (depth >= MAX_REDIRECTS) { reject(new Error('too many redirects')); return; }
        resolve(open(new URL(to, url).toString(), headers, depth + 1));
        return;
      }
      if (code !== 200) { res.resume(); reject(new Error(`GitHub returned HTTP ${code}`)); return; }
      resolve(res);
    });
    req.setTimeout(NET_TIMEOUT_MS, () => req.destroy(new Error('network timeout')));
    req.on('error', reject);
  });
}

async function getJson(url) {
  const res = await open(url, { 'User-Agent': userAgent(), Accept: 'application/vnd.github+json' });
  res.setTimeout(NET_TIMEOUT_MS, () => res.destroy(new Error('network timeout')));
  const chunks = [];
  let len = 0;
  for await (const chunk of res) {
    len += chunk.length;
    if (len > MAX_FEED_BYTES) { res.destroy(); throw new Error('release feed too large'); }
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

// --- version and asset -----------------------------------------------------

// Exact x.y.z only, so a prerelease tag like 1.2.0-beta.1 never matches.
function parseVersion(v) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)$/.exec(String(v == null ? '' : v).trim());
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

// Numeric, part by part. A string compare would read 0.10.0 as older than 0.9.0.
function isNewer(remote, local) {
  const a = parseVersion(remote);
  const b = parseVersion(local);
  if (!a || !b) return false;
  for (let i = 0; i < 3; i += 1) {
    if (a[i] !== b[i]) return a[i] > b[i];
  }
  return false;
}

function releaseAssets(release) {
  return (Array.isArray(release.assets) ? release.assets : [])
    .filter((a) => a && typeof a.name === 'string' && a.browser_download_url);
}

// Keyed on the running architecture: installing an x64 build on arm64 (or the
// reverse) produces an app that cannot launch, so no match means no update.
function pickAsset(release, version) {
  const arch = process.arch;
  if (arch !== 'arm64' && arch !== 'x64') return null;
  const assets = releaseAssets(release);
  const exact = `claudeaccounts-${version}-${arch}-mac.zip`;
  const name = (a) => a.name.toLowerCase();
  return assets.find((a) => name(a) === exact)
    || assets.find((a) => name(a).endsWith('.zip') && name(a).includes(`-${arch}-mac`))
    || null;
}

// The update-only zip (scripts/update-zip.sh) names the Electron it was built
// with. Only an exact match with the running one is worth downloading; any other
// release, or one published without it, goes straight to the full zip.
function pickUpdateAsset(release, version) {
  const arch = process.arch;
  const electron = process.versions.electron;
  if ((arch !== 'arm64' && arch !== 'x64') || !electron) return null;
  const exact = `claudeaccounts-${version}-${arch}-update-electron-${electron}.zip`.toLowerCase();
  return releaseAssets(release).find((a) => a.name.toLowerCase() === exact) || null;
}

// --- the installed bundle --------------------------------------------------

// Walk up from the executable to the .app; never assume /Applications.
function installedBundle() {
  let dir = path.dirname(app.getPath('exe')); // .../Something.app/Contents/MacOS
  for (let i = 0; i < 4; i += 1) {
    if (dir.endsWith('.app')) return dir;
    const up = path.dirname(dir);
    if (up === dir) break;
    dir = up;
  }
  return null;
}

// The swap renames inside the bundle's parent directory, so that directory has
// to be writable for real - a mounted DMG is not, and accessSync alone can lie
// about a read-only volume, so probe it.
function swapBlocker(bundle) {
  const parent = path.dirname(bundle);
  const probe = path.join(parent, `.cca-update-probe-${process.pid}`);
  try {
    fs.writeFileSync(probe, '');
    fs.unlinkSync(probe);
    fs.accessSync(bundle, fs.constants.W_OK);
    return null;
  } catch (e) {
    try { fs.unlinkSync(probe); } catch (e2) { /* never existed */ }
    if (parent.startsWith('/Volumes/')) {
      return 'Claude Accounts is running from a disk image. Drag it into Applications, then check for updates again.';
    }
    return `Claude Accounts cannot update itself in ${parent}: that location is not writable.`;
  }
}

// --- download and unpack ---------------------------------------------------

async function download(asset, zip, version, send, minBytes = MIN_ZIP_BYTES) {
  const res = await open(asset.browser_download_url, { 'User-Agent': userAgent(), Accept: 'application/octet-stream' });
  res.setTimeout(NET_TIMEOUT_MS, () => res.destroy(new Error('download stalled')));

  const expected = Number(asset.size) > 0 ? Number(asset.size) : 0;
  let got = 0;
  let shown = -1;
  res.on('data', (chunk) => {
    got += chunk.length;
    if (got > MAX_ZIP_BYTES) { res.destroy(new Error('download is far larger than any release')); return; }
    if (!expected) return;
    const pct = Math.min(100, Math.floor((got / expected) * 100));
    if (pct !== shown) { shown = pct; send({ state: 'downloading', version, percent: pct, transferred: got, total: expected }); }
  });
  await pipeline(res, fs.createWriteStream(zip));

  // Prove the download finished: the declared size when GitHub gave us one, and
  // a floor otherwise. A truncated zip must never reach the swap.
  const size = fs.statSync(zip).size;
  if (expected && size !== expected) throw new Error(`download incomplete: ${size} of ${expected} bytes`);
  if (size < minBytes) throw new Error(`download too small to be an app (${size} bytes)`);

  // GitHub publishes a "sha256:<hex>" digest per asset. Check it, so a corrupted or
  // truncated body can never be unpacked over the installed app. The digest arrives
  // with the download URL on the same TLS connection, so this proves integrity, not
  // provenance. An algorithm we do not know is left to the size checks above rather
  // than failing every update if GitHub ever changes the format.
  const declared = typeof asset.digest === 'string' ? asset.digest.trim().toLowerCase() : '';
  const parsed = /^(sha256|sha512):([0-9a-f]{64,128})$/.exec(declared);
  if (parsed) {
    const [, algo, want] = parsed;
    const hash = crypto.createHash(algo);
    await pipeline(fs.createReadStream(zip), hash);
    const got = hash.digest('hex');
    if (got !== want) {
      throw new Error(`the update failed its ${algo} check (expected ${want.slice(0, 12)}…, got ${got.slice(0, 12)}…)`);
    }
  }
  return zip;
}

// A system tool; a failure rejects with what it printed, after `what`.
function run(file, args, timeout, what) {
  return new Promise((resolve, reject) => {
    execFile(file, args, { timeout }, (err, _out, stderr) => {
      if (err) reject(new Error(`${what}: ${String(stderr || err.message).trim().slice(0, 200)}`));
      else resolve();
    });
  });
}

// ditto, not unzip: it preserves the symlinks, permissions and metadata an .app
// bundle needs to launch at all.
function ditto(zip, dir) {
  return run('/usr/bin/ditto', ['-x', '-k', zip, dir], DITTO_TIMEOUT_MS, 'could not unpack the update');
}

function findBundle(dir) {
  const queue = [[dir, 0]];
  while (queue.length) {
    const [at, depth] = queue.shift();
    let entries = [];
    try { entries = fs.readdirSync(at, { withFileTypes: true }); } catch (e) { continue; }
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      const p = path.join(at, e.name);
      if (e.name.endsWith('.app')) return p;
      if (depth < 1) queue.push([p, depth + 1]);
    }
  }
  return null;
}

// A directory ending in .app is not enough; it has to carry an executable.
function isRunnable(bundle) {
  try {
    const macos = path.join(bundle, 'Contents', 'MacOS');
    return fs.statSync(macos).isDirectory() && fs.readdirSync(macos).length > 0;
  } catch (e) {
    return false;
  }
}

function bundleVersion(bundle) {
  try {
    const plist = fs.readFileSync(path.join(bundle, 'Contents', 'Info.plist'), 'utf8');
    const m = /<key>CFBundleShortVersionString<\/key>\s*<string>([^<]*)<\/string>/.exec(plist);
    return m ? m[1].trim() : null;
  } catch (e) {
    return null;
  }
}

// --- the update-only zip ---------------------------------------------------

// The small path: the update-only zip is the new bundle minus its
// Contents/Frameworks/*.framework, still carrying the signature of the full
// build. That signature seals the hash of every nested framework, so once the
// installed app's frameworks are copied in, codesign --verify passes only if they
// are byte for byte the ones the release was built with. Nothing is re-signed:
// what reaches the swap is the release's own bundle. Any mismatch throws, and the
// caller downloads the full zip instead.
async function stageFromUpdateZip(asset, dest, dir, version, send) {
  fs.mkdirSync(dir);
  const zip = await download(asset, path.join(dir, 'update.zip'), version, send, MIN_UPDATE_ZIP_BYTES);

  send({ state: 'unpacking', version });
  const out = path.join(dir, 'unpacked');
  fs.mkdirSync(out);
  await ditto(zip, out);
  const staged = findBundle(out);
  if (!staged) throw new Error('the update-only zip holds no app bundle');
  const inside = bundleVersion(staged);
  if (inside !== version) throw new Error(`the update-only zip holds version ${inside}, not ${version}`);

  const from = path.join(dest, 'Contents', 'Frameworks');
  const into = path.join(staged, 'Contents', 'Frameworks');
  const frameworks = fs.readdirSync(from).filter((n) => n.endsWith('.framework'));
  if (!frameworks.includes('Electron Framework.framework')) throw new Error('the installed app has no Electron Framework');
  for (const name of frameworks) {
    const target = path.join(into, name);
    if (fs.existsSync(target)) throw new Error(`the update-only zip already holds ${name}`);
    // -c clones on APFS (instant, no extra space) and falls back to a plain copy.
    await run('/bin/cp', ['-c', '-R', '-p', path.join(from, name), target], DITTO_TIMEOUT_MS, `could not copy ${name}`);
  }

  await run('/usr/bin/codesign', ['--verify', '--deep', '--strict', staged], CODESIGN_TIMEOUT_MS,
    'the assembled update fails its signature check');
  if (!isRunnable(staged)) throw new Error('the assembled update is not a usable app bundle');
  return staged;
}

// --- the swap --------------------------------------------------------------

const SWAP_SCRIPT = `#!/bin/bash
# Claude Accounts updater. Replaces the installed bundle once the old process is
# gone. Arguments: 1 = pid to wait for, 2 = installed .app, 3 = staged .app,
# 4 = temp directory to remove at the end. Paths arrive as arguments, never
# pasted into this text, so no path can be mistaken for shell syntax.
#
# THE ORDER BELOW IS THE WHOLE POINT: this is the one place where a mistake
# destroys the user's installation.
#   1. wait for the old process to exit - an app cannot replace its own bundle
#   2. move the staged bundle NEXT TO the installed one as "<app>.new"; across
#      volumes mv copies here, and the installed app is still whole while it does
#   3. verify "<app>.new" is a runnable bundle; bail out changing nothing if not
#   4. rename the installed bundle aside to "<app>.old"  <- atomic, same directory
#   5. rename "<app>.new" onto the real path             <- atomic, same directory
#      if that fails, rename "<app>.old" straight back and stop
#   6. only now delete "<app>.old", then the temp directory
# Steps 4 and 5 are renames within one directory, so at every instant a complete
# bundle sits at either the real path or the .old path. Nothing is ever copied
# over a live bundle, and nothing is deleted before its replacement is in place.
set -u

PID="$1"
DEST="$2"
STAGED="$3"
WORKDIR="$4"
NEW="$DEST.new"
OLD="$DEST.old"

# 1. Wait for the old app to exit. If it refuses to, change nothing at all.
i=0
while kill -0 "$PID" 2>/dev/null; do
  sleep 0.2
  i=$((i + 1))
  if [ "$i" -ge 300 ]; then exit 1; fi
done
sleep 1

# Leftovers from an interrupted run would make the renames below fail.
rm -rf "$NEW"

# 2. Stage beside the install; the installed app is untouched by this.
mv "$STAGED" "$NEW" || { rm -rf "$NEW"; exit 1; }

# Unsigned app: clear the quarantine flag or Gatekeeper will not open it.
/usr/bin/xattr -dr com.apple.quarantine "$NEW" 2>/dev/null || true

# 3. Go no further unless the replacement can actually run.
if [ ! -d "$NEW/Contents/MacOS" ] || [ -z "$(ls -A "$NEW/Contents/MacOS" 2>/dev/null)" ]; then
  rm -rf "$NEW"
  exit 1
fi

# 4. Installed bundle aside.
rm -rf "$OLD"
mv "$DEST" "$OLD" || { rm -rf "$NEW"; exit 1; }

# 5. Replacement into place; on failure put the old bundle straight back.
if ! mv "$NEW" "$DEST"; then
  mv "$OLD" "$DEST"
  rm -rf "$NEW"
  exit 1
fi

# 6. The new app is in place: now, and only now, throw the old one away.
rm -rf "$OLD"
rm -rf "$WORKDIR"

/usr/bin/open "$DEST" 2>/dev/null || true
`;

// The script lives outside the directory it deletes, so bash is never reading a
// file it has just removed. /tmp is cleaned by macOS.
function writeSwapScript() {
  const file = path.join(os.tmpdir(), `cca-update-${process.pid}-${crypto.randomBytes(4).toString('hex')}.sh`);
  fs.writeFileSync(file, SWAP_SCRIPT, { mode: 0o700 });
  return file;
}

function installAndQuit(dest, staged, work) {
  const script = writeSwapScript();
  const child = spawn('/bin/bash', [script, String(process.pid), dest, staged, work], {
    detached: true,
    stdio: 'ignore',
  });
  child.unref();
  app.quit();
}

// --- the check ------------------------------------------------------------

function cleanup(dir) {
  if (!dir) return;
  try { fs.rmSync(dir, { recursive: true, force: true }); } catch (e) { /* temp dir: leave it to the OS */ }
}

async function checkForUpdates(win, send) {
  if (busy) return;
  busy = true;
  let work = null;
  try {
    send({ state: 'checking' });

    let release = null;
    try {
      release = await getJson(RELEASE_URL);
    } catch (err) {
      // A 404 is not a failure: GitHub's "latest" skips prereleases, so it means
      // no full release is published yet and there is nothing to update to.
      // Offline, rate limited, DNS down: not worth alarming anyone over either.
      const why = String((err && err.message) || 'network error');
      if (/HTTP 404/.test(why)) send({ state: 'none' });
      else send({ state: 'none', message: `Could not reach GitHub: ${why}` });
      return;
    }

    if (!release || typeof release !== 'object' || release.draft || release.prerelease) {
      send({ state: 'none' });
      return;
    }
    const version = String(release.tag_name || '').trim().replace(/^v/, '');
    if (!isNewer(release.tag_name, app.getVersion())) {
      send({ state: 'none', version });
      return;
    }
    if (deferred.has(version)) {
      send({ state: 'available', version, message: 'Update postponed for now.' });
      return;
    }

    const asset = pickAsset(release, version);
    if (!asset) {
      send({ state: 'none', version, message: `Version ${version} has no build for this Mac (${process.arch}).` });
      return;
    }

    // Refuse before downloading anything if the swap could not succeed.
    const dest = installedBundle();
    if (!dest) {
      send({ state: 'error', message: 'Could not find the installed Claude Accounts app bundle.' });
      return;
    }
    const blocker = swapBlocker(dest);
    if (blocker) {
      send({ state: 'error', version, message: blocker });
      return;
    }

    send({ state: 'available', version });
    work = fs.mkdtempSync(path.join(os.tmpdir(), 'cca-update-'));

    let staged = null;
    const small = pickUpdateAsset(release, version);
    if (small) {
      const dir = path.join(work, 'small');
      try {
        staged = await stageFromUpdateZip(small, dest, dir, version, send);
      } catch (err) {
        // Not worth troubling anyone with: the full zip below does the same job.
        console.error(`update-only zip not used, downloading the full app: ${(err && err.message) || err}`);
        cleanup(dir);
      }
    }

    if (!staged) {
      const zip = await download(asset, path.join(work, 'update.zip'), version, send);

      send({ state: 'unpacking', version });
      const out = path.join(work, 'unpacked');
      fs.mkdirSync(out, { recursive: true });
      await ditto(zip, out);

      staged = findBundle(out);
      if (!staged || !isRunnable(staged)) {
        throw new Error('the downloaded update does not contain a usable app bundle');
      }
    }

    send({ state: 'ready', version });
    const { response } = await dialog.showMessageBox(win && !win.isDestroyed() ? win : null, {
      type: 'question',
      buttons: ['Install and restart', 'Later'],
      defaultId: 0,
      cancelId: 1,
      title: 'Update ready',
      message: `Claude Accounts ${version} is ready to install.`,
      detail: 'Claude Accounts will quit, replace itself and reopen. Choose Later to keep working - you will be asked again the next time the app starts.',
    });
    if (response !== 0) {
      deferred.add(version);
      cleanup(work);
      work = null;
      send({ state: 'available', version, message: 'Update postponed for now.' });
      return;
    }

    installAndQuit(dest, staged, work);
    work = null; // the swap script owns the temp directory from here on
  } catch (err) {
    cleanup(work);
    work = null;
    send({ state: 'error', message: (err && (err.message || String(err))) || 'update failed' });
  } finally {
    cleanup(work);
    busy = false;
  }
}

module.exports = { checkForUpdates };
