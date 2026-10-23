# Uninstall cca on Windows: removes the profile lines, cca.ps1, the backup job and launcher shortcuts.
# Account data and backups in ~\.claude-accounts are kept.
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($p in @((Join-Path $docs 'WindowsPowerShell\profile.ps1'), (Join-Path $docs 'PowerShell\profile.ps1'))) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $bak = "$p.bak-cca-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -LiteralPath $p -Destination $bak
    $keep = Get-Content -LiteralPath $p | Where-Object { $_ -ne '# Claude Code accounts (cca)' -and $_ -notmatch 'claude-accounts\\cca\.ps1' }
    Set-Content -LiteralPath $p -Value $keep
    Write-Host "Cleaned $p (backup: $bak)"
}

Remove-Item -LiteralPath (Join-Path $HOME '.claude-accounts\cca.ps1') -Force -ErrorAction SilentlyContinue

if (Get-ScheduledTask -TaskName 'cca-backup' -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName 'cca-backup' -Confirm:$false
    Write-Host 'Removed the daily backup job'
}

$launchers = Join-Path ([Environment]::GetFolderPath('Programs')) 'cca'
if (Test-Path -LiteralPath $launchers) {
    Remove-Item -LiteralPath $launchers -Recurse -Force
    Write-Host "Removed launchers in $launchers"
}

Write-Host "Done. Your accounts and backups are still in $HOME\.claude-accounts"
Write-Host 'To delete them too:  Remove-Item -Recurse -Force "$HOME\.claude-accounts"'
