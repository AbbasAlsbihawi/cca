# Parses every .ps1 in the repo, so a syntax error cannot ship green.
# Usage: pwsh tests/parse-ps1.ps1
# CI runs it twice: PowerShell 7 on macos-latest, and Windows PowerShell 5.1 on
# windows-latest, which is the version cca.ps1 targets. So keep this file to 5.1
# syntax (no ??, ?. or ternaries) and to plain ASCII, which 5.1 reads correctly
# from a file without a byte order mark.

$root = Split-Path -Parent $PSScriptRoot
$parsed = 0
$fail = 0

"PowerShell $($PSVersionTable.PSVersion)"
foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.ps1)) {
    if ($f.FullName -like '*node_modules*') { continue }
    $parsed++
    $rel = $f.FullName.Substring($root.Length + 1)
    $e = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e)
    if ($e) {
        $fail++
        "FAIL - $rel"
        $e | ForEach-Object { "         " + $_.Message }
    } else {
        "ok - $rel"
    }
}

"$parsed parsed, $fail failed"
if ($fail) { exit 1 }
exit 0
