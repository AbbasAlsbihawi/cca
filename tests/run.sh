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
# 14. reload after an update
mk_home
cp $REPO/cca.zsh $T/cca-copy.zsh
out=$(env -u CLAUDECODE HOME=$H PATH=$T/bin:$PATH T=$T zsh -f -c '
  source $T/cca-copy.zsh
  print -r -- "_cca_help() { print -r -- RELOADED }" >> $T/cca-copy.zsh
  touch -t 203001010000 $T/cca-copy.zsh
  cca help' 2>&1)
eq "cca reloads itself after the file changes" RELOADED "$out"
out=$(run 'cca help' | head -1)
has "unchanged file: normal help" "cca — switch" "$out"

# 15. cca remove
mk_home
print -r -- "#!/bin/sh
echo \"CFG=\${CLAUDE_CONFIG_DIR-UNSET} ARGS=\$*\" >> $T/claude.log" > $T/bin/claude
prof personal; prof other
mkdir -p $A/desktop/personal $T/work/p $T/work/o
for n in Personal Work; do
  mkdir -p "$H/Applications/Claude $n.app/Contents/Resources"
  print -r -- ${(L)n} > "$H/Applications/Claude $n.app/Contents/Resources/cca-account"
done
print -r -- "$T/work/p"$'\t'"personal"$'\n'"$T/work/o"$'\t'"other" > $A/bindings
rm -f $T/claude.log
out=$(run 'ps() { :; }; CCA_TRASH=$T/trash cca remove personal')
has "remove: message" "Removed 'personal'" "$out"
has "remove: logs out the account" "CFG=$A/profiles/personal ARGS=auth logout" "$(<$T/claude.log)"
[[ ! -e $A/profiles/personal && ! -e $A/desktop/personal && ! -e "$H/Applications/Claude Personal.app" ]] \
  && ok "remove: folders and launcher gone" || bad "remove: folders and launcher gone" "gone" "still there"
eq "remove: 3 items in the Trash" 3 "$(ls $T/trash | wc -l | tr -d ' ')"
eq "remove: only its bindings dropped" "$T/work/o"$'\t'"other" "$(<$A/bindings)"
[[ -d $A/profiles/other ]] && ok "remove: other accounts untouched" || bad "remove: other accounts untouched" "kept" "gone"
rm -f $T/claude.log
out=$(run 'ps() { :; }; CCA_TRASH=$T/trash cca remove work')
has "remove default: logs out ~/.claude" "CFG=UNSET ARGS=auth logout" "$(<$T/claude.log)"
[[ ! -e "$H/Applications/Claude Work.app" && -d $H/.claude ]] \
  && ok "remove default: launcher gone, ~/.claude kept" || bad "remove default: launcher gone, ~/.claude kept" "yes" "no"
out=$(run 'ps() { print -r -- " 9 /Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=$CCA_HOME/desktop/other"; }; CCA_TRASH=$T/trash cca remove other'); rc=$?
no "remove: refuses while its app is open" $rc
[[ -d $A/profiles/other ]] && ok "remove: nothing moved when refused" || bad "remove: nothing moved when refused" "kept" "gone"
out=$(run 'cca remove nope'); no "remove: unknown account" $?

# 16. cca restore from the main app (and the older name, cca import)
mk_home
U=11111111-2222-3333-4444-555555555555 O=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
C1=99999999-0000-0000-0000-000000000001 C2=99999999-0000-0000-0000-000000000002
MS="$H/Library/Application Support/Claude/claude-code-sessions/$U/$O"
mkdir -p $MS $H/.claude/projects/-w-p/$C1/subagents
print -r -- "{\"sessionId\":\"local_1\",\"cliSessionId\":\"$C1\"}" > $MS/local_1.json
print -r -- $'{\n  "sessionId": "local_2",\n  "cliSessionId": "'$C2$'"\n}' > $MS/local_2.json
print -r -- x > $MS/archived-sessions.idx
print -r -- t1 > $H/.claude/projects/-w-p/$C1.jsonl
print -r -- s > $H/.claude/projects/-w-p/$C1/subagents/a.jsonl
prof personal
print -r -- "{\"oauthAccount\":{\"accountUuid\":\"$U\"}}" > $A/profiles/personal/.claude.json
out=$(run 'ps() { :; }; cca restore personal --dry-run')
has "restore dry run: counts" "Would restore 'personal' from the main Claude app: 2 sessions, 1 transcripts, 0 deleted marks" "$out"
[[ ! -e $A/desktop/personal && ! -e $A/profiles/personal/projects ]] && ok "restore dry run: copies nothing" || bad "restore dry run: copies nothing" "no folder" "folder made"
out=$(run 'ps() { :; }; cca restore personal')
has "restore from main app: copies" "Restored 'personal' from the main Claude app: 2 sessions, 1 transcripts" "$out"
has "restore from main app: reports missing transcripts" "1 sessions have no transcript" "$out"
D=$A/desktop/personal/claude-code-sessions/$U/$O
[[ -f $D/local_1.json && -f $D/local_2.json && -f $D/archived-sessions.idx ]] \
  && ok "restore from main app: session files copied" || bad "restore from main app: session files copied" "3 files" "$(ls $D 2>&1)"
[[ -f $A/profiles/personal/projects/-w-p/$C1.jsonl && -f $A/profiles/personal/projects/-w-p/$C1/subagents/a.jsonl ]] \
  && ok "restore from main app: transcript and subagents copied" || bad "restore from main app: transcript and subagents copied" "copied" "missing"
eq "restore from main app: main app unchanged" 3 "$(ls $MS | wc -l | tr -d ' ')"
print -r -- mine > $D/local_1.json
out=$(run 'ps() { :; }; cca restore personal')
has "restore again: nothing new" "0 sessions, 0 transcripts" "$out"
eq "restore: never overwrites" mine "$(<$D/local_1.json)"
out=$(run 'ps() { :; }; cca import personal --dry-run')
has "import still works as an older name" "Would restore 'personal'" "$out"
out=$(run 'cca restore work'); no "restore: default account has no main-app import" $?
out=$(run 'ps() { print -r -- " 9 /Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=$CCA_HOME/desktop/personal"; }; cca restore personal'); no "restore: refuses while its app is open" $?
prof other
out=$(run 'ps() { :; }; cca restore other' 2>&1); rc=$?
no "restore: unknown account uuid refused" $rc
has "restore: lists accounts in the main app" "$U  2 sessions" "$out"
out=$(run "ps() { :; }; cca restore other --account $U --dry-run")
has "restore --account" "Would restore 'other' from the main Claude app" "$out"
[[ ! -e $A/desktop/other ]] && ok "restore --account dry run: copies nothing" || bad "restore --account dry run: copies nothing" "no folder" "folder made"

# 17. backups
mk_home
U=11111111-2222-3333-4444-555555555555 O=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
W=22222222-2222-3333-4444-555555555555
C1=99999999-0000-0000-0000-000000000001 C2=99999999-0000-0000-0000-000000000002
MAD="$H/Library/Application Support/Claude"
LA=$H/Library/LaunchAgents
BK=$A/backups
# default account (work): main app sessions + ~/.claude transcripts; personal: its own copy
mkdir -p "$MAD/claude-code-sessions/$W/$O" $H/.claude/projects/-w-a
print -r -- '{"sessionId":"local_w1"}' > "$MAD/claude-code-sessions/$W/$O/local_w1.json"
print -r -- w1 > $H/.claude/projects/-w-a/w1.jsonl
prof personal
mkdir -p $A/desktop/personal/claude-code-sessions/$U/$O $A/profiles/personal/projects/-p-b
print -r -- '{"sessionId":"local_p1","cliSessionId":"p1"}' > $A/desktop/personal/claude-code-sessions/$U/$O/local_p1.json
print -r -- p1 > $A/profiles/personal/projects/-p-b/p1.jsonl
print -r -- "{\"oauthAccount\":{\"accountUuid\":\"$U\"}}" > $A/profiles/personal/.claude.json
print -r -- "$T/work"$'\t'personal > $A/bindings
CTX='export CCA_MAIN_APP_DATA="$HOME/Library/Application Support/Claude" CCA_LAUNCH_AGENTS=$HOME/Library/LaunchAgents CCA_TRASH=$T/trash
ps() { :; }
launchctl() { print -r -- "LAUNCHCTL $*" >> $T/launchctl.log; }'
out=$(run "$CTX"$'\n''cca backup'); rc=$?
yes "backup exits 0" $rc
has "backup prints a summary" "2 accounts, 4 folders" "$out"
SN=$(ls $BK | grep -E '^[0-9]{4}-' | head -1)
eq "backup: snapshot dir mode 700" 700 "$(mode $BK/$SN)"
[[ -f $BK/$SN/work/projects/-w/a/w1.jsonl || -f $BK/$SN/work/projects/-w-a/w1.jsonl ]] && [[ -f $BK/$SN/work/claude-code-sessions/$W/$O/local_w1.json ]] \
  && ok "backup: default account files" || bad "backup: default account files" "projects + sessions" "$(find $BK/$SN -type f 2>&1)"
[[ -f $BK/$SN/personal/projects/-p-b/p1.jsonl && -f $BK/$SN/personal/claude-code-sessions/$U/$O/local_p1.json ]] \
  && ok "backup: profile files" || bad "backup: profile files" "projects + sessions" "$(find $BK/$SN -type f 2>&1)"
eq "backup: bindings and default-name saved" "bindings default-name" "$(ls $BK/$SN/cca | tr '\n' ' ' | sed 's/ $//')"
[[ -d $BK/.lock ]] && bad "backup: lock released" "no .lock" ".lock left" || ok "backup: lock released"
[[ -s $BK/backup.log ]] && ok "backup: log line written" || bad "backup: log line written" "backup.log" "missing"
out=$(run "$CTX"$'\n''cca backup --quiet'); eq "backup --quiet prints nothing" "" "$out"
mkdir $BK/.lock
out=$(run "$CTX"$'\n''cca backup'); no "backup refuses while locked" $?
touch -t 200001010000 $BK/.lock
out=$(run "$CTX"$'\n''cca backup --quiet'); yes "backup ignores a stale lock" $?
rm -rf $BK
for i in 1 2 3; do run "$CTX"$'\n''CCA_BACKUP_KEEP=2 cca backup --quiet; sleep 1' >/dev/null; done
eq "backup keeps only the newest 2" 2 "$(ls $BK | grep -cE '^[0-9]{4}-')"
eq "backup list: newest first" "$(ls $BK | grep -E '^[0-9]{4}-' | sort -r)" "$(run 'cca backup list')"
out=$(run 'cca backup nope'); no "backup: bad argument refused" $?

# 18. restore
rm -rf $BK $T/trash
SD=$A/desktop/personal/claude-code-sessions/$U/$O
PP=$A/profiles/personal/projects/-p-b
print -r -- '{"sessionId":"local_p2"}' > $SD/local_p2.json
run "$CTX"$'\n''cca backup --quiet' >/dev/null
# lose one session and transcript; change another session (must not be overwritten)
rm -f $SD/local_p1.json $PP/p1.jsonl
print -r -- changed > $SD/local_p2.json
print -r -- gone > $SD/local_p9.json
print -r -- 'xxxxxxxxxxxxx' > $SD/deleted_p9
print -r -- 'xxxxxxxxxxxxx' > $SD/deleted_nomatch
out=$(run "$CTX"$'\n''cca restore personal'); rc=$?
yes "restore exits 0" $rc
has "restore: counts" "1 sessions, 1 transcripts, 1 deleted marks" "$out"
[[ -f $SD/local_p1.json && -f $PP/p1.jsonl ]] && ok "restore: missing session and transcript copied" || bad "restore: missing session and transcript copied" "both back" "missing"
eq "restore: existing changed file not overwritten" changed "$(<$SD/local_p2.json)"
[[ ! -e $SD/deleted_p9 && -e $SD/deleted_nomatch ]] && ok "restore: matching tombstone gone, unmatched kept" || bad "restore: matching tombstone gone, unmatched kept" "p9 gone, nomatch kept" "$(ls $SD)"
eq "restore: tombstone is in the Trash" 1 "$(ls $T/trash | wc -l | tr -d ' ')"
rm -f $SD/local_p1.json
out=$(run "$CTX"$'\n''cca restore personal 1999-01-01_000000'); no "restore: unknown snapshot refused" $?
out=$(run "$CTX"$'\n''cca restore nope'); no "restore: unknown account refused" $?
[[ ! -e $SD/local_p1.json ]] && ok "restore: refused calls change nothing" || bad "restore: refused calls change nothing" "nothing copied" "copied"
SNAP1=$(ls $BK | grep -E '^[0-9]{4}-' | sort | head -1)
rm -f $PP/p1.jsonl; print -r -- xxxxxxxxxxxxx > $SD/deleted_p9; print -r -- gone > $SD/local_p9.json
out=$(run "$CTX"$'\n''cca restore personal --dry-run'); yes "restore dry run exits 0" $?
has "restore dry run: reports session, transcript, tombstone" "1 sessions, 1 transcripts, 1 deleted marks to move" "$out"
[[ ! -e $SD/local_p1.json && -e $SD/deleted_p9 ]] && ok "restore dry run: changes nothing" || bad "restore dry run: changes nothing" "nothing" "changed"
out=$(run "$CTX"$'\n'"cca restore personal $SNAP1"); yes "restore: named snapshot works" $?
[[ -f $SD/local_p1.json ]] && ok "restore: named snapshot brought the session back" || bad "restore: named snapshot brought the session back" "copied" "missing"
rm -f $SD/local_p1.json
out=$(run "$CTX"$'\n''ps() { print -r -- " 9 /Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=$CCA_HOME/desktop/personal"; }; cca restore personal'); rc=$?
no "restore: refuses while its app is open" $rc
[[ ! -e $SD/local_p1.json ]] && ok "restore: open app, nothing copied" || bad "restore: open app, nothing copied" "nothing" "copied"
out=$(run "$CTX"$'\n''ps() { print -r -- " 8 /Applications/Claude.app/Contents/MacOS/Claude"; }; cca restore work'); no "restore: default refused while the main app is open" $?

# restore from the main app by accountUuid, no snapshot needed
rm -rf $BK $A/desktop/personal $A/profiles/personal/projects
mkdir -p "$MAD/claude-code-sessions/$U/$O" $H/.claude/projects/-w-p/$C1/subagents
print -r -- "{\"sessionId\":\"local_m1\",\"cliSessionId\":\"$C1\"}" > "$MAD/claude-code-sessions/$U/$O/local_m1.json"
print -r -- t1 > $H/.claude/projects/-w-p/$C1.jsonl
print -r -- s > $H/.claude/projects/-w-p/$C1/subagents/a.jsonl
out=$(run "$CTX"$'\n''cca restore personal'); rc=$?
yes "restore from main app exits 0" $rc
has "restore from main app: counts" "1 sessions, 1 transcripts, 0 deleted marks" "$out"
[[ -f $A/desktop/personal/claude-code-sessions/$U/$O/local_m1.json && -f $A/profiles/personal/projects/-w-p/$C1.jsonl && -f $A/profiles/personal/projects/-w-p/$C1/subagents/a.jsonl ]] \
  && ok "restore from main app: session, transcript, subagents copied" || bad "restore from main app: session, transcript, subagents copied" "copied" "$(find $A/desktop $A/profiles/personal -type f 2>&1)"
eq "restore from main app: main app untouched" 1 "$(ls "$MAD/claude-code-sessions/$U/$O" | wc -l | tr -d ' ')"

# 19. autobackup
rm -rf $LA $T/launchctl.log
out=$(run "$CTX"$'\n''cca autobackup on'); rc=$?
yes "autobackup on exits 0" $rc
PL=$LA/dev.cca.backup.plist
[[ -f $PL ]] && ok "autobackup on: plist written" || bad "autobackup on: plist written" "$PL" "missing"
has "autobackup plist: runs the backup" "source $A/cca.zsh &amp;&amp; cca backup --quiet" "$(<$PL)"
has "autobackup plist: 13:00" "<key>Hour</key><integer>13</integer>" "$(<$PL)"
has "autobackup plist: log file" "$A/backups/autobackup.log" "$(<$PL)"
plutil -lint $PL >/dev/null 2>&1; yes "autobackup plist is valid" $?
has "autobackup on: bootstrap called" "LAUNCHCTL bootstrap gui/$(id -u) $PL" "$(<$T/launchctl.log)"
has "autobackup status: on" "Autobackup: on" "$(run "$CTX"$'\n''cca autobackup status')"
out=$(run "$CTX"$'\n''cca autobackup off'); rc=$?
yes "autobackup off exits 0" $rc
[[ ! -e $PL ]] && ok "autobackup off: plist removed" || bad "autobackup off: plist removed" "gone" "still there"
has "autobackup off: bootout called" "LAUNCHCTL bootout gui/$(id -u) $PL" "$(<$T/launchctl.log)"
has "autobackup status: off" "Autobackup: off" "$(run "$CTX"$'\n''cca autobackup status')"
out=$(run "$CTX"$'\n''cca autobackup maybe'); no "autobackup: bad argument refused" $?

# 20. remove and login back up first
rm -rf $BK
out=$(run "$CTX"$'\n''cca remove personal')
eq "remove triggers a backup" 1 "$(ls $BK | grep -cE '^[0-9]{4}-')"
rm -rf $BK
prof extra
out=$(run "$CTX"$'\n''cca login extra')
eq "login triggers a backup" 1 "$(ls $BK | grep -cE '^[0-9]{4}-')"

print -r -- "$pass passed, $fail failed"
(( fail == 0 ))
