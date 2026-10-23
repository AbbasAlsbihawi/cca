# Install cca on Windows: copies cca.ps1 to ~\.claude-accounts and hooks it into your PowerShell profiles.
$ErrorActionPreference = 'Stop'

$src = Join-Path $PSScriptRoot 'cca.ps1'
if (-not (Test-Path -LiteralPath $src)) { Write-Error 'install: cca.ps1 not found next to install.ps1'; exit 1 }

$home_dir = Join-Path $HOME '.claude-accounts'
New-Item -ItemType Directory -Force -Path (Join-Path $home_dir 'profiles') | Out-Null
Copy-Item -LiteralPath $src -Destination (Join-Path $home_dir 'cca.ps1') -Force
Write-Host "Installed $home_dir\cca.ps1"

$docs = [Environment]::GetFolderPath('MyDocuments')
$profiles = @(
    (Join-Path $docs 'WindowsPowerShell\profile.ps1'),   # Windows PowerShell 5.1
    (Join-Path $docs 'PowerShell\profile.ps1')           # PowerShell 7
)
$line = '. "$HOME\.claude-accounts\cca.ps1"'
foreach ($p in $profiles) {
    # Only touch a shell that is installed (its folder exists), plus the one running now.
    $isCurrent = $p -eq $PROFILE.CurrentUserAllHosts
    if (-not $isCurrent -and -not (Test-Path -LiteralPath (Split-Path $p))) { continue }
    New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType File -Path $p | Out-Null }
    if (Select-String -LiteralPath $p -Pattern 'claude-accounts\\cca\.ps1' -Quiet) {
        Write-Host "$p already loads cca"
        continue
    }
    $bak = "$p.bak-cca-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -LiteralPath $p -Destination $bak
    Add-Content -LiteralPath $p -Value "`n# Claude Code accounts (cca)`n$line"
    Write-Host "Added cca to $p (backup: $bak)"
}

if ((Get-ExecutionPolicy) -in 'Restricted', 'AllSigned') {
    Write-Host ''
    Write-Host 'PowerShell is blocking profile scripts. Allow your own scripts with:'
    Write-Host '  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
}

Write-Host @'

Next steps:
  1. Open a new PowerShell window
  2. Name your current account before binding folders:
       Set-Content "$HOME\.claude-accounts\default-name" work
  3. Run: cca help
'@
