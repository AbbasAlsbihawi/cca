# Runs one cca command for the desktop app. Arguments arrive as a real argv
# array, so nothing is ever interpolated into a PowerShell command string.
param([Parameter(ValueFromRemainingArguments = $true)]$CcaArgs)

if (-not $env:CCA_HOME) { $env:CCA_HOME = Join-Path $HOME '.claude-accounts' }
$cli = Join-Path $env:CCA_HOME 'cca.ps1'
if (Test-Path -LiteralPath $cli) { . $cli }
# A failed load does not stop a script: without this check the `cca` call below
# only prints to stderr, and the app reads the exit code 0 and empty stdout as a
# successful command.
if (-not (Get-Command cca -CommandType Function -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("cca: could not load $cli. Reopen Claude Accounts to install it, or run install.ps1 from the cca repo.")
    exit 1
}

$global:LASTEXITCODE = 0
cca @CcaArgs
exit $global:LASTEXITCODE
