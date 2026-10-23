#!/bin/zsh
# Builds "build/Claude Accounts.app". With --install, copies it to ~/Applications.
set -e
cd "${0:A:h}"

app="build/Claude Accounts.app"
rm -rf build
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"

xcrun swiftc -O -parse-as-library -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
  -framework SwiftUI -framework AppKit Sources/*.swift -o "$app/Contents/MacOS/ClaudeAccounts"

mkdir -p build/tmp
if xcrun swiftc -O make-icon.swift -o build/tmp/make-icon \
   && build/tmp/make-icon build/tmp/AppIcon.iconset \
   && iconutil -c icns build/tmp/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"; then
  :
else
  print -u2 "warning: could not build the app icon; continuing without it"
  rm -f "$app/Contents/Resources/AppIcon.icns"
  plutil -remove CFBundleIconFile "$app/Contents/Info.plist" || true
fi
rm -rf build/tmp

codesign --force --sign - "$app"

if [[ ${1-} == --install ]]; then
  dest="$HOME/Applications/Claude Accounts.app"
  if [[ -e $dest/Contents/Resources/cca-account ]]; then
    print -u2 "error: $dest is a cca launcher, not this app; left alone"
    exit 1
  fi
  rm -rf "$dest"
  mkdir -p "$HOME/Applications"
  ditto "$app" "$dest"
  print -r -- "Installed $dest"
  exit 0
fi

print -r -- "${PWD}/$app"
