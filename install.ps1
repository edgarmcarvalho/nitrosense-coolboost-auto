#Requires -Version 5.1
<#
.SYNOPSIS
  Installs CoolBoost Auto: automatic, context-based NitroSense CoolBoost switching + tray icon.
.DESCRIPTION
  - Checks that this laptop exposes Acer's CoolBoost control (ACPI WMI class APGeAction).
  - Installs the background worker to "Program Files\CoolBoostAuto" (admin-only) and the
    tray icon to "ProgramData\CoolBoostAuto".
  - Registers 4 scheduled tasks that run the worker as SYSTEM:
      CoolBoostAuto   - on power plug/unplug, at startup and after waking from sleep
      CoolBoostToggle - toggle  (runnable by normal users, used by the tray icon)
      CoolBoostOn     - set ON  (idem)
      CoolBoostOff    - set OFF (idem)
  - Adds "CoolBoost Auto" to the Start menu and (unless -NoAutostart) to Startup.
  Re-running it upgrades an existing install and keeps your settings.
.PARAMETER NoAutostart
  Don't start the tray icon automatically at login.
.PARAMETER Force
  Install even if the compatibility checks fail. Not recommended.
.PARAMETER Quiet
  Don't wait for Enter at the end.
.PARAMETER NoStartTray
  Don't start the tray icon at the end (the setup wizard starts it itself).
.PARAMETER CheckOnly
  Only run the compatibility checks. Exit code 0 = supported, 2 = CoolBoost interface missing/unsupported, 3 = NitroSense missing.
.PARAMETER LogPath
  Also write everything to this log file.
#>
[CmdletBinding()]
param([switch]$NoAutostart, [switch]$Force, [switch]$Quiet, [switch]$NoStartTray, [switch]$CheckOnly, [string]$LogPath)
$ErrorActionPreference = 'Stop'

# ---------- self-elevate ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
  if ($NoAutostart) { $a += '-NoAutostart' }; if ($Force) { $a += '-Force' }; if ($Quiet) { $a += '-Quiet' }
  if ($NoStartTray) { $a += '-NoStartTray' }; if ($CheckOnly) { $a += '-CheckOnly' }; if ($LogPath) { $a += '-LogPath', "`"$LogPath`"" }
  Start-Process powershell.exe -Verb RunAs -ArgumentList $a
  return
}

function Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m" -ForegroundColor Green }
function Done($code) { if ($LogPath) { try { Stop-Transcript | Out-Null } catch {} }; if (-not $Quiet) { Read-Host "`nPress Enter to close" | Out-Null }; exit $code }
function Fail($m, $code = 1) { Write-Host "`nERROR: $m" -ForegroundColor Red; Done $code }
if ($LogPath) { try { Start-Transcript -Path $LogPath -Force | Out-Null } catch {} }

$src = Join-Path $PSScriptRoot 'src'
$PF  = Join-Path $env:ProgramFiles 'CoolBoostAuto'
$PD  = Join-Path $env:ProgramData  'CoolBoostAuto'
$assets = Join-Path $PSScriptRoot 'assets'
$icons = 'app.ico', 'tray_on.ico', 'tray_off.ico', 'tray_on_game.ico', 'tray_off_game.ico'

Write-Host "`nCoolBoost Auto installer`n" -ForegroundColor White

# ---------- compatibility ----------
Step 'Checking that this laptop supports CoolBoost control'
try {
  $ap = Get-CimInstance -Namespace root\WMI -ClassName APGeAction -ErrorAction Stop | Select-Object -First 1
  $r  = [uint64](Invoke-CimMethod -InputObject $ap -MethodName GetFunction -Arguments @{ uiInput = [uint32]0x207 }).uiOutput
} catch { $ap = $null; $r = $null }
if (-not $ap) {
  if (-not $Force) { Fail "Acer's CoolBoost interface (WMI class APGeAction) was not found. This tool only works on Acer Nitro / Predator laptops that have it." 2 }
  Write-Warning 'APGeAction not found - continuing because of -Force.'
} elseif (($r -band 0xFF) -ne 0) {
  if (-not $Force) { Fail ("The CoolBoost status query returned an error (0x{0:X}). This model doesn't seem to support CoolBoost through this interface." -f $r) 2 }
  Write-Warning ('CoolBoost query returned 0x{0:X} - continuing because of -Force.' -f $r)
} else {
  Ok ("Supported. CoolBoost is currently {0}." -f $(if ((($r -shr 8) -band 0xFF) -eq 1) { 'ON' } else { 'OFF' }))
}

Step 'Checking for NitroSense'
if (Test-Path 'HKLM:\SOFTWARE\OEM\NitroSense\FanControl') { Ok 'NitroSense found.' }
elseif ($Force) { Write-Warning "NitroSense settings not found - the tray icon won't be able to show CoolBoost's state." }
else { Fail "NitroSense doesn't seem to be installed (its settings key is missing). Install NitroSense from the Microsoft Store / Acer support first." 3 }
if ($CheckOnly) { Done 0 }

$files = @(Join-Path $src 'CoolBoostSys.ps1'; Join-Path $src 'CoolBoostTray.ps1'; Join-Path $src 'Start CoolBoost Auto.vbs') + ($icons | ForEach-Object { Join-Path $assets $_ })
foreach ($f in $files) { if (-not (Test-Path $f)) { Fail "Missing file $f - extract the whole download before running install.ps1." } }

# ---------- stop a running tray icon (upgrade) ----------
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'CoolBoostTray\.ps1' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# ---------- files + permissions ----------
Step 'Installing files'
New-Item -ItemType Directory -Force -Path $PF, $PD | Out-Null
Copy-Item (Join-Path $src 'CoolBoostSys.ps1') $PF -Force
foreach ($f in 'CoolBoostTray.ps1', 'Start CoolBoost Auto.vbs') { Copy-Item (Join-Path $src $f) $PD -Force }
foreach ($f in $icons) { Copy-Item (Join-Path $assets $f) $PD -Force }
# files from older versions
Remove-Item (Join-Path $PD 'CoolBoostIcon.ps1'), (Join-Path $PD 'CoolBoostApp.ico'), (Join-Path $PD 'Start CoolBoost Tray.vbs') -Force -ErrorAction SilentlyContinue
Get-ChildItem $PF, $PD -File | Unblock-File

$sidAdmins = New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544'
$sidSystem = New-Object Security.Principal.SecurityIdentifier 'S-1-5-18'
$sidUsers  = New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-545'
$sidOwner  = New-Object Security.Principal.SecurityIdentifier 'S-1-3-0'
$CIOI = [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
$none = [Security.AccessControl.PropagationFlags]::None
function Rule($sid, $rights, $inh = $CIOI, $prop = $none) { New-Object Security.AccessControl.FileSystemAccessRule($sid, $rights, $inh, $prop, 'Allow') }

# ProgramData folder: admins/SYSTEM full; users read + may create their own files (the tray log);
# scripts stay admin-owned so other accounts can't change them.
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetOwner($sidAdmins); $acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule((Rule $sidSystem 'FullControl'))
$acl.AddAccessRule((Rule $sidAdmins 'FullControl'))
$acl.AddAccessRule((Rule $sidUsers  'ReadAndExecute'))
$acl.AddAccessRule((Rule $sidUsers  'CreateFiles,AppendData' ([Security.AccessControl.InheritanceFlags]::None)))
$acl.AddAccessRule((Rule $sidOwner  'FullControl' $CIOI ([Security.AccessControl.PropagationFlags]::InheritOnly)))
Set-Acl $PD $acl
foreach ($f in Get-ChildItem $PD -File) {
  $fa = New-Object Security.AccessControl.FileSecurity; $fa.SetOwner($sidAdmins); $fa.SetAccessRuleProtection($false, $false)
  Set-Acl $f.FullName $fa
}
# settings + tray log must stay writable by the user running the tray icon
$settings = Join-Path $PD 'settings.json'
if (-not (Test-Path $settings)) {
  '{"offOnBattery":true,"onPlugIn":"restore","gameMode":true,"gamesInclude":[],"gamesExclude":[]}' | Set-Content $settings -Encoding UTF8
}
foreach ($w in $settings, (Join-Path $PD 'tray.log')) {
  if (-not (Test-Path $w)) { New-Item -ItemType File -Path $w | Out-Null }
  $fa = Get-Acl $w; $fa.AddAccessRule((Rule $sidUsers 'Modify' ([Security.AccessControl.InheritanceFlags]::None))); Set-Acl $w $fa
}
Ok "Worker:    $PF (admin-only)"
Ok "Tray icon: $PD"


# ---------- scheduled tasks ----------
Step 'Registering scheduled tasks'
$worker = Join-Path $PF 'CoolBoostSys.ps1'
function Act($mode) { New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$worker`" -Mode $mode" }
$settingsSet = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances Queue
$system      = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$evClass     = Get-CimClass -Namespace Root/Microsoft/Windows/TaskScheduler -ClassName MSFT_TaskEventTrigger
function EventTrigger($provider, $id) {
  $t = New-CimInstance -CimClass $evClass -ClientOnly; $t.Enabled = $true
  $t.Subscription = "<QueryList><Query Id=`"0`" Path=`"System`"><Select Path=`"System`">*[System[Provider[@Name='$provider'] and EventID=$id]]</Select></Query></QueryList>"
  $t
}
$powerChange = EventTrigger 'Microsoft-Windows-Kernel-Power' 105          # power source changed
$wake        = EventTrigger 'Microsoft-Windows-Power-Troubleshooter' 1    # resumed from sleep
$boot        = New-ScheduledTaskTrigger -AtStartup; $boot.Delay = 'PT45S'
Register-ScheduledTask -TaskName 'CoolBoostAuto' -Action (Act 'auto') -Trigger @($powerChange, $boot, $wake) -Settings $settingsSet -Principal $system `
  -Description 'CoolBoost Auto: CoolBoost rules on plug/unplug, startup and wake' -Force | Out-Null
$svc = New-Object -ComObject Schedule.Service; $svc.Connect()
foreach ($m in 'Toggle', 'On', 'Off') {
  $name = "CoolBoost$m"
  Register-ScheduledTask -TaskName $name -Action (Act $m.ToLower()) -Settings $settingsSet -Principal $system `
    -Description "CoolBoost Auto: CoolBoost $($m.ToLower()) (used by the tray icon)" -Force | Out-Null
  # let normal (non-admin) users run this one task, so the tray icon needs no UAC prompt
  $t = $svc.GetFolder('\').GetTask($name); $sd = $t.GetSecurityDescriptor(4)
  if ($sd -notmatch ';;;AU\)') { $t.SetSecurityDescriptor(($sd -replace '(D:[A-Z]*)', '$1(A;;GRGX;;;AU)'), 0) }
}
Ok 'CoolBoostAuto, CoolBoostToggle, CoolBoostOn, CoolBoostOff'

# ---------- shortcuts ----------
Step 'Creating shortcuts'
$sh = New-Object -ComObject WScript.Shell
function Lnk($path) {
  $l = $sh.CreateShortcut($path)
  $l.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
  $l.Arguments = "`"$(Join-Path $PD 'Start CoolBoost Auto.vbs')`""
  $l.WorkingDirectory = $PD; $l.IconLocation = "$(Join-Path $PD 'app.ico'),0"; $l.Description = 'CoolBoost Auto - automatic CoolBoost control'
  $l.Save()
}
$commonPrograms = [Environment]::GetFolderPath('CommonPrograms')
$commonStartup  = [Environment]::GetFolderPath('CommonStartup')
# remove shortcuts left by older versions ("CoolBoost Tray") and per-user/manual installs, to avoid duplicates
foreach ($d in [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Startup')) {
  Get-ChildItem $d -Filter '*CoolBoost*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force
}
foreach ($d in $commonPrograms, $commonStartup) { Remove-Item (Join-Path $d 'CoolBoost Tray.lnk') -Force -ErrorAction SilentlyContinue }
$startLnk = Join-Path $commonPrograms 'CoolBoost Auto.lnk'
Lnk $startLnk; Ok 'Start menu: CoolBoost Auto'
$autoLnk = Join-Path $commonStartup 'CoolBoost Auto.lnk'
if ($NoAutostart) { Remove-Item $autoLnk -Force -ErrorAction SilentlyContinue; Ok 'Autostart: off' } else { Lnk $autoLnk; Ok 'Autostart at login: on' }

# ---------- start the tray icon as the normal (non-admin) user ----------
if (-not $NoStartTray) {
  Step 'Starting CoolBoost Auto'
  Start-Process explorer.exe -ArgumentList "`"$startLnk`""
  Ok 'Look for the red fan icon next to the clock (it may be under the ^ arrow).'
}

Write-Host "`nCoolBoost Auto is installed. Right-click its tray icon for options. To remove: run uninstall.ps1." -ForegroundColor Green
Done 0
