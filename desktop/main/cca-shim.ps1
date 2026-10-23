# Runs one cca command for the desktop app. Arguments arrive as a real argv
# array, so nothing is ever interpolated into a PowerShell command string.
param([Parameter(ValueFromRemainingArguments = $true)]$CcaArgs)

if (-not $env:CCA_HOME) { $env:CCA_HOME = Join-Path $HOME '.claude-accounts' }
. (Join-Path $env:CCA_HOME 'cca.ps1')

$global:LASTEXITCODE = 0
cca @CcaArgs
exit $global:LASTEXITCODE
