# Behavioural tests for cca.ps1: runs real cca commands in a throwaway CCA_HOME
# and checks what they exit with and what they print. The counterpart of
# tests/run.sh, which covers the zsh side.
#
# Needs no Claude install and no account: every command here either fails on
# purpose, works without one, or runs against a stub `claude` the suite writes. Windows only, because cca.ps1 reaches for the
# Claude app and Task Scheduler. CI runs it on windows-latest under Windows
# PowerShell 5.1, the version cca.ps1 targets.
#
# Usage: powershell -NoProfile -File tests\run.ps1
# Keep this file to 5.1 syntax (no ??, ?. or ternaries) and plain ASCII.

# This suite runs commands that fail on purpose, and Windows PowerShell 5.1
# turns a native command's stderr into a NativeCommandError record. GitHub runs
# a `shell: powershell` step with $ErrorActionPreference = 'stop', so the first
# cca command that reported an error killed the whole run 88 assertions in, with
# no FAIL line and no count to show for it. `2>$null` hides such a record but
# does not stop 5.1 raising it, so the preference is the only lever. PowerShell
# 7 does not promote native stderr this way, which is why this bites on the 5.1
# runner and never locally. Assigning here shadows the caller's value for this
# script alone, so the step's own 'stop' is back the moment the script ends.
$ErrorActionPreference = 'Continue'

$repo = Split-Path -Parent $PSScriptRoot
$cca = Join-Path $repo 'cca.ps1'
$shim = Join-Path (Join-Path (Join-Path $repo 'desktop') 'main') 'cca-shim.ps1'
$pshost = (Get-Process -Id $PID).Path
$script:pass = 0
$script:fail = 0
$script:boxes = @()
$script:doc = $null

function ok($name) { "ok - $name"; $script:pass++ }
function bad($name, $want, $got) { "FAIL - ${name}: expected $want got $got"; $script:fail++ }
function eq($name, $want, $got) {
    if ($got -eq $want) { ok $name } else { bad $name "'$want'" "'$got'" }
}
function has($name, $needle, $text) {
    if ($text -and $text.Contains($needle)) { ok $name } else { bad $name "text containing '$needle'" "'$text'" }
}
function keys($label, $obj, $wanted) {
    $have = @($obj.PSObject.Properties.Name)
    foreach ($k in $wanted) {
        if ($have -contains $k) { ok "$label has $k" } else { bad "$label has $k" 'the key' 'missing' }
    }
}

# A throwaway home for one group of tests. Every CCA_* path is redirected, so a
# test never touches a real profile, the real Recycle Bin or the Start menu.
# cca.ps1 reads these once, when it is sourced, so the caller sources it again.
function newbox {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('cca-test-' + [Guid]::NewGuid().ToString('N'))
    $env:CCA_HOME = Join-Path $t 'accounts'
    $env:CCA_MAIN_DIR = Join-Path $t 'claude'
    $env:CCA_MAIN_JSON = Join-Path $t 'claude.json'
    $env:CCA_MAIN_APP_DATA = Join-Path $t 'appdata'
    $env:CCA_TRASH = Join-Path $t 'trash'
    $env:CCA_LAUNCHERS = Join-Path $t 'launchers'
    New-Item -ItemType Directory -Force -Path $env:CCA_HOME, $env:CCA_MAIN_DIR | Out-Null
    Remove-Variable -Name CCA_ACCOUNT -Scope Global -ErrorAction SilentlyContinue
    $script:boxes += $t
    $t
}

# Runs a cca command in this session, the way a user who sourced cca.ps1 in
# their profile does, and checks the exit status it leaves behind.
function code($name, $want, $block) {
    & $block 6>$null | Out-Null
    eq $name $want $LASTEXITCODE
}

# Runs one command through desktop/main/cca-shim.ps1 in a child host, the only
# path the desktop app ever uses, and the suite's only native invocation: the
# one place the NativeCommandError trap above can show up. The catch turns a
# surprise into a FAIL line instead of a dead run.
# Returns @{ Code; Out } with stdout only.
function shim($argv) {
    try {
        $out = & $pshost -NoProfile -File $shim @argv 2>$null
        return @{ Code = $LASTEXITCODE; Out = @($out) }
    } catch {
        return @{ Code = "threw: $($_.Exception.Message)"; Out = @() }
    }
}

# Puts a stub `claude` on PATH that prints what it was handed and exits with
# $env:CCA_STUB_EXIT, so the tests below can watch whose exit code survives.
# tests/run.sh stubs claude the same way on the zsh side.
function stubclaude($dir) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    # Windows resolves claude.cmd through PATHEXT; a developer running this on
    # macOS needs an executable file with no extension instead.
    Set-Content -LiteralPath (Join-Path $dir 'claude.cmd') -Encoding ASCII -Value @(
        '@echo off',
        'if "%CCA_STUB_EXIT%"=="" set CCA_STUB_EXIT=0',
        'echo CFG=%CLAUDE_CONFIG_DIR%',
        'echo ARGS=%*',
        'exit /b %CCA_STUB_EXIT%')
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
        $sh = Join-Path $dir 'claude'
        Set-Content -LiteralPath $sh -Encoding ASCII -Value @(
            '#!/bin/sh',
            'echo "CFG=$CLAUDE_CONFIG_DIR"',
            'echo "ARGS=$*"',
            'exit ${CCA_STUB_EXIT:-0}')
        & chmod +x $sh
    }
    $env:PATH = $dir + [IO.Path]::PathSeparator + $env:PATH
}

# Every assertion the desktop app's reading of `cca list --json` rests on.
# Leaves the parsed document in $script:doc.
function checkjson($label, $lines) {
    $script:doc = $null
    $text = (@($lines) -join "`n").Trim()
    eq "$label - one line on stdout" 1 @($lines).Count
    if (-not ($text.StartsWith('{') -and $text.EndsWith('}'))) {
        bad "$label - stdout is JSON and nothing else" 'text from { to }' "'$text'"
        return
    }
    ok "$label - stdout is JSON and nothing else"
    $parsed = $null
    try { $parsed = $text | ConvertFrom-Json } catch {
        bad "$label - parses as JSON" 'a document' $_.Exception.Message
        return
    }
    ok "$label - parses as JSON"
    keys "$label -" $parsed 'version', 'default', 'colors', 'autobackup', 'snapshots', 'accounts'
    # ConvertTo-Json turns a one-element array into a bare object, and the
    # renderer does accounts.map(), so these stay arrays whatever the count.
    foreach ($k in 'colors', 'snapshots', 'accounts') {
        has "$label - $k is a JSON array" ('"' + $k + '":[') $text
    }
    if ($parsed.accounts -is [array]) { ok "$label - accounts parses as an array" }
    else { bad "$label - accounts parses as an array" 'an array' $parsed.accounts.GetType().Name }
    keys "$label - account" (@($parsed.accounts)[0]) 'name', 'isDefault', 'email', 'org', 'loggedIn', 'color', 'app', 'running', 'folders'
    $script:doc = $parsed
}

"PowerShell $($PSVersionTable.PSVersion)"

# ---- exit codes, in one session ----------------------------------------
$box = newbox
. $cca

code 'cca help exits 0' 0 { cca help }
code 'cca (no args) exits 0' 0 { cca }
code 'cca list on an empty home exits 0' 0 { cca list }
code 'cca list --json exits 0' 0 { cca list --json }
code 'cca use with no name exits 0' 0 { cca use }
code 'cca backup exits 0' 0 { cca backup }
code 'cca backup list exits 0' 0 { cca backup list }
code 'cca autobackup status exits 0' 0 { cca autobackup status }
code 'cca bind exits 0' 0 { cca bind default $box }
code 'cca unbind exits 0' 0 { cca unbind $box }

code 'an unknown command exits non-zero' 1 { cca wat }
code 'cca import (not ported) exits non-zero' 1 { cca import foo }
code 'cca remove on an unknown account exits non-zero' 1 { cca remove nosuchacct }
code 'cca restore on an unknown account exits non-zero' 1 { cca restore nosuchacct }
code 'cca restore with no backup exits non-zero' 1 { cca restore default }
code 'cca restore on an unknown snapshot exits non-zero' 1 { cca restore default 9999-99-99_999999 }
code 'cca bind with no name exits non-zero' 1 { cca bind }
code 'cca bind on an unknown account exits non-zero' 1 { cca bind nosuchacct }
code 'cca bind on a missing folder exits non-zero' 1 { cca bind default (Join-Path $box 'nope') }
code 'cca use on an unknown account exits non-zero' 1 { cca use nosuchacct }
code 'cca unbind on an unbound folder exits non-zero' 1 { cca unbind $box }
code 'cca add with an invalid name exits non-zero' 1 { cca add 'Bad Name' }
code 'cca add on an existing account exits non-zero' 1 { cca add default }
code 'cca login on an unknown account exits non-zero' 1 { cca login nosuchacct }
code 'cca run with no name exits non-zero' 1 { cca run }
code 'cca autobackup with a bad argument exits non-zero' 1 { cca autobackup bogus }

# A failure must not stick to the next command in the same session.
code 'a failure first' 1 { cca wat }
code 'then a success is 0 again' 0 { cca list }

# ---- cca list --json, one account (a fresh home has the default) -------
$box = newbox
. $cca

checkjson 'json, one account' (cca list --json)
if ($script:doc) {
    eq 'json, one account - version is 1' 1 $script:doc.version
    eq 'json, one account - one account' 1 @($script:doc.accounts).Count
    eq 'json, one account - it is the default' $true @($script:doc.accounts)[0].isDefault
    eq 'json, one account - not logged in' $false @($script:doc.accounts)[0].loggedIn
    eq 'json, one account - default names it' @($script:doc.accounts)[0].name $script:doc.default
}

# ---- cca list --json, two accounts and one snapshot --------------------
$box = newbox
. $cca
New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path $env:CCA_HOME 'profiles') 'extra') | Out-Null
cca backup 6>$null | Out-Null

checkjson 'json, two accounts' (cca list --json)
if ($script:doc) {
    eq 'json, two accounts - two accounts' 2 @($script:doc.accounts).Count
    eq 'json, two accounts - one snapshot' 1 @($script:doc.snapshots).Count
    has 'json, two accounts - the new account is listed' 'extra' (@($script:doc.accounts).name -join ',')
}

# ---- through desktop/main/cca-shim.ps1, the app's own path -------------
$box = newbox
Copy-Item -LiteralPath $cca -Destination (Join-Path $env:CCA_HOME 'cca.ps1')

$r = shim @('help')
eq 'shim: cca help exits 0' 0 $r.Code
$r = shim @('list')
eq 'shim: cca list exits 0' 0 $r.Code
$r = shim @('wat')
eq 'shim: an unknown command exits non-zero' 1 $r.Code
$r = shim @('remove', 'nosuchacct')
eq 'shim: cca remove on an unknown account exits non-zero' 1 $r.Code
$r = shim @('restore', 'nosuchacct')
eq 'shim: cca restore on an unknown account exits non-zero' 1 $r.Code
$r = shim @('list', '--json')
eq 'shim: cca list --json exits 0' 0 $r.Code
checkjson 'shim json' $r.Out

# ---- whose exit code wins, against a stub claude ------------------------
# `cca run` hands back the exit code of the tool it ran, while the logout that
# `cca remove` runs on its way out has its code thrown away. Both are on
# purpose, and neither could be reached without a claude to run.
$box = newbox
. $cca
$oldpath = $env:PATH
stubclaude (Join-Path $box 'bin')
Copy-Item -LiteralPath $cca -Destination (Join-Path $env:CCA_HOME 'cca.ps1')
# Make the account where cca.ps1 itself looks for it, whatever it joins with.
$extra = Get-CcaDir 'extra'
New-Item -ItemType Directory -Force -Path $extra | Out-Null

$env:CCA_STUB_EXIT = '3'
code 'cca run hands back the exit code of the tool' 3 { cca run extra a b }
code 'and that code does not stick to the next command' 0 { cca list }
$env:CCA_STUB_EXIT = '0'
code 'cca run is 0 when the tool succeeds' 0 { cca run extra a b }

$seen = (cca run extra a b 6>$null) -join "`n"
has 'cca run points CLAUDE_CONFIG_DIR at the account' "CFG=$extra" $seen
has 'cca run passes the arguments through' 'ARGS=a b' $seen

$env:CCA_STUB_EXIT = '3'
$r = shim @('run', 'extra', 'x')
eq 'shim: cca run hands back the exit code of the tool' 3 $r.Code

code 'cca remove ignores a logout that fails' 0 { cca remove extra }
if (Test-Path -LiteralPath $extra) { bad 'cca remove moved the account out' 'the folder gone' 'still there' }
else { ok 'cca remove moved the account out' }

$env:PATH = $oldpath
Remove-Item Env:\CCA_STUB_EXIT -ErrorAction SilentlyContinue

foreach ($b in $script:boxes) { Remove-Item -LiteralPath $b -Recurse -Force -ErrorAction SilentlyContinue }

"$script:pass passed, $script:fail failed"
if ($script:fail) { exit 1 }
exit 0
