# cca — switch Claude Code between accounts.
#
# Each account has its own config folder (CLAUDE_CONFIG_DIR), so each keeps
# its own login. The default folder ~/.claude stays as one account; the others
# live in ~/.claude-accounts/profiles/<name>. settings.json, CLAUDE.md, skills
# and plugins are shared with ~/.claude through symlinks.
#
# Which account `claude` uses, first match wins:
#   1. `cca use <name>` in this terminal
#   2. a folder bound with `cca bind <name>` (that folder or a parent)
#   3. the default account (~/.claude)
#
# The Claude desktop app works the same way: `cca app <name> [color]` makes a
# "Claude <Name>" launcher that opens the app with its own data folder
# (--user-data-dir), so each account stays signed in to the app at once.
#
# Load from ~/.zshrc:  source ~/.claude-accounts/cca.zsh

: ${CCA_HOME:=$HOME/.claude-accounts}
: ${CCA_CLAUDE_APP:=/Applications/Claude.app}
: ${CCA_MAIN_DIR:=$HOME/.claude}
: ${CCA_MAIN_JSON:=$HOME/.claude.json}
: ${CCA_MAIN_APP_DATA:="$HOME/Library/Application Support/Claude"}
: ${CCA_LAUNCH_AGENTS:=$HOME/Library/LaunchAgents}
typeset -ga CCA_SHARED=(settings.json CLAUDE.md skills plugins agents commands output-styles keybindings.json)

# Remember which file this shell loaded and when it changed, so `cca` can
# reload itself after an update instead of running old code.
typeset -g CCA_SCRIPT=${${(%):-%x}:A}
zmodload -F zsh/stat b:zstat 2>/dev/null
typeset -g CCA_LOADED=$(zstat +mtime -- $CCA_SCRIPT 2>/dev/null)

_cca_err() { print -ru2 -- "cca: $*" }

_cca_valid() { [[ $1 =~ '^[a-z0-9][a-z0-9_-]*$' ]] }

_cca_default_name() {
  local n
  [[ -r $CCA_HOME/default-name ]] && n=$(<$CCA_HOME/default-name)
  print -r -- ${n:-default}
}

_cca_exists() {
  _cca_valid "$1" && [[ $1 == "$(_cca_default_name)" || -d $CCA_HOME/profiles/$1 ]]
}

# Prints the account's config folder; prints nothing for the default account.
_cca_dir() {
  _cca_exists "$1" || return 1
  [[ $1 == "$(_cca_default_name)" ]] || print -r -- $CCA_HOME/profiles/$1
}

_cca_profiles() {
  emulate -L zsh
  local d
  _cca_default_name
  for d in $CCA_HOME/profiles/*(N/); do print -r -- ${d:t}; done
}

# Prints "name<TAB>folder" for the closest bound folder at or above $1.
_cca_bound() {
  emulate -L zsh
  local dir=${1:A} f=$CCA_HOME/bindings p n best bestp
  [[ -r $f ]] || return 1
  while IFS=$'\t' read -r p n; do
    [[ -n $p && ( $dir == "$p" || $dir == "$p"/* ) ]] || continue
    (( ${#p} > ${#bestp} )) && { best=$n; bestp=$p }
  done < $f
  [[ -n $best ]] && print -r -- "$best"$'\t'"$bestp"
}

# Prints "name<TAB>reason" for the account `claude` uses in this folder.
_cca_resolve() {
  emulate -L zsh
  local hit
  if [[ -n $CCA_ACCOUNT ]]; then
    print -r -- "$CCA_ACCOUNT"$'\t'"set in this terminal"
  elif hit=$(_cca_bound $PWD); then
    print -r -- "${hit%%$'\t'*}"$'\t'"folder ${hit#*$'\t'}"
  else
    print -r -- "$(_cca_default_name)"$'\t'"default"
  fi
}

# Runs a command with the account's config folder.
_cca_exec() {
  local dir
  dir=$(_cca_dir "$1") || { _cca_err "no account '$1'. See: cca list"; return 1 }
  shift
  if [[ -n $dir ]]; then
    env CLAUDE_CONFIG_DIR=$dir "$@"
  else
    env -u CLAUDE_CONFIG_DIR "$@"
  fi
}

_cca_link_shared() {
  emulate -L zsh
  local item
  for item in $CCA_SHARED; do
    [[ -e $CCA_MAIN_DIR/$item && ! -e $1/$item && ! -L $1/$item ]] && ln -s $CCA_MAIN_DIR/$item $1/$item
  done
  return 0
}

# A new account starts with the same MCP servers and theme as the default one.
_cca_seed_config() {
  [[ -e $1/.claude.json || ! -r $CCA_MAIN_JSON ]] && return 0
  (( $+commands[jq] )) || return 0
  ( umask 077
    jq '{mcpServers: (.mcpServers // {})} + (if .theme then {theme: .theme} else {} end)' \
      $CCA_MAIN_JSON > $1/.claude.json ) || rm -f $1/.claude.json
}

# Makes the config folder for a new account, without logging in.
_cca_create() {
  emulate -L zsh
  local dir=$CCA_HOME/profiles/$1
  mkdir -p $dir && chmod 700 $CCA_HOME $CCA_HOME/profiles $dir || return 1
  _cca_link_shared $dir
  _cca_seed_config $dir
}

_cca_add() {
  emulate -L zsh
  local name=$1
  if ! _cca_valid "$name"; then
    _cca_err "usage: cca add <name> [--email you@example.com] [--sso]  (name: a-z, 0-9, - and _)"
    return 1
  fi
  if _cca_exists $name; then
    _cca_err "account '$name' already exists. To log in again: cca login $name"
    return 1
  fi
  shift
  _cca_create $name || return 1
  print -r -- "Created account '$name'."
  _cca_login $name "$@"
}

_cca_login() {
  emulate -L zsh
  local name=$1
  if ! _cca_exists "$name"; then
    _cca_err "usage: cca login <name> [--email you@example.com] [--sso]"
    _cca_err "accounts: ${(j:, :)${(f)"$(_cca_profiles)"}}"
    return 1
  fi
  shift
  local dir=$(_cca_dir $name)
  [[ -n $dir ]] && _cca_link_shared $dir
  _cca_backup --quiet >/dev/null 2>&1 || :
  print -r -- "Signing in '$name'. If the browser is signed in to another Claude account, switch it there first."
  _cca_exec $name claude auth login "$@"
}

_cca_use() {
  emulate -L zsh
  case $1 in
    '')
      if [[ -n $CCA_ACCOUNT ]]; then
        print -r -- "This terminal uses: $CCA_ACCOUNT  (cca use - to stop)"
      else
        print -r -- "This terminal follows folder bindings. Set one with: cca use <name>"
      fi ;;
    -|off)
      unset CCA_ACCOUNT
      print -r -- "This terminal follows folder bindings again." ;;
    *)
      _cca_exists "$1" || { _cca_err "no account '$1'. See: cca list"; return 1 }
      typeset -g CCA_ACCOUNT=$1
      print -r -- "This terminal now uses: $1" ;;
  esac
}

# Removes the binding on exactly folder $1. Returns 1 if there was none.
_cca_drop_binding() {
  emulate -L zsh
  local f=$CCA_HOME/bindings line found=0
  local -a keep
  [[ -r $f ]] || return 1
  for line in "${(@f)$(<$f)}"; do
    [[ -z $line ]] && continue
    if [[ ${line%%$'\t'*} == "$1" ]]; then found=1; else keep+=($line); fi
  done
  (( found )) || return 1
  if (( $#keep )); then print -rl -- $keep > $f; else : > $f; fi
}

_cca_bind() {
  emulate -L zsh
  local name=$1 dir=${2:-$PWD}
  [[ -n $name ]] || { _cca_err "usage: cca bind <name> [folder]"; return 1 }
  _cca_exists "$name" || { _cca_err "no account '$name'. See: cca list"; return 1 }
  [[ -d $dir ]] || { _cca_err "not a folder: $dir"; return 1 }
  dir=${dir:A}
  mkdir -p $CCA_HOME
  _cca_drop_binding $dir
  print -r -- "$dir"$'\t'"$name" >> $CCA_HOME/bindings
  print -r -- "$dir and its subfolders now use: $name"
}

_cca_unbind() {
  emulate -L zsh
  local dir=${${1:-$PWD}:A} hit
  if _cca_drop_binding $dir; then
    print -r -- "Removed the binding on $dir"
  elif hit=$(_cca_bound $dir); then
    _cca_err "$dir has no binding of its own; it follows ${hit#*$'\t'} (${hit%%$'\t'*})"
    return 1
  else
    _cca_err "no binding on $dir"
    return 1
  fi
}

_cca_run() {
  emulate -L zsh
  local name=$1
  [[ -n $name ]] || { _cca_err "usage: cca run <name> [claude args...]"; return 1 }
  shift
  _cca_exec $name claude "$@"
}

# Prints the Claude app data folder for an account; nothing for the default account.
_cca_app_data() {
  _cca_exists "$1" || return 1
  [[ $1 == "$(_cca_default_name)" ]] || print -r -- $CCA_HOME/desktop/$1
}

# Prints the PID of the Claude app already open for an account.
_cca_app_pid() {
  emulate -L zsh
  local data line pid args bin=$CCA_CLAUDE_APP/Contents/MacOS/Claude
  data=$(_cca_app_data "$1") || return 1
  for line in "${(@f)$(ps -axww -o pid=,args=)}"; do
    read -r pid args <<< $line
    [[ $args == "$bin" || $args == "$bin "* ]] || continue
    if [[ -z $data ]]; then
      [[ $args == *--user-data-dir=* ]] && continue
    else
      [[ "$args " == *" --user-data-dir=$data "* ]] || continue
    fi
    print -r -- $pid
    return 0
  done
  return 1
}

_cca_front() {
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $1) to true" >/dev/null 2>&1
}

# Opens the Claude app for an account, or brings it to the front if it is open.
# Never starts a second copy on the same data folder.
_cca_open() {
  emulate -L zsh
  local name=$1 pid data
  if ! _cca_exists "$name"; then
    _cca_err "usage: cca open <name>. Accounts: ${(j:, :)${(f)"$(_cca_profiles)"}}"
    return 1
  fi
  if pid=$(_cca_app_pid $name); then
    _cca_front $pid || _cca_err "could not bring '$name' to the front. Allow it in System Settings > Privacy & Security > Automation."
    return
  fi
  data=$(_cca_app_data $name)
  if [[ -z $data ]]; then
    open -n -a $CCA_CLAUDE_APP
  else
    mkdir -p $data && chmod 700 $CCA_HOME/desktop $data || return 1
    open -n -a $CCA_CLAUDE_APP --env CLAUDE_CONFIG_DIR=$CCA_HOME/profiles/$name --args --user-data-dir=$data
  fi
}

# Colours `cca app` can tint the launcher icon with.
typeset -ga _CCA_COLORS=(red orange yellow green teal blue purple pink gray)

# Recolours an .icns: _cca_tint <src.icns> <dest.icns> <color>. Returns non-zero on any failure.
_cca_tint() {
  emulate -L zsh
  local src=$1 dest=$2 color=$3 tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/cca-tint.XXXXXX") || return 1
  {
    iconutil -c iconset -o $tmp/in.iconset $src >/dev/null 2>&1 || return 1
    osascript -l JavaScript - $tmp/in.iconset $color >/dev/null 2>&1 <<'JS' || return 1
ObjC.import('Cocoa');
ObjC.import('CoreImage');
function run(argv) {
  var dir = argv[0], color = argv[1];
  var hues = {red: 0, orange: 30, yellow: 50, green: 140, teal: 178, blue: 215, purple: 275, pink: 330};
  var fm = $.NSFileManager.defaultManager;
  var names = ObjC.deepUnwrap(fm.contentsOfDirectoryAtPathError(dir, $()));
  var files = names.filter(function (n) { return /\.png$/.test(n); });
  if (!files.length) throw new Error('no png');
  var widths = {}, big = files[0];
  files.forEach(function (n) {
    widths[n] = $.NSBitmapImageRep.imageRepWithContentsOfFile(dir + '/' + n).pixelsWide;
    if (widths[n] > widths[big]) big = n;
  });
  // Measure the hue of the plain tile area of the largest icon.
  var rep = $.NSBitmapImageRep.imageRepWithContentsOfFile(dir + '/' + big);
  var c = rep.colorAtXY(Math.floor(rep.pixelsWide * 0.5), Math.floor(rep.pixelsHigh * 0.12))
             .colorUsingColorSpace($.NSColorSpace.sRGBColorSpace);
  var tile = c.hueComponent * 360;
  var sat = 1.3, bright = 0;
  if (color === 'gray') sat = 0;
  if (color === 'orange') { sat = 2.0; bright = 0.08; }
  function tint(img, angle) {
    var f = $.CIFilter.filterWithName('CIHueAdjust');
    f.setValueForKey(img, 'inputImage');
    f.setValueForKey(angle, 'inputAngle');
    var g = $.CIFilter.filterWithName('CIColorControls');
    g.setValueForKey(f.valueForKey('outputImage'), 'inputImage');
    g.setValueForKey(sat, 'inputSaturation');
    g.setValueForKey(bright, 'inputBrightness');
    return g.valueForKey('outputImage');
  }
  // CIHueAdjust turns the colour in YIQ space, not HSV: positive angles raise the hue,
  // but the result drifts. Adjust the angle on the tile colour until its hue hits the target.
  var angle = 0;
  if (color !== 'gray') {
    var px = Math.floor(rep.pixelsWide * 0.5), py = Math.floor(rep.pixelsHigh * 0.88);
    var probe = $.CIImage.imageWithContentsOfURL($.NSURL.fileURLWithPath(dir + '/' + big))
                  .imageByCroppingToRect($.CGRectMake(px, py, 1, 1));
    angle = (hues[color] - tile) * Math.PI / 180;
    var best = angle, bestErr = 999;
    for (var i = 0; i < 12; i++) {
      var pr = $.NSBitmapImageRep.alloc.initWithCIImage(tint(probe, angle));
      var h = pr.colorAtXY(0, 0).colorUsingColorSpace($.NSColorSpace.sRGBColorSpace).hueComponent * 360;
      var d = hues[color] - h;
      if (d > 180) d -= 360;
      if (d < -180) d += 360;
      if (Math.abs(d) < bestErr) { bestErr = Math.abs(d); best = angle; }
      if (bestErr < 1) break;
      angle += d * Math.PI / 180 / (1 + i / 3);
    }
    angle = best;
  }
  files.forEach(function (n) {
    var img = $.CIImage.imageWithContentsOfURL($.NSURL.fileURLWithPath(dir + '/' + n));
    var out = $.NSBitmapImageRep.alloc.initWithCIImage(tint(img, angle));
    var png = out.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $({}));
    if (!png.writeToFileAtomically(dir + '/' + n, true)) throw new Error('write failed');
  });
  return '';
}
JS
    iconutil -c icns -o $dest $tmp/in.iconset >/dev/null 2>&1 || return 1
  } always {
    rm -rf $tmp
  }
}

# Makes "~/Applications/Claude <Name>.app", a launcher for `cca open <name>`.
_cca_app() {
  emulate -L zsh
  local name=$1 color=$2
  if ! _cca_valid "$name"; then
    _cca_err "usage: cca app <name> [color]. Colors: ${(j:, :)_CCA_COLORS}"
    return 1
  fi
  if [[ -n $color && ${_CCA_COLORS[(Ie)$color]} -eq 0 ]]; then
    _cca_err "unknown color '$color'. Colors: ${(j:, :)_CCA_COLORS}"
    return 1
  fi
  local dest="$HOME/Applications/Claude ${(C)name}.app"
  local res=$dest/Contents/Resources out
  local icon=$(defaults read $CCA_CLAUDE_APP/Contents/Info CFBundleIconFile 2>/dev/null)
  if [[ -e $dest && ! -e $res/cca-account ]]; then
    _cca_err "$dest exists and was not made by cca, so it was left alone"
    return 1
  fi
  # No colour given: keep the one saved in the existing launcher.
  [[ -z $color && -r $res/cca-color ]] && color=$(<$res/cca-color)
  [[ ${_CCA_COLORS[(Ie)$color]} -eq 0 ]] && color=
  _cca_exists $name || _cca_create $name || return 1
  rm -rf $dest
  mkdir -p $HOME/Applications
  out=$(osacompile -o $dest -e "do shell script \"/bin/zsh -f -c 'source $CCA_HOME/cca.zsh && cca open $name'\"" 2>&1) \
    || { _cca_err "osacompile failed: $out"; return 1 }
  # Show the Claude icon instead of the script icon.
  if [[ -n $icon ]]; then
    cp $CCA_CLAUDE_APP/Contents/Resources/${icon%.icns}.icns $res/applet.icns
    if [[ -n $color ]]; then
      if _cca_tint $CCA_CLAUDE_APP/Contents/Resources/${icon%.icns}.icns $res/applet.tmp.icns $color; then
        mv -f $res/applet.tmp.icns $res/applet.icns
      else
        rm -f $res/applet.tmp.icns
        print -u2 -r -- "cca: could not tint the icon $color, kept the plain icon"
        color=
      fi
    fi
    rm -f $res/Assets.car
    plutil -remove CFBundleIconName $dest/Contents/Info.plist 2>/dev/null
  fi
  print -r -- $name > $res/cca-account
  [[ -n $color ]] && print -r -- $color > $res/cca-color
  codesign --force --sign - $dest 2>/dev/null
  touch $dest
  # Make Finder and the Dock show the new icon now, not a cached one.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f $dest 2>/dev/null
  print -r -- "Made: $dest"
  if [[ $name != "$(_cca_default_name)" && ! -d $CCA_HOME/desktop/$name ]]; then
    print -r -- "First sign-in: quit every Claude window (Cmd+Q), open 'Claude ${(C)name}', sign in, then reopen the others."
  fi
}

# Moves a file or folder to the Trash, so a removal can be undone.
_cca_trash() {
  if [[ -n $CCA_TRASH ]]; then
    mkdir -p $CCA_TRASH && mv $1 $CCA_TRASH/${1:t}.$(date +%s).$RANDOM
  elif [[ -x /usr/bin/trash ]]; then
    /usr/bin/trash $1
  else
    mv $1 $HOME/.Trash/${1:t}.$(date +%s).$RANDOM
  fi
}

# Drops every folder binding that points to account $1.
_cca_drop_account_bindings() {
  emulate -L zsh
  local f=$CCA_HOME/bindings line
  local -a keep
  [[ -r $f ]] || return 0
  for line in "${(@f)$(<$f)}"; do
    [[ -z $line || ${line#*$'\t'} == "$1" ]] || keep+=($line)
  done
  if (( $#keep )); then print -rl -- $keep > $f; else : > $f; fi
}

# Removes an account: logs it out, drops its folder bindings and moves its
# config folder, Claude app data and launcher to the Trash. The default
# account keeps ~/.claude; only its login and launcher go.
_cca_remove() {
  emulate -L zsh
  local name=$1 dir data pid default=$(_cca_default_name)
  local app="$HOME/Applications/Claude ${(C)name}.app"
  if ! _cca_exists "$name"; then
    _cca_err "usage: cca remove <name>. Accounts: ${(j:, :)${(f)"$(_cca_profiles)"}}"
    return 1
  fi
  if [[ $name != "$default" ]] && pid=$(_cca_app_pid $name); then
    _cca_err "the Claude app for '$name' is open (PID $pid). Quit it first (Cmd+Q)."
    return 1
  fi
  _cca_backup --quiet >/dev/null 2>&1 || :
  dir=$(_cca_dir $name)
  data=$(_cca_app_data $name)
  _cca_exec $name claude auth logout >/dev/null 2>&1
  _cca_drop_account_bindings $name
  [[ -e $app/Contents/Resources/cca-account ]] && _cca_trash $app
  [[ -n $data && -d $data ]] && _cca_trash $data
  [[ -n $dir && -d $dir ]] && _cca_trash $dir
  [[ $CCA_ACCOUNT == "$name" ]] && unset CCA_ACCOUNT
  if [[ $name == "$default" ]]; then
    print -r -- "Logged out '$name' and moved its launcher to the Trash. ~/.claude and its settings stay."
  else
    print -r -- "Removed '$name': logged out and moved its folders and launcher to the Trash."
  fi
}

# Prints the Claude account UUID of a cca account: from its terminal login,
# or from the one account its Claude app copy has signed in with.
_cca_account_uuid() {
  emulate -L zsh
  local json=$CCA_HOME/profiles/$1/.claude.json id
  local -a dirs
  if [[ -r $json ]]; then
    if (( $+commands[jq] )); then
      id=$(jq -r '.oauthAccount.accountUuid // empty' $json 2>/dev/null)
    elif [[ $(<$json) =~ '"accountUuid"[[:space:]]*:[[:space:]]*"([0-9a-f-]+)"' ]]; then
      id=$match[1]
    fi
  fi
  if [[ -z $id ]]; then
    dirs=($CCA_HOME/desktop/$1/claude-code-sessions/*(N/:t))
    (( $#dirs == 1 )) && id=$dirs[1]
  fi
  [[ -n $id ]] && print -r -- $id
}

# Prints "transcripts<TAB>session lists": the two folders of an account that cca protects.
_cca_data_dirs() {
  emulate -L zsh
  _cca_exists "$1" || return 1
  if [[ $1 == "$(_cca_default_name)" ]]; then
    print -r -- $CCA_MAIN_DIR/projects$'\t'$CCA_MAIN_APP_DATA/claude-code-sessions
  else
    print -r -- $CCA_HOME/profiles/$1/projects$'\t'$CCA_HOME/desktop/$1/claude-code-sessions
  fi
}

# Prints the backup snapshot names, newest first.
_cca_snapshots() {
  emulate -L zsh
  setopt local_options extended_glob null_glob
  local d
  for d in $CCA_HOME/backups/[0-9](#c4)-[0-9](#c2)-[0-9](#c2)_[0-9](#c6)(-<->)#(/On); do
    print -r -- ${d:t}
  done
}

# Copies a folder with APFS clones (instant, no extra space); plain copy if cloning fails.
_cca_clone() {
  cp -Rcp $1 $2 2>/dev/null || { rm -rf "${2:?}"; cp -Rp $1 $2 }
}

# Prints one top-level string field of a JSON file.
_cca_json_field() {
  if (( $+commands[jq] )); then
    jq -r --arg k $2 '.[$k] // empty | strings' $1 2>/dev/null
  else
    python3 -I -c 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print(v if isinstance(v,str) else "")' $1 $2 2>/dev/null
  fi
}

# Copies file $1 to $2 only if $2 is missing. Returns 1 if it was there ($n_old counts those); counts a failed copy in $bad.
# With $dry set it copies nothing and collects the new session files in $would.
_cca_put() {
  if [[ -e $2 || -L $2 ]]; then n_old+=1; return 1; fi
  if [[ -n $dry ]]; then [[ ${2:t} == local_*.json ]] && would+=$2; return 0; fi
  mkdir -p ${2:h} && { cp -cp $1 $2 2>/dev/null || cp -p $1 $2 } && return 0
  _cca_err "could not copy $1"
  bad+=1
  return 1
}

# Copies the files under $1 that are missing under $2. Kind sess counts session
# files (to $n_sess), tr counts transcripts (to $n_tr). The caller declares the counters.
_cca_fill() {
  emulate -L zsh
  setopt local_options null_glob
  local f rel
  for f in $1/**/*(.DN); do
    rel=${f#$1/}
    [[ ${rel:t} == .DS_Store ]] && continue
    _cca_put $f $2/$rel || continue
    case $3 in
      sess) [[ ${rel:t} == local_*.json ]] && n_sess+=1 ;;
      tr)   [[ $rel == */*.jsonl && $rel != */*/* ]] && n_tr+=1 ;;
    esac
  done
  return 0
}

# Snapshots every account's transcripts and desktop session lists, plus bindings
# and the default name, into ~/.claude-accounts/backups/<time>. Keeps the newest
# $CCA_BACKUP_KEEP (30). `cca backup list` shows them.
_cca_backup() {
  emulate -L zsh
  setopt local_options extended_glob null_glob
  local quiet name d proj sess src snap stamp keep=${CCA_BACKUP_KEEP:-30}
  local root=$CCA_HOME/backups lock=$CCA_HOME/backups/.lock
  integer n=1 accts=0 dirs=0 bad=0 got
  local -a snaps old
  case $1 in
    list)    _cca_snapshots; return 0 ;;
    --quiet) quiet=1 ;;
    '')      ;;
    *)       _cca_err "usage: cca backup [--quiet]  or  cca backup list"; return 1 ;;
  esac
  [[ $keep == <-> ]] && (( keep >= 1 )) || keep=30
  mkdir -p $root && chmod 700 $CCA_HOME $root || return 1
  # One run at a time; a lock older than an hour is left over from a crash.
  if ! mkdir $lock 2>/dev/null; then
    [[ -n $(find $lock -maxdepth 0 -mmin +60 2>/dev/null) ]] && rmdir $lock 2>/dev/null
    mkdir $lock 2>/dev/null || { _cca_err "another backup is running"; return 1 }
  fi
  {
    stamp=$(date +%Y-%m-%d_%H%M%S) snap=$root/$stamp
    while [[ -e $snap ]]; do n+=1; snap=$root/$stamp-$n; done
    mkdir -m 700 $snap || { _cca_err "could not make $snap"; return 1 }
    for name in ${(f)"$(_cca_profiles)"}; do
      d=$(_cca_data_dirs $name) proj=${d%%$'\t'*} sess=${d#*$'\t'} got=0
      for src in $proj $sess; do
        [[ -d $src ]] || continue
        mkdir -p $snap/$name && _cca_clone $src $snap/$name/${src:t} || { _cca_err "could not copy $src"; bad+=1; continue }
        dirs+=1 got=1
      done
      accts+=got
    done
    mkdir -p $snap/cca
    for src in bindings default-name; do
      [[ -f $CCA_HOME/$src ]] && cp -p $CCA_HOME/$src $snap/cca/$src
    done
    snaps=(${(f)"$(_cca_snapshots)"})
    # A snapshot with a failed folder must not push out the good older ones.
    (( $#snaps > keep && bad == 0 )) && old=($snaps[$((keep + 1)),-1])
    for d in $old; do rm -rf "${root:?}/${d:?}"; done
    print -r -- "$(date '+%Y-%m-%d %H:%M:%S') ${snap:t} accounts=$accts folders=$dirs failed=$bad pruned=$#old" >> $root/backup.log
    [[ -n $quiet ]] || print -r -- "Backup ${snap:t}: $accts accounts, $dirs folders. Keeping the newest $keep."
    (( bad == 0 ))
  } always {
    rmdir $lock 2>/dev/null
  }
}

# Brings back an account's conversations: copies what is missing from a backup
# and, for a desktop copy, from the main Claude app. Never overwrites. Then moves
# the 'deleted' marks of sessions that are back to the Trash, so they show again.
# -n/--dry-run only reports. --account <uuid> overrides the account found by login.
# (`cca import` is the older name of this command.)
_cca_restore() {
  emulate -L zsh
  setopt local_options null_glob
  local name snapname pid d s proj sess src acct f id t slug tomb from dry
  local root=$CCA_HOME/backups
  local -a would pos
  integer n_sess=0 n_tr=0 n_tomb=0 n_old=0 t_none=0 bad=0
  while (( $# )); do
    case $1 in
      -n|--dry-run) dry=1 ;;
      --account)    acct=$2; shift ;;
      *)            pos+=$1 ;;
    esac
    shift
  done
  name=$pos[1] snapname=$pos[2]
  if ! _cca_exists "$name" || (( $#pos > 2 )); then
    _cca_err "usage: cca restore <name> [snapshot] [--dry-run] [--account <uuid>]. Accounts: ${(j:, :)${(f)"$(_cca_profiles)"}}"
    return 1
  fi
  if pid=$(_cca_app_pid $name); then
    _cca_err "the Claude app for '$name' is open (PID $pid). Quit it first (Cmd+Q)."
    return 1
  fi
  d=$(_cca_data_dirs $name) proj=${d%%$'\t'*} sess=${d#*$'\t'}
  if [[ -n $snapname ]]; then
    [[ $snapname =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}(-[0-9]+)?$' && -d $root/$snapname/$name ]] || {
      _cca_err "snapshot '$snapname' has nothing for '$name'. See: cca backup list"
      return 1
    }
  else
    for s in ${(f)"$(_cca_snapshots)"}; do
      [[ -d $root/$s/$name ]] && { snapname=$s; break }
    done
  fi
  if [[ $name != "$(_cca_default_name)" ]]; then
    [[ -n $acct ]] || acct=$(_cca_account_uuid $name)
    [[ $acct =~ '^[0-9A-Za-z-]+$' && -d $CCA_MAIN_APP_DATA/claude-code-sessions/$acct ]] && src=$CCA_MAIN_APP_DATA/claude-code-sessions/$acct
  fi
  if [[ -z $snapname && -z $src ]]; then
    if [[ $name == "$(_cca_default_name)" ]]; then
      _cca_err "no backup has '$name'. See: cca backup list"
      return 1
    fi
    _cca_err "no backup has '$name', and can't tell which sessions in the main Claude app belong to it."
    _cca_err "Log it in once (cca login $name), or pass --account <uuid>. Accounts there:"
    for f in $CCA_MAIN_APP_DATA/claude-code-sessions/*(/N); do
      would=($f/**/local_*.json(.N))
      _cca_err "  ${f:t}  $#would sessions"
    done
    return 1
  fi
  would=()
  if [[ -n $snapname ]]; then
    _cca_fill $root/$snapname/$name/projects $proj tr
    _cca_fill $root/$snapname/$name/claude-code-sessions $sess sess
  fi
  if [[ -n $src ]]; then
    if [[ -z $dry ]]; then
      mkdir -p $CCA_HOME/desktop/$name && chmod 700 $CCA_HOME/desktop $CCA_HOME/desktop/$name || return 1
    fi
    _cca_fill $src $sess/$acct sess
    # The transcripts those sessions point to (and their subagent folders).
    from=$CCA_MAIN_DIR/projects
    for f in $src/**/local_*.json(.N); do
      id=$(_cca_json_field $f cliSessionId)
      [[ $id =~ '^[A-Za-z0-9_-]+$' ]] || continue
      if [[ -z $(print -rl -- $from/*/$id.jsonl(N)) ]]; then t_none+=1; continue; fi
      for t in $from/*/$id.jsonl(N); do
        slug=${t:h:t}
        _cca_put $t $proj/$slug/$id.jsonl && n_tr+=1
        [[ -d ${t:r} ]] && _cca_fill ${t:r} $proj/$slug/$id none
      done
    done
  fi
  # A session that was logged out of has a 'deleted' mark next to it, which hides it.
  # (A dry run also looks at the sessions that would be copied.)
  for f in $sess/**/local_*.json(.N) $would; do
    id=${${f:t}#local_} id=${id%.json}
    tomb=${f:h}/deleted_$id
    [[ -f $tomb ]] || continue
    if [[ -n $dry ]]; then n_tomb+=1; continue; fi
    _cca_trash $tomb && n_tomb+=1 || bad+=1
  done
  local from_what="${snapname:-the main Claude app}${snapname:+${src:+ and the main Claude app}}"
  if [[ -n $dry ]]; then
    print -r -- "Would restore '$name' from $from_what: $n_sess sessions, $n_tr transcripts, $n_tomb deleted marks to move to the Trash. Nothing was changed."
  else
    print -r -- "Restored '$name' from $from_what: $n_sess sessions, $n_tr transcripts, $n_tomb deleted marks moved to the Trash. Nothing was overwritten."
  fi
  (( n_old )) && print -r -- "Already there, left as is: $n_old files."
  (( t_none )) && print -r -- "$t_none sessions have no transcript on this Mac; they will list but not open."
  (( bad == 0 ))
}

# launchctl, in one place so tests can replace it.
_cca_launchctl() { launchctl "$@" }

# Turns the daily backup (13:00, a launchd job) on or off.
_cca_autobackup() {
  emulate -L zsh
  local plist=$CCA_LAUNCH_AGENTS/dev.cca.backup.plist home=${CCA_HOME:A} cmd newest
  case $1 in
    on)
      mkdir -p $CCA_LAUNCH_AGENTS $home/backups && chmod 700 $home $home/backups || return 1
      cmd="source ${(q)home}/cca.zsh && cca backup --quiet"
      cmd=${cmd//&/&amp;} cmd=${cmd//</&lt;} home=${home//&/&amp;} home=${home//</&lt;}
      print -r -- '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.cca.backup</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string><string>-f</string><string>-c</string>
    <string>'$cmd'</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>CCA_HOME</key><string>'$home'</string></dict>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>'$home'/backups/autobackup.log</string>
  <key>StandardErrorPath</key><string>'$home'/backups/autobackup.log</string>
</dict>
</plist>' > $plist || return 1
      _cca_launchctl bootout gui/$UID $plist >/dev/null 2>&1
      _cca_launchctl bootstrap gui/$UID $plist || { _cca_err "launchctl could not load $plist"; return 1 }
      print -r -- "Autobackup on: every day at 13:00 (a missed run happens at the next wake)." ;;
    off)
      _cca_launchctl bootout gui/$UID $plist >/dev/null 2>&1
      rm -f $plist
      print -r -- "Autobackup off." ;;
    status)
      local -a snaps=(${(f)"$(_cca_snapshots)"})
      newest=$snaps[1]
      print -r -- "Autobackup: $([[ -f $plist ]] && print on || print off). Newest backup: ${newest:-none}" ;;
    *)
      _cca_err "usage: cca autobackup on|off|status"
      return 1 ;;
  esac
}

_cca_list() {
  emulate -L zsh
  local r=$(_cca_resolve) name dir json email org mark
  local here=${r%%$'\t'*}
  for name in ${(f)"$(_cca_profiles)"}; do
    dir=$(_cca_dir $name)
    json=${dir:+$dir/.claude.json}
    json=${json:-$CCA_MAIN_JSON}
    email= org=
    if [[ -r $json ]] && (( $+commands[jq] )); then
      email=$(jq -r '.oauthAccount.emailAddress // empty' $json 2>/dev/null)
      org=$(jq -r '.oauthAccount.organizationName // empty' $json 2>/dev/null)
    fi
    mark=' '
    [[ $name == "$here" ]] && mark='*'
    printf '%s %-14s %s\n' $mark $name "${email:-not logged in}${org:+  ($org)}"
  done
}

_cca_status() {
  emulate -L zsh
  local r=$(_cca_resolve) line
  print -r -- "Here: ${r%%$'\t'*}  (${r#*$'\t'})"
  print
  print -r -- "Accounts:"
  _cca_list
  if [[ -s $CCA_HOME/bindings ]]; then
    print
    print -r -- "Folders:"
    for line in "${(@f)$(<$CCA_HOME/bindings)}"; do
      [[ -n $line ]] && print -r -- "  ${line%%$'\t'*} -> ${line#*$'\t'}"
    done
  fi
}

_cca_help() {
  print -r -- "cca — switch Claude Code between accounts

  cca                        show the account used here, all accounts and bound folders
  cca add <name> [opts]      create an account and log in   (opts: --email you@x.com, --sso)
  cca login <name> [opts]    log in again (expired, or the wrong account)
  cca use <name>             use an account in this terminal   (cca use - to stop)
  cca bind <name> [folder]   always use an account in a folder and its subfolders
  cca unbind [folder]        remove a folder binding
  cca run <name> [args]      run claude once with an account
  cca list                   list accounts with their emails
  cca app <name> [color]     make a 'Claude <Name>' app in ~/Applications for that account
                             (colors: red orange yellow green teal blue purple pink gray)
  cca open <name>            open the Claude app for an account (or bring it to the front)
  cca remove <name>          log out an account; move its folders and launcher to the Trash
  cca backup [--quiet|list]  save every account's conversations (keeps the newest 30)
  cca restore <name> [snap] [-n] [--account <uuid>]
                             bring an account's conversations back (never overwrites; -n: dry run)
  cca autobackup on|off|status   a daily backup at 13:00

Order: cca use > folder binding > default account (~/.claude).
Set CCA_QUIET=1 to hide the line 'claude' prints about the account."
}

cca() {
  # Reload when the file changed since this shell loaded it (an update), or
  # when Claude Code's shell snapshot kept cca but dropped the _cca_* helpers.
  local src=${CCA_SCRIPT:-${CCA_HOME:-$HOME/.claude-accounts}/cca.zsh}
  local -a mtime
  zmodload -F zsh/stat b:zstat 2>/dev/null
  zstat -A mtime +mtime -- $src 2>/dev/null
  if (( ! $+functions[_cca_status] )) || [[ $mtime[1] != $CCA_LOADED ]]; then
    source $src
  fi
  emulate -L zsh
  local cmd=${1:-status}
  (( $# )) && shift
  case $cmd in
    status)         _cca_status ;;
    list|ls)        _cca_list ;;
    add)            _cca_add "$@" ;;
    login)          _cca_login "$@" ;;
    use)            _cca_use "$@" ;;
    bind)           _cca_bind "$@" ;;
    unbind)         _cca_unbind "$@" ;;
    run)            _cca_run "$@" ;;
    app)            _cca_app "$@" ;;
    open)           _cca_open "$@" ;;
    remove|rm)      _cca_remove "$@" ;;
    import)         _cca_restore "$@" ;;
    backup)         _cca_backup "$@" ;;
    restore)        _cca_restore "$@" ;;
    autobackup)     _cca_autobackup "$@" ;;
    help|-h|--help) _cca_help ;;
    *)              _cca_err "unknown command '$cmd'"; _cca_help; return 1 ;;
  esac
}

claude() {
  # Inside Claude Code, keep the account the parent session runs on.
  if [[ -n $CLAUDECODE ]]; then
    command claude "$@"
    return
  fi
  (( $+functions[_cca_resolve] )) || source ${CCA_HOME:-$HOME/.claude-accounts}/cca.zsh
  emulate -L zsh
  local r=$(_cca_resolve)
  local name=${r%%$'\t'*} why=${r#*$'\t'}
  if ! _cca_exists "$name"; then
    _cca_err "account '$name' ($why) does not exist. See: cca list"
    return 1
  fi
  [[ -t 2 && -z $CCA_QUIET ]] && print -ru2 -- $'\e[2m'"claude account: $name ($why)"$'\e[0m'
  _cca_exec $name claude "$@"
}

_cca_complete() {
  local -a cmds=(status list add login use bind unbind run app open remove backup restore autobackup help)
  if (( CURRENT == 2 )); then
    compadd -a cmds
  elif (( CURRENT == 3 )); then
    case $words[2] in
      login|use|bind|run|app|open|remove|restore) compadd -- ${(f)"$(_cca_profiles)"} ;;
      backup)             compadd -- list --quiet ;;
      autobackup)         compadd -- on off status ;;
      unbind)             _files -/ ;;
    esac
  elif (( CURRENT == 4 )) && [[ $words[2] == bind ]]; then
    _files -/
  elif (( CURRENT >= 4 )) && [[ $words[2] == restore ]]; then
    (( CURRENT == 4 )) && compadd -- ${(f)"$(_cca_snapshots)"}
    compadd -- --dry-run --account
  fi
}
# `if` so sourcing still succeeds without completion (the app launchers run zsh -f).
if (( $+functions[compdef] )); then compdef _cca_complete cca; fi
