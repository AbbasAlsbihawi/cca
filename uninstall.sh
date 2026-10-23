#!/bin/sh
# Uninstall cca: removes the ~/.zshrc lines, cca.zsh and cca launcher apps.
# Account data and backups in ~/.claude-accounts are kept.
set -e

rc="$HOME/.zshrc"
if [ -f "$rc" ]; then
  bak="$rc.bak-cca-$(date +%Y%m%d%H%M%S)"
  cp "$rc" "$bak"
  tmp=$(mktemp "${TMPDIR:-/tmp}/cca-zshrc.XXXXXX")
  grep -v -e '^# Claude Code accounts (cca)$' -e 'claude-accounts/cca.zsh' "$rc" > "$tmp" || true
  cat "$tmp" > "$rc"
  rm -f "$tmp"
  echo "Cleaned $rc (backup: $bak)"
fi

rm -f "$HOME/.claude-accounts/cca.zsh"

plist="$HOME/Library/LaunchAgents/dev.cca.backup.plist"
if [ -f "$plist" ]; then
  launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
  rm -f "$plist"
  echo "Removed the daily backup job"
fi

for app in "$HOME"/Applications/*.app; do
  [ -d "$app" ] || continue
  if [ -e "$app/Contents/Resources/cca-account" ]; then
    rm -rf "$app"
    echo "Removed launcher $app"
  fi
done

# The Mac app, only if it is ours.
app="$HOME/Applications/Claude Accounts.app"
if [ -d "$app" ] && [ "$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "dev.cca.accounts" ]; then
  rm -rf "$app"
  echo "Removed $app"
fi

cat <<'MSG'

cca removed. Your account data was kept (profiles, desktop, bindings, default-name, backups).
To remove it by hand:
  rm -rf ~/.claude-accounts
macOS keychain items named "Claude Code-credentials-<hash>" stay;
remove them in Keychain Access if you want.
MSG
