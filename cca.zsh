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
# The Claude desktop app works the same way: `cca app <name>` makes a
# "Claude <Name>" launcher that opens the app with its own data folder
# (--user-data-dir), so each account stays signed in to the app at once.
#
# Load from ~/.zshrc:  source ~/.claude-accounts/cca.zsh

: ${CCA_HOME:=$HOME/.claude-accounts}
: ${CCA_CLAUDE_APP:=/Applications/Claude.app}
: ${CCA_MAIN_DIR:=$HOME/.claude}
: ${CCA_MAIN_JSON:=$HOME/.claude.json}
typeset -ga CCA_SHARED=(settings.json CLAUDE.md skills plugins agents commands output-styles keybindings.json)

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

# Makes "~/Applications/Claude <Name>.app", a launcher for `cca open <name>`.
_cca_app() {
  emulate -L zsh
  local name=$1
  if ! _cca_valid "$name"; then
    _cca_err "usage: cca app <name>"
    return 1
  fi
  local dest="$HOME/Applications/Claude ${(C)name}.app"
  local res=$dest/Contents/Resources out
  local icon=$(defaults read $CCA_CLAUDE_APP/Contents/Info CFBundleIconFile 2>/dev/null)
  if [[ -e $dest && ! -e $res/cca-account ]]; then
    _cca_err "$dest exists and was not made by cca, so it was left alone"
    return 1
  fi
  _cca_exists $name || _cca_create $name || return 1
  rm -rf $dest
  mkdir -p $HOME/Applications
  out=$(osacompile -o $dest -e "do shell script \"/bin/zsh -f -c 'source $CCA_HOME/cca.zsh && cca open $name'\"" 2>&1) \
    || { _cca_err "osacompile failed: $out"; return 1 }
  # Show the Claude icon instead of the script icon.
  if [[ -n $icon ]]; then
    cp $CCA_CLAUDE_APP/Contents/Resources/${icon%.icns}.icns $res/applet.icns
    rm -f $res/Assets.car
    plutil -remove CFBundleIconName $dest/Contents/Info.plist 2>/dev/null
  fi
  print -r -- $name > $res/cca-account
  codesign --force --sign - $dest 2>/dev/null
  touch $dest
  print -r -- "Made: $dest"
  if [[ $name != "$(_cca_default_name)" ]]; then
    print -r -- "First sign-in: quit every Claude window (Cmd+Q), open 'Claude ${(C)name}', sign in, then reopen the others."
  fi
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
  cca app <name>             make a 'Claude <Name>' app in ~/Applications for that account
  cca open <name>            open the Claude app for an account (or bring it to the front)

Order: cca use > folder binding > default account (~/.claude).
Set CCA_QUIET=1 to hide the line 'claude' prints about the account."
}

cca() {
  # Claude Code's shell snapshot keeps cca but drops the _cca_* helpers.
  (( $+functions[_cca_status] )) || source ${CCA_HOME:-$HOME/.claude-accounts}/cca.zsh
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
  local -a cmds=(status list add login use bind unbind run app open help)
  if (( CURRENT == 2 )); then
    compadd -a cmds
  elif (( CURRENT == 3 )); then
    case $words[2] in
      login|use|bind|run|app|open) compadd -- ${(f)"$(_cca_profiles)"} ;;
      unbind)             _files -/ ;;
    esac
  elif (( CURRENT == 4 )) && [[ $words[2] == bind ]]; then
    _files -/
  fi
}
# `if` so sourcing still succeeds without completion (the app launchers run zsh -f).
if (( $+functions[compdef] )); then compdef _cca_complete cca; fi
