#!/bin/sh
# Uninstall cca: removes the ~/.zshrc lines, cca.zsh, cca launcher apps and the sign-in router.
# Account data and backups in ~/.claude-accounts are kept.
set -e

# Where the desktop app is looked for. The test suite points CCA_TEST_APPLICATIONS
# at a throwaway folder; it is honoured only for an existing folder inside the
# temporary folder, and anything else stops the script, so it can never send the
# removal anywhere else.
apps_dir=/Applications
if [ -n "${CCA_TEST_APPLICATIONS:-}" ]; then
  tmp_root=$(cd "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P) || tmp_root=
  test_dir=$(cd "$CCA_TEST_APPLICATIONS" 2>/dev/null && pwd -P) || test_dir=
  case "$tmp_root" in ''|/) test_dir= ;; esac
  case "$test_dir" in
    "$tmp_root"/?*) apps_dir=$test_dir ;;
    *) echo "uninstall: CCA_TEST_APPLICATIONS must be a folder inside ${TMPDIR:-/tmp}" >&2; exit 1 ;;
  esac
fi

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

# The launchd jobs cca can add: the daily backup, Claude app autoupdate and
# the job that keeps the sign-in router on.
for job in backup:"daily backup" update:"autoupdate" router:"sign-in router"; do
  plist="$HOME/Library/LaunchAgents/dev.cca.${job%%:*}.plist"
  if [ -f "$plist" ]; then
    launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
    rm -f "$plist"
    echo "Removed the ${job#*:} job"
  fi
done

# The sign-in router (`cca router on`): give claude:// links back to Claude,
# then remove it. Under the test suite macOS's link opener is never touched.
router="$HOME/Applications/Claude Link Router.app"
if [ -e "$router/Contents/Resources/cca-router" ]; then
  if [ -z "${CCA_TEST_APPLICATIONS:-}" ]; then
    osascript -l JavaScript -e 'ObjC.import("CoreServices"); $.LSSetDefaultHandlerForURLScheme($("claude"), $("com.anthropic.claudefordesktop"))' >/dev/null 2>&1 || true
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$router" 2>/dev/null || true
  fi
  rm -rf "$router"
  echo "Removed the sign-in router; Claude opens claude:// links again"
fi

for app in "$HOME"/Applications/*.app; do
  [ -d "$app" ] || continue
  if [ -e "$app/Contents/Resources/cca-account" ]; then
    rm -rf "$app"
    echo "Removed launcher $app"
  fi
done

# The desktop app, only if it is ours: "CCA.app" from 0.2.0, "Claude Accounts.app"
# before (an upgraded copy keeps that folder name). /Applications is where the dmg puts it;
# ~/Applications is where the retired Swift app installed itself.
for app in "$apps_dir/CCA.app" "$apps_dir/Claude Accounts.app" "$HOME/Applications/CCA.app" "$HOME/Applications/Claude Accounts.app"; do
  if [ -d "$app" ] && [ "$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "dev.cca.accounts" ]; then
    rm -rf "$app"
    echo "Removed $app"
  fi
done

cat <<'MSG'

cca removed. Your account data was kept (profiles, desktop, bindings, default-name, backups).
To remove it by hand:
  rm -rf ~/.claude-accounts
macOS keychain items named "Claude Code-credentials-<hash>" stay;
remove them in Keychain Access if you want.
MSG
