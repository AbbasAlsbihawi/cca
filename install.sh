#!/bin/sh
# Install cca: copies cca.zsh to ~/.claude-accounts and hooks it into ~/.zshrc.
set -e

command -v zsh >/dev/null 2>&1 || { echo "install: zsh is required but not found" >&2; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
src="$here/cca.zsh"
[ -f "$src" ] || { echo "install: cca.zsh not found next to install.sh" >&2; exit 1; }

home_dir="$HOME/.claude-accounts"
mkdir -p "$home_dir" "$home_dir/profiles"
chmod 700 "$home_dir" "$home_dir/profiles"
cp "$src" "$home_dir/cca.zsh"
echo "Installed $home_dir/cca.zsh"

rc="$HOME/.zshrc"
[ -f "$rc" ] || : > "$rc"
if grep -q '^[^#]*claude-accounts/cca.zsh' "$rc"; then
  echo "$rc already loads cca"
else
  bak="$rc.bak-cca-$(date +%Y%m%d%H%M%S)"
  cp "$rc" "$bak"
  {
    echo ""
    echo "# Claude Code accounts (cca)"
    echo '[[ -r ~/.claude-accounts/cca.zsh ]] && source ~/.claude-accounts/cca.zsh'
  } >> "$rc"
  echo "Added cca to $rc (backup: $bak)"
fi

cat <<'MSG'

Next steps:
  1. Open a new terminal (or run: source ~/.zshrc)
  2. Name your current account before binding folders:
       echo work > ~/.claude-accounts/default-name
  3. Run: cca help

Desktop app (macOS and Windows, with automatic updates):
  download the .dmg from https://github.com/AbbasAlsbihawi/cca/releases
MSG
