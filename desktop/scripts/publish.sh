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

echo "==> [1/5] Reading version from package.json"
V=$(node -p "require('./package.json').version")
[ -n "$V" ] || { echo "ERROR: could not read version" >&2; exit 1; }
echo "    version $V (tag v$V)"

echo "==> [2/5] Checking git state"
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

echo "==> [3/5] Verifying release assets in $DESKTOP_DIR/release"
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

echo "==> [4/5] Tagging and pushing"
git tag "v$V"
git push origin main
git push origin "v$V"

if [ -n "$PRERELEASE" ]; then
  echo "==> [5/5] Creating GitHub PRE-release v$V"
else
  echo "==> [5/5] Creating GitHub release v$V"
fi
set --
[ -n "$PRERELEASE" ] && set -- --prerelease
for f in $ASSETS; do
  set -- "$@" "release/$f"
done
gh release create "v$V" --title "Claude Accounts v$V" --generate-notes "$@"

echo "==> Done"
gh release view "v$V" --json url --jq .url
