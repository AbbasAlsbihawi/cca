#!/bin/sh
# Uninstall cca: removes the ~/.zshrc lines, cca.zsh and cca launcher apps.
# Account data in ~/.claude-accounts is kept.
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

for app in "$HOME"/Applications/*.app; do
  [ -d "$app" ] || continue
  if [ -e "$app/Contents/Resources/cca-account" ]; then
    rm -rf "$app"
    echo "Removed launcher $app"
  fi
done

cat <<'MSG'

cca removed. Your account data was kept (profiles, desktop, bindings, default-name).
To remove it by hand:
  rm -rf ~/.claude-accounts
macOS keychain items named "Claude Code-credentials-<hash>" stay;
remove them in Keychain Access if you want.
MSG
