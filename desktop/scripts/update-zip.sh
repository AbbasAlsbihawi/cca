#!/bin/sh
# Build the update-only zip for one macOS arch from the full release zip:
#   sh scripts/update-zip.sh <version> <arm64|x64>
# It is the same app bundle minus Contents/Frameworks/*.framework, the ~115 MB of
# Electron that only changes when the electron version does. The updater fills
# those frameworks in from the installed app, and the bundle's own signature
# proves the result is the release byte for byte (see main/updater/mac.js).
# Its name carries the Electron version, so the updater knows before downloading
# whether the frameworks it has can be used.
# Progress goes to stderr; the zip's file name (inside release/) goes to stdout.
set -e

cd "$(dirname "$0")/.."

V=$1
ARCH=$2
case $ARCH in
  arm64|x64) ;;
  *) echo "ERROR: usage: sh scripts/update-zip.sh <version> <arm64|x64>" >&2; exit 1 ;;
esac
[ -n "$V" ] || { echo "ERROR: no version given" >&2; exit 1; }

FULL="release/ClaudeAccounts-$V-$ARCH-mac.zip"
[ -f "$FULL" ] || { echo "ERROR: $FULL is missing" >&2; exit 1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/cca-update-zip.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# Start from the zip that gets published, not from release/mac*, so the two
# downloads can never hold different builds.
ditto -x -k "$FULL" "$TMP/full"
APP="$TMP/full/Claude Accounts.app"
[ -d "$APP" ] || { echo "ERROR: $FULL holds no 'Claude Accounts.app'" >&2; exit 1; }
if ! codesign --verify --deep --strict "$APP" 2>/dev/null; then
  echo "ERROR: the bundle inside $FULL fails codesign --verify --deep --strict" >&2
  exit 1
fi

GOT=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
[ "$GOT" = "$V" ] || { echo "ERROR: $FULL holds version $GOT, not $V" >&2; exit 1; }

FW="$APP/Contents/Frameworks"
[ -d "$FW/Electron Framework.framework" ] || { echo "ERROR: $FULL has no Electron Framework" >&2; exit 1; }
# The version the running app reports as process.versions.electron.
EV=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$FW/Electron Framework.framework/Resources/Info.plist")
case $EV in
  ''|*[!0-9A-Za-z.-]*) echo "ERROR: unexpected Electron version '$EV'" >&2; exit 1 ;;
esac

# Take the frameworks out; they come back below for the round trip check.
mkdir "$TMP/frameworks"
mv "$FW/"*.framework "$TMP/frameworks/"

NAME="ClaudeAccounts-$V-$ARCH-update-electron-$EV.zip"
rm -f "release/ClaudeAccounts-$V-$ARCH-update-electron-"*.zip
# --norsrc: no extended attributes or resource forks, like the full zip.
ditto -c -k --norsrc --keepParent "$APP" "release/$NAME"

# Round trip: unpack the new zip, put the same frameworks back, as the updater
# does, and require the result to pass the same signature check.
ditto -x -k "release/$NAME" "$TMP/check"
mv "$TMP/frameworks/"*.framework "$TMP/check/Claude Accounts.app/Contents/Frameworks/"
if ! codesign --verify --deep --strict "$TMP/check/Claude Accounts.app" 2>/dev/null; then
  rm -f "release/$NAME"
  echo "ERROR: $NAME plus the frameworks of $FULL fails codesign --verify" >&2
  exit 1
fi

mb() { stat -Lf %z "$1" | awk '{ printf "%.1f MB", $1 / 1000000 }'; }
echo "    $ARCH: full zip $(mb "$FULL"), update-only zip $(mb "release/$NAME") (Electron $EV)" >&2
echo "$NAME"
