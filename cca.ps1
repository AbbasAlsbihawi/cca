# cca for Windows (PowerShell 5.1 or 7) - switch Claude Code between accounts.
#
# Each account has its own config folder (CLAUDE_CONFIG_DIR), so each keeps
# its own login. The default folder ~\.claude stays as one account; the others
# live in ~\.claude-accounts\profiles\<name>. settings.json, CLAUDE.md, skills
# and plugins are shared with ~\.claude (symlink, junction or hard link).
#
# Which account `claude` uses, first match wins:
#   1. `cca use <name>` in this terminal
#   2. a folder bound with `cca bind <name>` (that folder or a parent)
#   3. the default account (~\.claude)
#
# Load from your PowerShell profile:  . "$HOME\.claude-accounts\cca.ps1"

function Get-CcaEnv([string]$name, [string]$default) {
    $v = [Environment]::GetEnvironmentVariable($name)
    if ($v) { $v } else { $default }
}

$script:CCA_HOME     = Get-CcaEnv 'CCA_HOME' (Join-Path $HOME '.claude-accounts')
$script:CCA_MAIN_DIR = Get-CcaEnv 'CCA_MAIN_DIR' (Join-Path $HOME '.claude')
$script:CCA_MAIN_JSON = Get-CcaEnv 'CCA_MAIN_JSON' (Join-Path $HOME '.claude.json')
$script:CCA_MAIN_APP_DATA = Get-CcaEnv 'CCA_MAIN_APP_DATA' (Join-Path $env:APPDATA 'Claude')
$script:CCA_SHARED = @('settings.json', 'CLAUDE.md', 'skills', 'plugins', 'agents', 'commands', 'output-styles', 'keybindings.json')
$script:CCA_SCRIPT = $MyInvocation.MyCommand.Path

function Write-CcaErr([string]$msg) { [Console]::Error.WriteLine("cca: $msg") }

# Set by a command that failed; `cca` and `claude` turn it into $LASTEXITCODE on the
# way out. A PowerShell function returns its output stream, so a status cannot be
# returned without printing it, and `exit` would close the shell that dot-sourced
# this file. Write-CcaErr on its own stays a warning, the way cca.zsh prints some
# errors without returning 1.
$script:CCA_FAILED = $false

function Set-CcaFailed { $script:CCA_FAILED = $true }

# An error that fails the command: cca.zsh's `_cca_err "..."; return 1`.
function Write-CcaFail([string]$msg) { Write-CcaErr $msg; $script:CCA_FAILED = $true }

function Write-CcaFile([string]$path, [string]$text) {
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}

function Test-CcaValid([string]$name) { $name -cmatch '^[a-z0-9][a-z0-9_-]*$' }

function Get-CcaFullPath([string]$p) { [IO.Path]::GetFullPath($p).TrimEnd('\', '/') }

function Get-CcaDefaultName {
    $f = Join-Path $script:CCA_HOME 'default-name'
    $n = $null
    if (Test-Path -LiteralPath $f) { $n = (Get-Content -LiteralPath $f -Raw).Trim() }
    if ($n) { $n } else { 'default' }
}

function Test-CcaExists([string]$name) {
    (Test-CcaValid $name) -and ($name -ceq (Get-CcaDefaultName) -or (Test-Path -LiteralPath (Join-Path $script:CCA_HOME "profiles\$name") -PathType Container))
}

# Returns the account's config folder; $null for the default account.
function Get-CcaDir([string]$name) {
    if ($name -ceq (Get-CcaDefaultName)) { return $null }
    Join-Path $script:CCA_HOME "profiles\$name"
}

function Get-CcaProfiles {
    Get-CcaDefaultName
    $p = Join-Path $script:CCA_HOME 'profiles'
    if (Test-Path -LiteralPath $p) {
        Get-ChildItem -LiteralPath $p -Directory | Sort-Object Name | ForEach-Object { $_.Name }
    }
}

function Get-CcaBindings {
    $f = Join-Path $script:CCA_HOME 'bindings'
    if (Test-Path -LiteralPath $f) {
        foreach ($line in (Get-Content -LiteralPath $f)) {
            if (-not $line) { continue }
            $i = $line.IndexOf("`t")
            if ($i -lt 1) { continue }
            [pscustomobject]@{ Path = $line.Substring(0, $i); Name = $line.Substring($i + 1) }
        }
    }
}

function Save-CcaBindings($items) {
    $text = ''
    foreach ($b in @($items)) { $text += "$($b.Path)`t$($b.Name)`n" }
    New-Item -ItemType Directory -Force -Path $script:CCA_HOME | Out-Null
    Write-CcaFile (Join-Path $script:CCA_HOME 'bindings') $text
}

# The closest bound folder at or above $dir, or $null.
function Get-CcaBound([string]$dir) {
    $dir = Get-CcaFullPath $dir
    $best = $null
    foreach ($b in (Get-CcaBindings)) {
        $p = Get-CcaFullPath $b.Path
        if ($dir -ieq $p -or $dir.StartsWith($p + '\', [StringComparison]::OrdinalIgnoreCase)) {
            if (-not $best -or $p.Length -gt (Get-CcaFullPath $best.Path).Length) { $best = $b }
        }
    }
    $best
}

# The account `claude` uses in this folder: @{ Name; Why }.
function Resolve-CcaAccount {
    if ($global:CCA_ACCOUNT) {
        return [pscustomobject]@{ Name = $global:CCA_ACCOUNT; Why = 'set in this terminal' }
    }
    $hit = Get-CcaBound (Get-Location).ProviderPath
    if ($hit) { return [pscustomobject]@{ Name = $hit.Name; Why = "folder $($hit.Path)" } }
    [pscustomobject]@{ Name = (Get-CcaDefaultName); Why = 'default' }
}

# Runs a script block with the account's CLAUDE_CONFIG_DIR set, then puts the variable back.
function Invoke-CcaAs([string]$name, [scriptblock]$block) {
    if (-not (Test-CcaExists $name)) { Write-CcaFail "no account '$name'. See: cca list"; return }
    $old = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR')
    $dir = Get-CcaDir $name
    [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $dir)
    try { & $block } finally { [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $old) }
}

function Get-CcaClaudeExe {
    $c = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $c) { Write-CcaFail "the 'claude' command was not found. Install Claude Code first."; return $null }
    $c.Source
}

function Invoke-CcaClaude([string]$name, $claudeArgs) {
    $exe = Get-CcaClaudeExe
    if (-not $exe) { return }
    $block = { & $exe @claudeArgs }.GetNewClosure()
    Invoke-CcaAs $name $block
}

# Makes $link point at $target: symlink, else junction (folders), else hard link (files).
function New-CcaLink([string]$link, [string]$target) {
    $isDir = Test-Path -LiteralPath $target -PathType Container
    try { New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null; return $true } catch {}
    try {
        if ($isDir) { New-Item -ItemType Junction -Path $link -Target $target -ErrorAction Stop | Out-Null }
        else { New-Item -ItemType HardLink -Path $link -Target $target -ErrorAction Stop | Out-Null }
        return $true
    } catch { return $false }
}

function Sync-CcaShared([string]$dir) {
    foreach ($item in $script:CCA_SHARED) {
        $src = Join-Path $script:CCA_MAIN_DIR $item
        $dst = Join-Path $dir $item
        if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $dst) -and -not (Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue)) {
            if (-not (New-CcaLink $dst $src)) {
                Write-CcaErr "could not share $item (turn on Developer Mode in Windows settings to allow symlinks)"
            }
        }
    }
}

# A new account starts with the same MCP servers and theme as the default one.
function Initialize-CcaConfig([string]$dir) {
    $dst = Join-Path $dir '.claude.json'
    if ((Test-Path -LiteralPath $dst) -or -not (Test-Path -LiteralPath $script:CCA_MAIN_JSON)) { return }
    try {
        $j = Get-Content -LiteralPath $script:CCA_MAIN_JSON -Raw | ConvertFrom-Json
        $o = [ordered]@{ mcpServers = $(if ($j.mcpServers) { $j.mcpServers } else { @{} }) }
        if ($j.theme) { $o.theme = $j.theme }
        Write-CcaFile $dst ($o | ConvertTo-Json -Depth 20)
    } catch { Remove-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue }
}

function New-CcaAccount([string]$name) {
    $dir = Join-Path $script:CCA_HOME "profiles\$name"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { Write-CcaFail "could not make $dir"; return }
    Sync-CcaShared $dir
    Initialize-CcaConfig $dir
}

function Invoke-CcaAdd($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    if (-not (Test-CcaValid $name)) {
        Write-CcaFail 'usage: cca add <name> [--email you@example.com] [--sso]  (name: a-z, 0-9, - and _)'
        return
    }
    if (Test-CcaExists $name) {
        Write-CcaFail "account '$name' already exists. To log in again: cca login $name"
        return
    }
    New-CcaAccount $name
    if ($script:CCA_FAILED) { return }
    Write-Host "Created account '$name'."
    Invoke-CcaLogin (@($name) + @($a | Select-Object -Skip 1))
}

function Invoke-CcaLogin($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    if (-not (Test-CcaExists $name)) {
        Write-CcaFail 'usage: cca login <name> [--email you@example.com] [--sso]'
        Write-CcaErr ("accounts: " + ((Get-CcaProfiles) -join ', '))
        return
    }
    $dir = Get-CcaDir $name
    if ($dir) { Sync-CcaShared $dir }
    # The safety backup must not fail the login; cca.zsh throws its status away too.
    $failed = $script:CCA_FAILED
    try { Invoke-CcaBackup @('--quiet') | Out-Null } catch {}
    $script:CCA_FAILED = $failed
    Write-Host "Signing in '$name'. If the browser is signed in to another Claude account, switch it there first."
    Invoke-CcaClaude $name (@('auth', 'login') + @($a | Select-Object -Skip 1))
}

function Invoke-CcaUse($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    switch -CaseSensitive ($name) {
        '' {
            if ($global:CCA_ACCOUNT) { Write-Host "This terminal uses: $($global:CCA_ACCOUNT)  (cca use - to stop)" }
            else { Write-Host 'This terminal follows folder bindings. Set one with: cca use <name>' }
        }
        { $_ -eq '-' -or $_ -eq 'off' } {
            Remove-Variable -Name CCA_ACCOUNT -Scope Global -ErrorAction SilentlyContinue
            Write-Host 'This terminal follows folder bindings again.'
        }
        default {
            if (-not (Test-CcaExists $name)) { Write-CcaFail "no account '$name'. See: cca list"; return }
            $global:CCA_ACCOUNT = $name
            Write-Host "This terminal now uses: $name"
        }
    }
}

function Invoke-CcaBind($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    if (-not $name) { Write-CcaFail 'usage: cca bind <name> [folder]'; return }
    if (-not (Test-CcaExists $name)) { Write-CcaFail "no account '$name'. See: cca list"; return }
    $dir = if ($a.Count -gt 1) { $a[1] } else { (Get-Location).ProviderPath }
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { Write-CcaFail "not a folder: $dir"; return }
    $dir = Get-CcaFullPath (Resolve-Path -LiteralPath $dir).ProviderPath
    $keep = @(Get-CcaBindings | Where-Object { (Get-CcaFullPath $_.Path) -ine $dir })
    $keep += [pscustomobject]@{ Path = $dir; Name = $name }
    Save-CcaBindings $keep
    Write-Host "$dir and its subfolders now use: $name"
}

function Invoke-CcaUnbind($a) {
    $arg = if ($a.Count) { $a[0] } else { (Get-Location).ProviderPath }
    $dir = Get-CcaFullPath $arg
    $all = @(Get-CcaBindings)
    $mine = @($all | Where-Object { (Get-CcaFullPath $_.Path) -ieq $dir })
    if ($mine.Count) {
        Save-CcaBindings @($all | Where-Object { (Get-CcaFullPath $_.Path) -ine $dir })
        Write-Host "Removed the binding on $dir"
        return
    }
    $hit = Get-CcaBound $dir
    if ($hit) { Write-CcaFail "$dir has no binding of its own; it follows $($hit.Path) ($($hit.Name))" }
    else { Write-CcaFail "no binding on $dir" }
}

function Invoke-CcaRun($a) {
    if (-not $a.Count) { Write-CcaFail 'usage: cca run <name> [claude args...]'; return }
    Invoke-CcaClaude $a[0] @($a | Select-Object -Skip 1)
}

function Get-CcaEmail([string]$name) {
    $dir = Get-CcaDir $name
    $json = if ($dir) { Join-Path $dir '.claude.json' } else { $script:CCA_MAIN_JSON }
    if (Test-Path -LiteralPath $json) {
        try {
            $o = (Get-Content -LiteralPath $json -Raw | ConvertFrom-Json).oauthAccount
            if ($o.emailAddress) { return [pscustomobject]@{ Email = $o.emailAddress; Org = $o.organizationName } }
        } catch {}
    }
    $null
}

function Show-CcaList {
    $here = (Resolve-CcaAccount).Name
    foreach ($name in (Get-CcaProfiles)) {
        $e = Get-CcaEmail $name
        $mark = if ($name -ceq $here) { '*' } else { ' ' }
        $who = if ($e) { $e.Email + $(if ($e.Org) { "  ($($e.Org))" } else { '' }) } else { 'not logged in' }
        '{0} {1,-14} {2}' -f $mark, $name, $who
    }
}

function Show-CcaStatus {
    $r = Resolve-CcaAccount
    Write-Host "Here: $($r.Name)  ($($r.Why))"
    Write-Host ''
    Write-Host 'Accounts:'
    Show-CcaList
    $b = @(Get-CcaBindings)
    if ($b.Count) {
        Write-Host ''
        Write-Host 'Folders:'
        foreach ($x in $b) { Write-Host "  $($x.Path) -> $($x.Name)" }
    }
}

# ---- Claude desktop app -------------------------------------------------

function Get-CcaClaudeApp {
    $override = [Environment]::GetEnvironmentVariable('CCA_CLAUDE_EXE')
    if ($override) { return $override }
    $cands = @(
        (Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Claude\Claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\claude-desktop\Claude.exe')
    )
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return $c } }
    $pkg = Get-AppxPackage -Name '*Claude*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg) {
        $c = Join-Path $pkg.InstallLocation 'app\Claude.exe'
        if (Test-Path -LiteralPath $c) { return $c }
    }
    $null
}

function Get-CcaAppData([string]$name) {
    if ($name -ceq (Get-CcaDefaultName)) { return $null }
    Join-Path $script:CCA_HOME "desktop\$name"
}

# The process id of the Claude app already open for an account, or $null.
function Get-CcaAppPid([string]$name) {
    $exe = Get-CcaClaudeApp
    if (-not $exe) { return $null }
    $data = Get-CcaAppData $name
    $procs = Get-CimInstance Win32_Process -Filter "Name = 'claude.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        $cl = [string]$p.CommandLine
        if ($cl -notlike '*--type=*' -and $p.ExecutablePath -ieq $exe) {
            if (-not $data) { if ($cl -notlike '*--user-data-dir=*') { return [int]$p.ProcessId } }
            elseif ($cl -like "*--user-data-dir=*$data*") { return [int]$p.ProcessId }
        }
    }
    $null
}

function Set-CcaFront([int]$procId) {
    try {
        Add-Type -Namespace Cca -Name Win -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int c);
'@ -ErrorAction SilentlyContinue
        $h = (Get-Process -Id $procId -ErrorAction Stop).MainWindowHandle
        if ($h -eq [IntPtr]::Zero) { return $false }
        [Cca.Win]::ShowWindow($h, 9) | Out-Null
        [Cca.Win]::SetForegroundWindow($h)
    } catch { $false }
}

function Invoke-CcaOpen($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    if (-not (Test-CcaExists $name)) { Write-CcaFail ('usage: cca open <name>. Accounts: ' + ((Get-CcaProfiles) -join ', ')); return }
    $exe = Get-CcaClaudeApp
    if (-not $exe) { Write-CcaFail 'could not find the Claude desktop app. Set CCA_CLAUDE_EXE to its Claude.exe path.'; return }
    $procId = Get-CcaAppPid $name
    if ($procId) {
        if (-not (Set-CcaFront $procId)) { Write-CcaErr "'$name' is open but could not be brought to the front." }
        return
    }
    $data = Get-CcaAppData $name
    if (-not $data) { Start-Process -FilePath $exe; return }
    New-Item -ItemType Directory -Force -Path $data | Out-Null
    if (-not (Test-Path -LiteralPath $data -PathType Container)) { Write-CcaFail "could not make $data"; return }
    $old = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR')
    [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', (Join-Path $script:CCA_HOME "profiles\$name"))
    try { Start-Process -FilePath $exe -ArgumentList "--user-data-dir=`"$data`"" }
    finally { [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $old) }
}

function Get-CcaLauncherPath([string]$name) {
    $dir = Get-CcaEnv 'CCA_LAUNCHERS' (Join-Path ([Environment]::GetFolderPath('Programs')) 'cca')
    $title = (Get-Culture).TextInfo.ToTitleCase($name)
    Join-Path $dir "Claude $title.lnk"
}

# Makes a Start Menu shortcut "Claude <Name>" that runs `cca open <name>`.
function Invoke-CcaApp($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    if (-not (Test-CcaValid $name)) { Write-CcaFail 'usage: cca app <name>'; return }
    if ($a.Count -gt 1) { Write-CcaErr 'colour tinting is not available on Windows; the plain Claude icon is used' }
    $exe = Get-CcaClaudeApp
    if (-not $exe) { Write-CcaFail 'could not find the Claude desktop app. Set CCA_CLAUDE_EXE to its Claude.exe path.'; return }
    if (-not (Test-CcaExists $name)) { New-CcaAccount $name; if ($script:CCA_FAILED) { return } }
    $lnk = Get-CcaLauncherPath $name
    New-Item -ItemType Directory -Force -Path (Split-Path $lnk) | Out-Null
    $sh = New-Object -ComObject WScript.Shell
    $s = $sh.CreateShortcut($lnk)
    $s.TargetPath = (Get-Process -Id $PID).Path
    $s.Arguments = "-NoProfile -WindowStyle Hidden -Command `". '$($script:CCA_HOME)\cca.ps1'; cca open $name`""
    $s.IconLocation = "$exe,0"
    $s.Description = "cca:$name"
    $s.WindowStyle = 7
    $s.Save()
    Write-Host "Made: $lnk (find it in the Start menu; right-click > Pin to taskbar)"
    $default = Get-CcaDefaultName
    if ($name -cne $default -and -not (Test-Path -LiteralPath (Join-Path $script:CCA_HOME "desktop\$name"))) {
        $t = (Get-Culture).TextInfo.ToTitleCase($name)
        Write-Host "First sign-in: quit every Claude window, open 'Claude $t', sign in, then reopen the others."
    }
}

# ---- remove, backup, restore -------------------------------------------

# Moves a file or folder to the Recycle Bin, so a removal can be undone.
function Move-CcaToTrash([string]$path) {
    $trash = [Environment]::GetEnvironmentVariable('CCA_TRASH')
    if ($trash) {
        New-Item -ItemType Directory -Force -Path $trash | Out-Null
        Move-Item -LiteralPath $path -Destination (Join-Path $trash ((Split-Path $path -Leaf) + '.' + [DateTimeOffset]::Now.ToUnixTimeSeconds() + '.' + (Get-Random)))
        return
    }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $fio = [Microsoft.VisualBasic.FileIO.FileSystem]
    if (Test-Path -LiteralPath $path -PathType Container) {
        $fio::DeleteDirectory($path, 'OnlyErrorDialogs', 'SendToRecycleBin')
    } else {
        $fio::DeleteFile($path, 'OnlyErrorDialogs', 'SendToRecycleBin')
    }
}

function Invoke-CcaRemove($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    if (-not (Test-CcaExists $name)) { Write-CcaFail ('usage: cca remove <name>. Accounts: ' + ((Get-CcaProfiles) -join ', ')); return }
    $default = Get-CcaDefaultName
    if ($name -cne $default) {
        $procId = Get-CcaAppPid $name
        if ($procId) { Write-CcaFail "the Claude app for '$name' is open (PID $procId). Quit it first."; return }
    }
    # Neither the safety backup nor a logout that fails (already logged out) fails
    # the removal; cca.zsh throws both statuses away as well.
    $failed = $script:CCA_FAILED
    try { Invoke-CcaBackup @('--quiet') | Out-Null } catch {}
    $dir = Get-CcaDir $name
    $data = Get-CcaAppData $name
    try { Invoke-CcaClaude $name @('auth', 'logout') *> $null } catch {}
    $script:CCA_FAILED = $failed
    $global:LASTEXITCODE = 0
    Save-CcaBindings @(Get-CcaBindings | Where-Object { $_.Name -cne $name })
    $lnk = Get-CcaLauncherPath $name
    if (Test-Path -LiteralPath $lnk) { Move-CcaToTrash $lnk }
    if ($data -and (Test-Path -LiteralPath $data)) { Move-CcaToTrash $data }
    if ($dir -and (Test-Path -LiteralPath $dir)) { Move-CcaToTrash $dir }
    if ($global:CCA_ACCOUNT -ceq $name) { Remove-Variable -Name CCA_ACCOUNT -Scope Global -ErrorAction SilentlyContinue }
    if ($name -ceq $default) { Write-Host "Logged out '$name' and moved its launcher to the Recycle Bin. ~\.claude and its settings stay." }
    else { Write-Host "Removed '$name': logged out and moved its folders and launcher to the Recycle Bin." }
}

function Get-CcaAccountUuid([string]$name) {
    $json = Join-Path $script:CCA_HOME "profiles\$name\.claude.json"
    if (Test-Path -LiteralPath $json) {
        try {
            $id = (Get-Content -LiteralPath $json -Raw | ConvertFrom-Json).oauthAccount.accountUuid
            if ($id) { return [string]$id }
        } catch {}
    }
    $d = Join-Path $script:CCA_HOME "desktop\$name\claude-code-sessions"
    if (Test-Path -LiteralPath $d) {
        $dirs = @(Get-ChildItem -LiteralPath $d -Directory)
        if ($dirs.Count -eq 1) { return $dirs[0].Name }
    }
    $null
}

# The two folders of an account that cca protects: @{ Projects; Sessions }.
function Get-CcaDataDirs([string]$name) {
    if ($name -ceq (Get-CcaDefaultName)) {
        [pscustomobject]@{ Projects = (Join-Path $script:CCA_MAIN_DIR 'projects'); Sessions = (Join-Path $script:CCA_MAIN_APP_DATA 'claude-code-sessions') }
    } else {
        [pscustomobject]@{ Projects = (Join-Path $script:CCA_HOME "profiles\$name\projects"); Sessions = (Join-Path $script:CCA_HOME "desktop\$name\claude-code-sessions") }
    }
}

# Snapshot names, newest first.
function Get-CcaSnapshots {
    $r = Join-Path $script:CCA_HOME 'backups'
    if (Test-Path -LiteralPath $r) {
        Get-ChildItem -LiteralPath $r -Directory |
            Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{6}(-\d+)?$' } |
            Sort-Object Name -Descending | ForEach-Object { $_.Name }
    }
}

# Copies the files under $from that are missing under $to. $c counts what was copied.
function Copy-CcaMissing([string]$from, [string]$to, [string]$kind, $c) {
    if (-not (Test-Path -LiteralPath $from -PathType Container)) { return }
    $root = (Get-Item -LiteralPath $from).FullName.TrimEnd('\')
    foreach ($f in (Get-ChildItem -LiteralPath $from -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($root.Length + 1)
        $dst = Join-Path $to $rel
        if (Test-Path -LiteralPath $dst) { continue }
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item -LiteralPath $f.FullName -Destination $dst
        } catch { Write-CcaErr "could not copy $($f.FullName)"; $c.bad++; continue }
        if ($kind -eq 'sess' -and $f.Name -like 'local_*.json') { $c.sess++ }
        if ($kind -eq 'tr' -and $rel -match '^[^\\]+\\[^\\]+\.jsonl$') { $c.tr++ }
    }
}

function Invoke-CcaBackup($a) {
    $arg = if ($a.Count) { $a[0] } else { '' }
    if ($arg -eq 'list') { Get-CcaSnapshots; return }
    if ($arg -and $arg -ne '--quiet') { Write-CcaFail 'usage: cca backup [--quiet]  or  cca backup list'; return }
    $quiet = $arg -eq '--quiet'
    $keep = 30
    $envKeep = [Environment]::GetEnvironmentVariable('CCA_BACKUP_KEEP')
    if ($envKeep -match '^\d+$' -and [int]$envKeep -ge 1) { $keep = [int]$envKeep }
    $root = Join-Path $script:CCA_HOME 'backups'
    $lock = Join-Path $root '.lock'
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { Write-CcaFail "could not make $root"; return }
    # One run at a time; a lock older than an hour is left over from a crash.
    try { New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null }
    catch {
        if ((Get-Item -LiteralPath $lock -ErrorAction SilentlyContinue).LastWriteTime -lt (Get-Date).AddMinutes(-60)) {
            Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
        }
        try { New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null }
        catch { Write-CcaFail 'another backup is running'; return }
    }
    try {
        $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
        $snap = Join-Path $root $stamp
        $n = 1
        while (Test-Path -LiteralPath $snap) { $n++; $snap = Join-Path $root "$stamp-$n" }
        New-Item -ItemType Directory -Path $snap | Out-Null
        if (-not (Test-Path -LiteralPath $snap -PathType Container)) { Write-CcaFail "could not make $snap"; return }
        $accts = 0; $dirs = 0; $bad = 0
        foreach ($name in (Get-CcaProfiles)) {
            $d = Get-CcaDataDirs $name
            $got = 0
            foreach ($src in @($d.Projects, $d.Sessions)) {
                if (-not (Test-Path -LiteralPath $src -PathType Container)) { continue }
                try {
                    $dest = Join-Path $snap "$name\$(Split-Path $src -Leaf)"
                    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
                    Copy-Item -LiteralPath $src -Destination $dest -Recurse -ErrorAction Stop
                    $dirs++; $got = 1
                } catch { Write-CcaErr "could not copy $src"; $bad++ }
            }
            $accts += $got
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $snap 'cca') | Out-Null
        foreach ($f in 'bindings', 'default-name') {
            $p = Join-Path $script:CCA_HOME $f
            if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $snap "cca\$f") }
        }
        $snaps = @(Get-CcaSnapshots)
        $old = @()
        # A snapshot with a failed folder must not push out the good older ones.
        if ($snaps.Count -gt $keep -and $bad -eq 0) { $old = @($snaps | Select-Object -Skip $keep) }
        foreach ($o in $old) { Remove-Item -LiteralPath (Join-Path $root $o) -Recurse -Force }
        $leaf = Split-Path $snap -Leaf
        Add-Content -LiteralPath (Join-Path $root 'backup.log') -Value ("{0} {1} accounts={2} folders={3} failed={4} pruned={5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $leaf, $accts, $dirs, $bad, $old.Count)
        if (-not $quiet) { Write-Host "Backup ${leaf}: $accts accounts, $dirs folders. Keeping the newest $keep." }
        # cca.zsh ends _cca_backup with `(( bad == 0 ))`: a folder it could not copy fails the backup.
        if ($bad) { Set-CcaFailed }
    } finally {
        Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-CcaRestore($a) {
    $name = if ($a.Count) { $a[0] } else { '' }
    $snapname = if ($a.Count -gt 1) { $a[1] } else { '' }
    if (-not (Test-CcaExists $name)) { Write-CcaFail ('usage: cca restore <name> [snapshot]. Accounts: ' + ((Get-CcaProfiles) -join ', ')); return }
    $procId = Get-CcaAppPid $name
    if ($procId) { Write-CcaFail "the Claude app for '$name' is open (PID $procId). Quit it first."; return }
    $d = Get-CcaDataDirs $name
    $root = Join-Path $script:CCA_HOME 'backups'
    if ($snapname) {
        if ($snapname -notmatch '^\d{4}-\d{2}-\d{2}_\d{6}(-\d+)?$' -or -not (Test-Path -LiteralPath (Join-Path $root "$snapname\$name"))) {
            Write-CcaFail "snapshot '$snapname' has nothing for '$name'. See: cca backup list"
            return
        }
    } else {
        foreach ($s in (Get-CcaSnapshots)) {
            if (Test-Path -LiteralPath (Join-Path $root "$s\$name")) { $snapname = $s; break }
        }
    }
    $src = $null
    if ($name -cne (Get-CcaDefaultName)) {
        $acct = Get-CcaAccountUuid $name
        if ($acct -match '^[0-9A-Za-z-]+$') {
            $cand = Join-Path $script:CCA_MAIN_APP_DATA "claude-code-sessions\$acct"
            if (Test-Path -LiteralPath $cand) { $src = $cand }
        }
    }
    if (-not $snapname -and -not $src) {
        Write-CcaFail "no backup has '$name', and the main Claude app has none of its sessions. See: cca backup list"
        return
    }
    $c = @{ sess = 0; tr = 0; bad = 0 }
    $tomb = 0
    if ($snapname) {
        Copy-CcaMissing (Join-Path $root "$snapname\$name\projects") $d.Projects 'tr' $c
        Copy-CcaMissing (Join-Path $root "$snapname\$name\claude-code-sessions") $d.Sessions 'sess' $c
    }
    if ($src) {
        $desk = Join-Path $script:CCA_HOME "desktop\$name"
        New-Item -ItemType Directory -Force -Path $desk | Out-Null
        if (-not (Test-Path -LiteralPath $desk -PathType Container)) { Write-CcaFail "could not make $desk"; return }
        Copy-CcaMissing $src (Join-Path $d.Sessions $acct) 'sess' $c
        # The transcripts those sessions point to.
        $from = Join-Path $script:CCA_MAIN_DIR 'projects'
        foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Filter 'local_*.json' -Force)) {
            try { $id = (Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json).cliSessionId } catch { continue }
            if ($id -notmatch '^[A-Za-z0-9_-]+$') { continue }
            foreach ($t in (Get-ChildItem -Path (Join-Path $from "*\$id.jsonl") -ErrorAction SilentlyContinue)) {
                $slug = $t.Directory.Name
                $dst = Join-Path $d.Projects "$slug\$id.jsonl"
                if (-not (Test-Path -LiteralPath $dst)) {
                    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
                    Copy-Item -LiteralPath $t.FullName -Destination $dst
                    $c.tr++
                }
                $sub = Join-Path $t.Directory.FullName $id
                if (Test-Path -LiteralPath $sub -PathType Container) { Copy-CcaMissing $sub (Join-Path $d.Projects "$slug\$id") 'none' $c }
            }
        }
    }
    # A session that was logged out of has a 'deleted' mark next to it, which hides it.
    if (Test-Path -LiteralPath $d.Sessions) {
        foreach ($f in (Get-ChildItem -LiteralPath $d.Sessions -Recurse -File -Filter 'local_*.json' -Force)) {
            $id = $f.BaseName.Substring('local_'.Length)
            $mark = Join-Path $f.DirectoryName "deleted_$id"
            if (Test-Path -LiteralPath $mark -PathType Leaf) {
                try { Move-CcaToTrash $mark; $tomb++ } catch { $c.bad++ }
            }
        }
    }
    $from = if ($snapname) { $snapname } else { 'the main Claude app' }
    if ($snapname -and $src) { $from += ' and the main Claude app' }
    Write-Host "Restored '$name' from ${from}: $($c.sess) sessions, $($c.tr) transcripts, $tomb deleted marks moved to the Recycle Bin. Nothing was overwritten."
    # cca.zsh ends _cca_restore with `(( bad == 0 ))`.
    if ($c.bad) { Set-CcaFailed }
}

# A daily backup at 13:00 as a Task Scheduler job.
function Invoke-CcaAutobackup($a) {
    $arg = if ($a.Count) { $a[0] } else { '' }
    $task = 'cca-backup'
    switch ($arg) {
        'on' {
            $ps = (Get-Process -Id $PID).Path
            $cmd = ". '$($script:CCA_HOME)\cca.ps1'; cca backup --quiet"
            $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -WindowStyle Hidden -Command `"$cmd`""
            $trigger = New-ScheduledTaskTrigger -Daily -At '13:00'
            $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
            try {
                Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction Stop | Out-Null
            } catch { Write-CcaFail "Task Scheduler could not create the job: $($_.Exception.Message)"; return }
            Write-Host 'Autobackup on: every day at 13:00 (a missed run happens at the next start).'
        }
        'off' {
            Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host 'Autobackup off.'
        }
        'status' {
            $on = [bool](Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue)
            $newest = @(Get-CcaSnapshots) | Select-Object -First 1
            Write-Host ("Autobackup: {0}. Newest backup: {1}" -f $(if ($on) { 'on' } else { 'off' }), $(if ($newest) { $newest } else { 'none' }))
        }
        default { Write-CcaFail 'usage: cca autobackup on|off|status' }
    }
}

function Show-CcaHelp {
    @'
cca - switch Claude Code between accounts (Windows)

  cca                        show the account used here, all accounts and bound folders
  cca add <name> [opts]      create an account and log in   (opts: --email you@x.com, --sso)
  cca login <name> [opts]    log in again (expired, or the wrong account)
  cca use <name>             use an account in this terminal   (cca use - to stop)
  cca bind <name> [folder]   always use an account in a folder and its subfolders
  cca unbind [folder]        remove a folder binding
  cca run <name> [args]      run claude once with an account
  cca list                   list accounts with their emails
  cca app <name>             make a 'Claude <Name>' Start menu shortcut for the desktop app
  cca open <name>            open the Claude desktop app for an account (or bring it to the front)
  cca remove <name>          log out an account; move its folders and launcher to the Recycle Bin
  cca backup [--quiet|list]  save every account's conversations (keeps the newest 30)
  cca restore <name> [snap]  bring an account's conversations back (never overwrites)
  cca autobackup on|off|status   a daily backup at 13:00

Order: cca use > folder binding > default account (~\.claude).
Set CCA_QUIET=1 to hide the line 'claude' prints about the account.
'@ | Write-Host
}

function cca {
    $cmd = if ($args.Count) { [string]$args[0] } else { 'status' }
    $rest = @($args | Select-Object -Skip 1)
    # $LASTEXITCODE is the status callers read, desktop/main/cca-shim.ps1 among them
    # (it exits with it). Starting at 0 keeps a stale code from an earlier command
    # out; a native command a cca command runs (claude) leaves its own code here.
    $script:CCA_FAILED = $false
    $global:LASTEXITCODE = 0
    switch ($cmd) {
        'status'  { Show-CcaStatus }
        { $_ -in 'list', 'ls' } { Show-CcaList }
        'add'     { Invoke-CcaAdd $rest }
        'login'   { Invoke-CcaLogin $rest }
        'use'     { Invoke-CcaUse $rest }
        'bind'    { Invoke-CcaBind $rest }
        'unbind'  { Invoke-CcaUnbind $rest }
        'run'     { Invoke-CcaRun $rest }
        'app'     { Invoke-CcaApp $rest }
        'open'    { Invoke-CcaOpen $rest }
        { $_ -in 'remove', 'rm' } { Invoke-CcaRemove $rest }
        'import'  { Write-CcaFail "'import' is not available on Windows yet. Use: cca restore <name>" }
        'backup'  { Invoke-CcaBackup $rest }
        'restore' { Invoke-CcaRestore $rest }
        'autobackup' { Invoke-CcaAutobackup $rest }
        { $_ -in 'help', '-h', '--help' } { Show-CcaHelp }
        default   { Write-CcaFail "unknown command '$cmd'"; Show-CcaHelp }
    }
    if ($script:CCA_FAILED) { $global:LASTEXITCODE = 1 }
}

# Wraps `claude` so it runs with the account chosen for this folder or terminal.
function claude {
    $script:CCA_FAILED = $false
    $global:LASTEXITCODE = 0
    # try/finally so the early returns below set the status too.
    try {
        $exe = Get-CcaClaudeExe
        if (-not $exe) { return }
        # Inside Claude Code, keep the account the parent session runs on.
        if ($env:CLAUDECODE) { & $exe @args; return }
        $r = Resolve-CcaAccount
        if (-not (Test-CcaExists $r.Name)) {
            Write-CcaFail "account '$($r.Name)' ($($r.Why)) does not exist. See: cca list"
            return
        }
        if (-not $env:CCA_QUIET -and -not [Console]::IsErrorRedirected) {
            [Console]::Error.WriteLine("$([char]27)[2mclaude account: $($r.Name) ($($r.Why))$([char]27)[0m")
        }
        $claudeArgs = $args
        $block = { & $exe @claudeArgs }.GetNewClosure()
        Invoke-CcaAs $r.Name $block
    } finally {
        if ($script:CCA_FAILED) { $global:LASTEXITCODE = 1 }
    }
}

Register-ArgumentCompleter -CommandName cca -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $words = @($commandAst.CommandElements | ForEach-Object { $_.ToString() })
    $pos = $words.Count - $(if ($wordToComplete) { 1 } else { 0 })
    $cmds = 'status', 'list', 'add', 'login', 'use', 'bind', 'unbind', 'run', 'app', 'open', 'remove', 'backup', 'restore', 'autobackup', 'help'
    $pick = if ($pos -le 1) { $cmds }
        elseif ($pos -eq 2 -and $words[1] -in 'login', 'use', 'bind', 'run', 'app', 'open', 'remove', 'restore') { Get-CcaProfiles }
        elseif ($pos -eq 2 -and $words[1] -eq 'backup') { 'list', '--quiet' }
        elseif ($pos -eq 2 -and $words[1] -eq 'autobackup') { 'on', 'off', 'status' }
        elseif ($pos -eq 3 -and $words[1] -eq 'restore') { Get-CcaSnapshots }
    $pick | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
