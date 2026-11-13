# Phase 3D: Windows x64 test handoff (CCA 0.2.0 candidate)

For a contributor with a real x64 Windows 10 or 11 PC. These tests confirm the CCA 0.2.0 installer on native x64. Until now it was tested only in a Windows 11 ARM virtual machine, where the x64 installer runs under emulation. The full results of that run are in [PHASE-3D-GATE-C-REPORT.md](PHASE-3D-GATE-C-REPORT.md), section "Windows".

Please send back the results described in "What to send back". Do not publish anything, and do not open a pull request for these tests.

## Before you start

- **Use a disposable Windows virtual machine** (Hyper-V, VirtualBox, VMware or similar). The tests install, upgrade and uninstall CCA for the whole machine, add test accounts and change shortcuts. **Do not use a PC with your real Claude accounts** or a real "Claude Accounts" or CCA install.
- Sign in with an administrator account (the first account Windows creates). Keep the Windows defaults: UAC on, SmartScreen on, Microsoft Defender on.
- Use only the test data below. Do not log in to Claude in this VM.
- Allow about 1.5 hours.

## Files

| File | Where from | SHA-256 |
|---|---|---|
| `CCA-Setup-0.2.0.exe` (the candidate) | Sent to you by the maintainer | `d1637d6149b8723cb396afa05524006745285aef3816864529417d0c8a06cd94` |
| `ClaudeAccounts-Setup-0.1.12.exe` (the current release) | [GitHub release v0.1.12](https://github.com/AbbasAlsbihawi/cca/releases/tag/v0.1.12) | `4a4e1f5f6bf1ee6ae46d7f1925d5d647bb5f7bfe7d12ed62b56c07f47b5f9e68` |

The 0.2.0 file is an unpublished test build, so its hash is the only proof that you have the right file. Get the expected hash through a different channel than the file itself: if the file comes by link, the maintainer confirms the hash in a separate message. Compare all 64 characters, not just the start.

Download both files in the VM with a browser into `Downloads`, so Windows marks them as downloaded (this is what triggers SmartScreen). Check both hashes before anything else:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\CCA-Setup-0.2.0.exe", "$env:USERPROFILE\Downloads\ClaudeAccounts-Setup-0.1.12.exe" -Algorithm SHA256 | Format-List Path, Hash
```

If a hash does not match, stop and tell the maintainer.

## Helper scripts

Save these three scripts in `Downloads`. Run them with `powershell -ExecutionPolicy Bypass -File .\<name>.ps1`.

**`cca-check.ps1`** prints the install state. It changes nothing.

```powershell
$g = '8a5b5904-a939-5366-a9c8-063f626483ae'; $UK = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
"os: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version) arch=$env:PROCESSOR_ARCHITECTURE"
foreach ($d in "$env:LOCALAPPDATA\Programs\Claude Accounts", "$env:ProgramFiles\Claude Accounts") { if (Test-Path "$d\Claude Accounts.exe") { $v = (Get-Item "$d\Claude Accounts.exe").VersionInfo; "dir: $d -> $($v.ProductName) $($v.ProductVersion)" } }
foreach ($h in 'HKCU','HKLM') { $u = Get-ItemProperty "${h}:\$UK\$g" -EA 0; $a = Get-ItemProperty "${h}:\Software\$g" -EA 0
  if ($u -or $a) { "${h}: DisplayName=$($u.DisplayName) Uninstall=$(($u.UninstallString -split '" ')[-1]) InstallLocation=$($a.InstallLocation) ShortcutName=$($a.ShortcutName)" } }
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs","$env:ProgramData\Microsoft\Windows\Start Menu\Programs","$env:USERPROFILE\Desktop","$env:PUBLIC\Desktop" -Filter *.lnk -Recurse -EA 0 | Where-Object Name -match 'CCA|Claude' | ForEach-Object { "lnk: $($_.FullName.Replace($env:USERPROFILE,'~'))" }
Get-CimInstance Win32_Process -Filter "Name='Claude Accounts.exe'" | Where-Object { $_.CommandLine -notmatch '--type=' } | ForEach-Object { $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($_.ParentProcessId)"; "running: $($_.ExecutablePath) args=[$($_.CommandLine -replace '^\s*"[^"]*"\s*','')] parent=$($p.Name)" }
function Short($p) { $h = Get-FileHash $p -EA 0; if ($h) { $h.Hash.Substring(0,16) } else { '-' } }
"data: appData=$((Get-ChildItem $env:APPDATA -Directory | Where-Object Name -match 'claude|cca' | Select-Object -ExpandProperty Name) -join ',') marker=$(Short "$env:APPDATA\claude-accounts\cca-test-marker.txt") bindings=$(Short "$env:USERPROFILE\.claude-accounts\bindings") profiles=$((Get-ChildItem "$env:USERPROFILE\.claude-accounts\profiles" -Name -EA 0) -join ',')"
```

**`cca-reset.ps1`** uninstalls CCA from both scopes, keeps the data, and silently installs v0.1.12 for the scope you pass: `currentuser` (only for me) or `allusers` (everyone). `none` only uninstalls. **Run it from an elevated PowerShell** (right-click PowerShell, *Run as administrator*). It touches only CCA / Claude Accounts. It stops unless Windows reports a virtual machine, and it asks you to type `YES` first (`-Yes` skips the question).

```powershell
param([ValidateSet('currentuser','allusers','none')][string]$Scope = 'currentuser', [switch]$Yes)
$cs = Get-CimInstance Win32_ComputerSystem
if ("$($cs.Manufacturer) $($cs.Model)" -notmatch 'Virtual|VMware|VirtualBox|innotek|KVM|QEMU|Parallels|Xen') { "Stopped: this does not look like a virtual machine ($($cs.Manufacturer) $($cs.Model)). Run these tests only in a disposable VM; if your VM is not recognised, tell the maintainer."; return }
if (-not $Yes) { try { $a = Read-Host "This closes and uninstalls CCA / Claude Accounts (both scopes) on this VM, keeps the data, then installs 0.1.12 for '$Scope'. Type YES to continue" } catch { $a = '' }; if ($a -cne 'YES') { 'Cancelled. Nothing was changed.'; return } }
Get-CimInstance Win32_Process -Filter "Name='Claude Accounts.exe'" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
Start-Sleep 3
foreach ($p in @(@("$env:LOCALAPPDATA\Programs\Claude Accounts", '/currentuser'), @("$env:ProgramFiles\Claude Accounts", '/allusers'))) {
  $un = "$($p[0])\Uninstall Claude Accounts.exe"
  if (Test-Path $un) { Start-Process -FilePath $un -ArgumentList '/S', $p[1]; $t = 0; while ((Test-Path "$($p[0])\Claude Accounts.exe") -and $t -lt 180) { Start-Sleep 3; $t += 3 }; Start-Sleep 5; "uninstalled $($p[1])" } }
if ($Scope -eq 'none') { return }
$f = "$env:USERPROFILE\Downloads\ClaudeAccounts-Setup-0.1.12.exe"
$k = if ($Scope -eq 'allusers') { 'HKLM' } else { 'HKCU' }
Start-Process -FilePath $f -ArgumentList '/S', "/$Scope"
$t = 0; while (-not (Get-ItemProperty "${k}:\Software\Microsoft\Windows\CurrentVersion\Uninstall\8a5b5904-a939-5366-a9c8-063f626483ae" -EA 0).DisplayName -and $t -lt 300) { Start-Sleep 3; $t += 3 }; Start-Sleep 8
"installed 0.1.12 /$Scope"
```

**`cca-data.ps1`** adds the synthetic test data, once. Run it after CCA or Claude Accounts has been opened at least once, from a normal PowerShell. It has the same VM check and `YES` question.

```powershell
param([switch]$Yes)
$cs = Get-CimInstance Win32_ComputerSystem
if ("$($cs.Manufacturer) $($cs.Model)" -notmatch 'Virtual|VMware|VirtualBox|innotek|KVM|QEMU|Parallels|Xen') { "Stopped: this does not look like a virtual machine ($($cs.Manufacturer) $($cs.Model))."; return }
if (-not $Yes) { try { $a = Read-Host "This adds the test accounts demo-work and demo-personal, a binding and a marker file. Type YES to continue" } catch { $a = '' }; if ($a -cne 'YES') { 'Cancelled. Nothing was changed.'; return } }
$H = "$env:USERPROFILE\.claude-accounts"
if (-not (Test-Path "$H\cca.ps1")) { 'Open the app once first (it writes cca.ps1), then run this again.'; return }
. "$H\cca.ps1"
cca add demo-work *> $null; cca add demo-personal *> $null
New-Item -ItemType Directory -Force "$env:USERPROFILE\projects\demo" | Out-Null; Push-Location "$env:USERPROFILE\projects\demo"; cca bind demo-work *> $null; Pop-Location
New-Item -ItemType Directory -Force "$env:APPDATA\claude-accounts" | Out-Null
"test marker $(Get-Date -Format o)" | Set-Content "$env:APPDATA\claude-accounts\cca-test-marker.txt"
"profiles: $((Get-ChildItem "$H\profiles" -Name) -join ',')"
```

If you run `cca-data.ps1` a second time, it says the accounts already exist; that is fine.

Run `cca-check.ps1` after every test and keep its output. The `data:` line must stay the same from test to test once the data exists.

## How an update starts on Windows

The app's updater runs the downloaded installer in one of two ways. These tests start the installer the same way by hand, because no 0.2.0 release exists for the app to download:

- **Path A, "Restart now":** `CCA-Setup-0.2.0.exe --updated --force-run`. You see a progress page and a Finish page; CCA starts when you click Finish.
- **Path B, the app quits after the download:** `CCA-Setup-0.2.0.exe --updated /S`. Silent; CCA does not start by itself.

Start both paths from a **normal (not elevated) PowerShell**, with CCA closed, like the app does:

```powershell
Copy-Item "$env:USERPROFILE\Downloads\CCA-Setup-0.2.0.exe" "$env:TEMP\CCA-Setup-0.2.0.exe" -Force
Unblock-File "$env:TEMP\CCA-Setup-0.2.0.exe"
# Path A:
Start-Process "$env:TEMP\CCA-Setup-0.2.0.exe" -ArgumentList '--updated','--force-run'
# Path B (instead of path A):
Start-Process "$env:TEMP\CCA-Setup-0.2.0.exe" -ArgumentList '--updated','/S'
```

For path B, wait about a minute (until the setup process is gone in Task Manager) before running `cca-check.ps1`.

## Tests

Expected `cca-check.ps1` results use these short names:

- **Per-user 0.2.0:** `dir:` `%LOCALAPPDATA%\Programs\Claude Accounts -> CCA 0.2.0`; one `HKCU:` line with `DisplayName=CCA 0.2.0`, `Uninstall=/currentuser`, `ShortcutName=CCA`; no `HKLM:` line; `lnk:` lines only for `CCA.lnk`, one in the user's Start Menu and one on the user's Desktop.
- **All-users 0.2.0:** `dir:` `C:\Program Files\Claude Accounts -> CCA 0.2.0`; one `HKLM:` line with `DisplayName=CCA 0.2.0`, `Uninstall=/allusers`, `ShortcutName=CCA`; no `HKCU:` line; `CCA.lnk` once in `ProgramData` Start Menu and once in `Public\Desktop`.
- In both cases, no `Claude Accounts.lnk` is left, and `appData` shows only `claude-accounts`.

| # | Test | Steps | Expected |
|---|---|---|---|
| 1 | Fresh install (W1) | On the clean VM, double-click `Downloads\CCA-Setup-0.2.0.exe`. SmartScreen: *More info* → *Run anyway*. On "Choose Installation Options", note which option is preselected; keep it. Finish with "Run CCA" checked. | SmartScreen shows "Unknown publisher" (expected, unsigned). "Only for me" is preselected. Per-user 0.2.0. CCA opens. |
| 2 | Single instance | With CCA open, double-click the Desktop `CCA` shortcut again. | No second window. `cca-check.ps1` shows one `running:` line. |
| 3 | Account list time | Look at the CCA window and its Activity panel for "list failed: timed out". Then run the command below and note the seconds. | No "timed out" message. Note the time; on the ARM VM it was 18–24 s from native PowerShell and over 60 s from the emulated app. |
| 4 | Uninstall | Run `cca-reset.ps1 -Scope none` (elevated). | No `dir:`, `HKCU:`, `HKLM:` or `lnk:` lines. `%APPDATA%\claude-accounts` and `~\.claude-accounts` still exist. |
| 5 | Manual upgrade (W2a) | `cca-reset.ps1 -Scope currentuser` (elevated). Open "Claude Accounts" from the Start Menu once, then close it with `Get-Process 'Claude Accounts' -EA 0 \| Stop-Process`. Run `cca-data.ps1`, then `cca-check.ps1`. Then double-click `Downloads\CCA-Setup-0.2.0.exe` and keep the defaults. | The options page shows "Only for me" preselected and a note that a per-user installation exists. Per-user 0.2.0; data line unchanged; CCA opens after Finish. |
| 6 | Path B, per-user | `cca-reset.ps1 -Scope currentuser` (elevated), then path B from a normal PowerShell. | Per-user 0.2.0; data unchanged; no `running:` line (CCA does not start). |
| 7 | Path A, per-user | `cca-reset.ps1 -Scope currentuser` (elevated), then path A from a normal PowerShell. Click Finish. | **No** "Choose Installation Options" page and no UAC prompt; it goes straight to the progress page. Per-user 0.2.0; data unchanged; after Finish one `running:` line from the per-user folder, `args=[--updated]`. |
| 8 | Path B, all users | `cca-reset.ps1 -Scope allusers` (elevated), then path B from a normal PowerShell. Answer the UAC prompt with *Yes*. | One UAC prompt. All-users 0.2.0; no `HKCU:` line; data unchanged; CCA does not start. |
| 9 | Path A, all users | `cca-reset.ps1 -Scope allusers` (elevated), then path A from a normal PowerShell. UAC: *Yes*. Click Finish. | One UAC prompt at the start, then **no** options page. All-users 0.2.0; after Finish CCA runs from Program Files with `parent=explorer.exe`. In Task Manager → Details, the "Elevated" column for `Claude Accounts.exe` says **No**. |
| 10 | Clean up | `cca-reset.ps1 -Scope none` (elevated). | Nothing installed. You can delete the VM. |

Command for test 3:

```powershell
$shim = "$env:LOCALAPPDATA\Programs\Claude Accounts\resources\app.asar.unpacked\main\cca-shim.ps1"
(Measure-Command { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $shim list --json | Out-Null }).TotalSeconds
```

If anything differs from "Expected", stop at that test, take a screenshot, keep the `cca-check.ps1` output, and report it. Do not try to fix it in the VM.

## What to send back

- Windows edition and version, and the `os:` line from `cca-check.ps1` (it must say `arch=AMD64`).
- For each test: PASS or FAIL, plus the `cca-check.ps1` output.
- Screenshots: SmartScreen (test 1), the options page (tests 1 and 5), and anything unexpected.
- The seconds from test 3, and whether "list failed: timed out" appeared.
- The VM tool you used and its CPU and memory settings.

Only the test accounts `demo-work` and `demo-personal` should appear. Do not include real account names, tokens or personal paths.

## What these tests do not cover

- The full download by the app's own updater from GitHub. There is no 0.2.0 release yet; the tests start the installer with the same arguments the updater uses.
- A machine with both a per-user and an all-users copy installed. The installer then still shows the options page; that is a known limitation.
- Installing v0.1.12 over 0.2.0 (rollback).

**For the maintainers (not part of these tests):** the check that electron-builder's NSIS template still calls the scope hook (`desktop/test/nsis-update-mode.test.js`, last test) was skipped in CI at first. CI now installs `desktop/node_modules` and runs it.
