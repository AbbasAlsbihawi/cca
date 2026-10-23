#!/bin/sh
# Cut a GitHub release from this machine. Build first: npm run dist:all
set -e

cd "$(dirname "$0")/.."
DESKTOP_DIR=$(pwd)

# --prerelease marks the release as not production ready on GitHub. Use it while
# an installer is still untested on its platform: the assets and tag are the same.
PRERELEASE=
while [ $# -gt 0 ]; do
  case $1 in
    --prerelease) PRERELEASE=1 ;;
    *) echo "ERROR: unknown option '$1' (the only option is --prerelease)" >&2; exit 1 ;;
  esac
  shift
done

echo "==> [1/6] Reading version from package.json"
V=$(node -p "require('./package.json').version")
[ -n "$V" ] || { echo "ERROR: could not read version" >&2; exit 1; }
echo "    version $V (tag v$V)"

echo "==> [2/6] Checking git state"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
  echo "ERROR: must be on main, currently on '$BRANCH'" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: git tree is not clean; commit or stash first" >&2
  git status --short >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/v$V" >/dev/null; then
  echo "ERROR: tag v$V already exists locally" >&2
  exit 1
fi
if [ -n "$(git ls-remote --tags origin "refs/tags/v$V")" ]; then
  echo "ERROR: tag v$V already exists on the remote" >&2
  exit 1
fi

echo "==> [3/6] Verifying release assets in $DESKTOP_DIR/release"
ASSETS="ClaudeAccounts-$V-arm64-mac.dmg
ClaudeAccounts-$V-x64-mac.dmg
ClaudeAccounts-$V-arm64-mac.zip
ClaudeAccounts-$V-x64-mac.zip
ClaudeAccounts-Setup-$V.exe
ClaudeAccounts-Setup-$V.exe.blockmap
latest.yml"
MISSING=0
for f in $ASSETS; do
  if [ -f "release/$f" ]; then
    echo "    ok       $f"
  else
    echo "    MISSING  $f" >&2
    MISSING=1
  fi
done
if [ "$MISSING" -ne 0 ]; then
  echo "ERROR: expected assets are missing; run: npm run dist:all" >&2
  exit 1
fi

echo "==> [4/6] Verifying the macOS code signature"
# The dmg and zip are packaged from these two bundles. macOS treats an app whose
# signature does not seal its resources as damaged: it removes a downloaded copy
# instead of opening it, which is how 0.1.0 to 0.1.2 shipped. Ad-hoc is what
# build.mac.identity "-" asks for; any other signature means the build picked up a
# certificate from this machine's keychain by accident, which must not be published.
for app in "release/mac-arm64/Claude Accounts.app" "release/mac/Claude Accounts.app"; do
  if [ ! -d "$app" ]; then
    echo "ERROR: built app is missing: $app" >&2
    exit 1
  fi
  if ! codesign --verify --deep --strict "$app" 2>/dev/null; then
    echo "ERROR: $app fails codesign --verify --deep --strict" >&2
    codesign --verify --deep --strict "$app" >&2 || true
    exit 1
  fi
  if ! codesign -dv "$app" 2>&1 | grep -q '^Signature=adhoc'; then
    echo "ERROR: $app is not ad-hoc signed; check build.mac.identity" >&2
    codesign -dv "$app" 2>&1 | grep -E '^(Identifier|Signature|Sealed)' >&2 || true
    exit 1
  fi
  echo "    ok       $app (ad-hoc, resources sealed)"
done

echo "==> [5/6] Tagging and pushing"
git tag "v$V"
git push origin main
git push origin "v$V"

if [ -n "$PRERELEASE" ]; then
  echo "==> [6/6] Creating GitHub PRE-release v$V"
else
  echo "==> [6/6] Creating GitHub release v$V"
fi
set --
[ -n "$PRERELEASE" ] && set -- --prerelease
for f in $ASSETS; do
  set -- "$@" "release/$f"
done
gh release create "v$V" --title "Claude Accounts v$V" --generate-notes "$@"

echo "==> Done"
gh release view "v$V" --json url --jq .url
