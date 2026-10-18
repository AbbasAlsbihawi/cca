#!/usr/bin/env zsh
# Test suite for cca.zsh. Runs everything in a throwaway HOME; touches nothing real.
# Usage: zsh tests/run.sh

REPO=${${(%):-%x}:A:h:h}
T=$(mktemp -d) || exit 1
T=${T:A}
trap 'rm -rf "$T"' EXIT INT TERM
H=$T/home
A=$H/.claude-accounts
integer pass=0 fail=0

ok()   { print -r -- "ok - $1"; pass+=1 }
bad()  { print -r -- "FAIL - $1: expected $2 got $3"; fail+=1 }
skip() { print -r -- "skip - $1" }
eq()   { [[ $3 == "$2" ]] && ok $1 || bad $1 "'$2'" "'$3'" }
has()  { [[ $3 == *"$2"* ]] && ok $1 || bad $1 "output containing '$2'" "'$3'" }
hasnt(){ [[ $3 != *"$2"* ]] && ok $1 || bad $1 "output without '$2'" "'$3'" }
yes()  { (( $2 == 0 )) && ok $1 || bad $1 "exit 0" "exit $2" }
no()   { (( $2 != 0 )) && ok $1 || bad $1 "non-zero exit" "exit $2" }

# Fresh fake HOME with a stub claude.
mk_home() {
  rm -rf $H $T/bin $T/work
  mkdir -p $H/.claude/skills $H/.claude/plugins $A $T/bin $T/work
  : > $H/.claude/settings.json
  : > $H/.claude/CLAUDE.md
  print -r -- '{"mcpServers":{"x":{"command":"echo"}},"theme":"dark","oauthAccount":{"emailAddress":"main@co.com","organizationName":"Co"}}' > $H/.claude.json
  print -r -- work > $A/default-name
  cp $REPO/cca.zsh $A/cca.zsh
  print -r -- '#!/bin/sh
echo "CFG=${CLAUDE_CONFIG_DIR-UNSET} ARGS=$*"' > $T/bin/claude
  chmod +x $T/bin/claude
}
prof() { mkdir -p $A/profiles/$1 }

# run '<zsh code>' : runs it after sourcing cca.zsh, outside Claude Code, in the fake HOME.
run() {
  env -u CLAUDECODE HOME=$H PATH=$T/bin:$PATH REPO=$REPO T=$T zsh -f -c 'source "$REPO/cca.zsh"; '"$1" 2>&1
}

mode() { stat -f %Lp $1 }

# 1. syntax and sourcing
mk_home
zsh -n $REPO/cca.zsh; yes "zsh -n cca.zsh" $?
out=$(env HOME=$H zsh -f -c 'source "$1" && echo ok' _ $REPO/cca.zsh 2>&1)
eq "sources without compinit" ok "$out"
out=$(run ':')
eq "sourcing prints nothing" "" "$out"

# 2. cca add
mk_home
out=$(run 'cca add personal --email a@b.c'); rc=$?
P=$A/profiles/personal
yes "add personal exits 0" $rc
eq "profile dir mode 700" 700 "$(mode $P)"
for i in settings.json CLAUDE.md skills plugins; do
  [[ -L $P/$i && $(readlink $P/$i) == $H/.claude/$i ]] && ok "symlink $i" || bad "symlink $i" "link to $H/.claude/$i" "$(ls -l $P/$i 2>&1)"
done
eq "only shared items that exist are linked" ".claude.json CLAUDE.md plugins settings.json skills" "$(ls -A $P | tr '\n' ' ' | sed 's/ $//')"
eq "seeded config keeps mcpServers+theme" '["mcpServers","theme"]' "$(jq -c 'keys' $P/.claude.json 2>&1)"
eq "seeded config has no oauthAccount" null "$(jq -c '.oauthAccount' $P/.claude.json 2>&1)"
eq ".claude.json mode 600" 600 "$(mode $P/.claude.json)"
has "login ran with email and profile dir" "CFG=$P ARGS=auth login --email a@b.c" "$out"

# 3. no binding
mk_home
eq "no binding -> default" "CFG=UNSET ARGS=-p hi" "$(run 'claude -p hi')"
eq "no binding unsets exported CLAUDE_CONFIG_DIR" "CFG=UNSET ARGS=-p hi" "$(run 'export CLAUDE_CONFIG_DIR=/x; claude -p hi')"

# 4. bindings
mk_home; prof personal
mkdir -p $T/work/p/sub/deep $T/work/p2 "$T/work/my dir/x"
PD=$A/profiles/personal
run 'cca bind personal $T/work/p' >/dev/null
eq "subfolder of bound folder -> profile" "CFG=$PD ARGS=x" "$(run 'cd $T/work/p/sub; claude x')"
run 'cca bind work $T/work/p/sub/deep' >/dev/null
eq "nested binding wins" "CFG=UNSET ARGS=x" "$(run 'cd $T/work/p/sub/deep; claude x')"
eq "outer binding still applies beside nested" "CFG=$PD ARGS=x" "$(run 'cd $T/work/p/sub; claude x')"
eq "sibling folder with same prefix -> UNSET" "CFG=UNSET ARGS=x" "$(run 'cd $T/work/p2; claude x')"
run 'cca bind personal "$T/work/my dir"' >/dev/null
eq "folder with a space binds and resolves" "CFG=$PD ARGS=x" "$(run 'cd "$T/work/my dir/x"; claude x')"

# 5. cca use
mk_home; prof personal; mkdir -p $T/work/p
run 'cca bind personal $T/work/p' >/dev/null
eq "use work beats binding" "CFG=UNSET ARGS=x" "$(run 'cd $T/work/p; cca use work >/dev/null; claude x')"
eq "use - restores binding" "CFG=$A/profiles/personal ARGS=x" "$(run 'cd $T/work/p; cca use work >/dev/null; cca use - >/dev/null; claude x')"

# 6. unbind
mk_home; prof personal; mkdir -p $T/work/p/sub $T/work/free
run 'cca bind personal $T/work/p' >/dev/null
out=$(run 'cca unbind $T/work/p'); rc=$?
yes "unbind bound folder exits 0" $rc
eq "unbind removes the binding" "CFG=UNSET ARGS=x" "$(run 'cd $T/work/p; claude x')"
out=$(run 'cca unbind $T/work/free'); rc=$?
no "unbind unbound folder fails" $rc
has "unbind unbound folder says so" "cca:" "$out"
run 'cca bind personal $T/work/p' >/dev/null
out=$(run 'cca unbind $T/work/p/sub'); rc=$?
no "unbind child of bound folder fails" $rc
has "unbind child message names parent" "$T/work/p" "$out"

# 7. errors
mk_home; prof personal
for c in 'cca add personal' "cca add 'Bad!'" 'cca add' 'cca use nope' 'cca use ../x' \
         'cca bind nope' 'cca run' 'cca foo' 'cca open nope'; do
  out=$(run "$c"); rc=$?
  no "error exit: $c" $rc
  has "error message: $c" "cca:" "$out"
done

# 8. list / status
mk_home
run '_cca_create personal' >/dev/null
mkdir -p $T/work/p
run 'cca bind personal $T/work/p' >/dev/null
out=$(run 'cca list')
[[ $out == *$'\n'* && $out =~ '(^|'$'\n'')\* work +main@co\.com' ]] && ok "list: * on default, work email" || bad "list: * on default, work email" "'* work ... main@co.com'" "'$out'"
has "list: org shown" "(Co)" "$out"
[[ $out =~ '(^|'$'\n'')  personal +not logged in' ]] && ok "list: personal not logged in" || bad "list: personal not logged in" "'  personal ... not logged in'" "'$out'"
out=$(run 'cca use personal >/dev/null; cca list')
[[ $out =~ '(^|'$'\n'')\* personal ' && $out =~ '(^|'$'\n'')  work ' ]] && ok "list: * follows cca use" || bad "list: * follows cca use" "'* personal'" "'$out'"
out=$(run 'cd $T/work/p; cca')
has "status: here line" "Here: personal" "$out"
has "status: lists accounts" "main@co.com" "$out"
has "status: lists bound folder" "$T/work/p -> personal" "$out"
eq "ls alias matches list" "$(run 'cca list')" "$(run 'cca ls')"

# 9. run
mk_home; prof personal
eq "cca run uses profile" "CFG=$A/profiles/personal ARGS=--version" "$(run 'cca run personal --version')"

# 10. inside Claude Code
mk_home
eq "CLAUDECODE passes through parent config" "CFG=/parent ARGS=x" "$(run 'export CLAUDECODE=1 CLAUDE_CONFIG_DIR=/parent; claude x')"

# 11. missing helpers
mk_home
out=$(run "unfunction -m '_cca_*'; cca list")
has "cca list re-sources helpers" "main@co.com" "$out"
eq "claude re-sources helpers" "CFG=UNSET ARGS=y" "$(run "unfunction -m '_cca_*'; claude y")"

# 12. cca open
mk_home; prof personal; prof other
STUBS='ps() { print -r -- " 111 /Applications/Claude.app/Contents/MacOS/Claude"; print -r -- " 222 /Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=$CCA_HOME/desktop/personal"; }
_cca_front() { echo FRONT $1; }
open() { echo OPEN "$@"; }'
eq "open default -> front its pid" "FRONT 111" "$(run "$STUBS"$'\n''cca open work')"
eq "open personal -> front its pid" "FRONT 222" "$(run "$STUBS"$'\n''cca open personal')"
eq "open not running account launches app" \
  "OPEN -n -a /Applications/Claude.app --env CLAUDE_CONFIG_DIR=$A/profiles/other --args --user-data-dir=$A/desktop/other" \
  "$(run "$STUBS"$'\n''cca open other')"
eq "open default when not running" "OPEN -n -a /Applications/Claude.app" \
  "$(run "$STUBS"$'\n''ps() { :; }'$'\n''cca open work')"

# 13. cca app
if ! command -v osacompile >/dev/null; then
  skip "cca app (osacompile missing)"
else
  mk_home
  F=$T/FakeClaude.app
  mkdir -p $F/Contents/Resources
  plutil -create xml1 $F/Contents/Info.plist
  plutil -insert CFBundleIconFile -string AppIcon $F/Contents/Info.plist
  cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns $F/Contents/Resources/AppIcon.icns
  D="$H/Applications/Claude Personal.app"
  out=$(run 'export CCA_CLAUDE_APP=$T/FakeClaude.app; cca app personal'); rc=$?
  yes "app personal exits 0" $rc
  [[ -d $D ]] && ok "launcher app exists" || bad "launcher app exists" "$D" "missing: $out"
  eq "marker names the account" personal "$(cat $D/Contents/Resources/cca-account 2>&1)"
  cmp -s $F/Contents/Resources/AppIcon.icns $D/Contents/Resources/applet.icns && ok "applet.icns is the Claude icon" || bad "applet.icns is the Claude icon" identical differs
  cv=$(codesign --verify $D 2>&1); yes "codesign --verify passes ($cv)" $?
  has "script runs cca open personal" "cca open personal" "$(osadecompile $D/Contents/Resources/Scripts/main.scpt 2>&1)"
  touch $D/stale
  out=$(run 'export CCA_CLAUDE_APP=$T/FakeClaude.app; cca app personal'); rc=$?
  yes "second app run exits 0" $rc
  [[ -d $D && ! -e $D/stale ]] && ok "second run replaces the app" || bad "second run replaces the app" "fresh app" "stale file kept or app missing"
  out=$(run 'export CCA_CLAUDE_APP=$T/FakeClaude.app; cca app personal purple'); rc=$?
  yes "app personal purple exits 0" $rc
  eq "cca-color saved" purple "$(cat $D/Contents/Resources/cca-color 2>&1)"
  cmp -s $F/Contents/Resources/AppIcon.icns $D/Contents/Resources/applet.icns && bad "purple icon is tinted" differs identical || ok "purple icon is tinted"
  sum1=$(cksum < $D/Contents/Resources/applet.icns)
  out=$(run 'export CCA_CLAUDE_APP=$T/FakeClaude.app; cca app personal'); rc=$?
  yes "app without color exits 0" $rc
  eq "color kept when none given" purple "$(cat $D/Contents/Resources/cca-color 2>&1)"
  eq "tinted icon kept when none given" "$sum1" "$(cksum < $D/Contents/Resources/applet.icns)"
  touch $D/stale
  out=$(run 'export CCA_CLAUDE_APP=$T/FakeClaude.app; cca app personal nocolor'); rc=$?
  no "unknown color is refused" $rc
  has "unknown color lists colors" "purple" "$out"
  [[ -e $D/stale ]] && eq "unknown color leaves launcher unchanged" purple "$(cat $D/Contents/Resources/cca-color 2>&1)" || bad "unknown color leaves launcher unchanged" "stale kept" "launcher rebuilt"
  rm -f $D/stale
  mkdir -p "$H/Applications/Claude Other.app/Contents/Resources"
  out=$(run 'export CCA_CLAUDE_APP=$T/FakeClaude.app; cca app other'); rc=$?
  no "foreign app is refused" $rc
  [[ ! -e $A/profiles/other ]] && ok "foreign app: no profile created" || bad "foreign app: no profile created" "no profiles/other" "profile exists"
fi

print
print -r -- "$pass passed, $fail failed"
(( fail == 0 ))
