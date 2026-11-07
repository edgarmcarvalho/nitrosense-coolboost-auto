#Requires -Version 5.1
<#
.SYNOPSIS
  CoolBoost Auto - READ-ONLY hardware check for Acer Nitro / Predator laptops.
.DESCRIPTION
  Records how this laptop reports CoolBoost, the fan table and the fan mode, so CoolBoost Auto
  can copy exactly what NitroSense / PredatorSense do on this model.

  It ONLY READS. It never changes any setting:
  - every firmware call goes through Read-Firmware, which refuses any method that does not start with "Get";
  - no registry, file or setting is written, except the report text file on your Desktop.

  It does not collect your name, user name, serial number or anything personal: only the laptop model,
  BIOS version, Windows version, Acer app versions and the firmware readings below.
.PARAMETER Step
  A label for this reading, e.g. "1-off", "2-on", "3-off", "4-custom". Asked interactively if omitted.
.PARAMETER NoPause
  Don't wait for Enter at the end.
.NOTES
  https://github.com/edgarmcarvalho/nitrosense-coolboost-auto  -  MIT License
#>
[CmdletBinding()]
param([string]$Step, [switch]$NoPause)

# ---------- run as admin (the Acer firmware interface needs it) ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
  if ($Step) { $a += '-Step', "`"$Step`"" }; if ($NoPause) { $a += '-NoPause' }
  Start-Process powershell.exe -Verb RunAs -ArgumentList $a
  return
}

if (-not $Step) {
  Write-Host "`nCoolBoost Auto - read-only hardware check`n" -ForegroundColor White
  Write-Host 'Which reading is this? Type a short label and press Enter.'
  Write-Host '  1-off     CoolBoost OFF in PredatorSense/NitroSense, fans on Auto'
  Write-Host '  2-on      CoolBoost ON'
  Write-Host '  3-off     CoolBoost OFF again'
  Write-Host '  4-custom  fans set to Custom (any speeds)'
  $Step = Read-Host 'Label'
  if (-not $Step) { $Step = 'reading' }
}
$Step = ($Step -replace '[^A-Za-z0-9_-]', '')

$lines = New-Object Collections.Generic.List[string]
function Out-Line($s) { $lines.Add([string]$s); Write-Host $s }
function Hex($v) { if ($null -eq $v) { 'n/a' } else { '0x{0:X16}' -f [uint64]$v } }

# The ONLY way this script talks to the firmware. Anything that isn't a "Get..." method is refused.
function Read-Firmware([string]$Class, [string]$Method, [uint64]$Value) {
  if ($Method -notmatch '^Get') { throw "Refused: $Method is not a read-only method" }
  $inName  = if ($Class -eq 'APGeAction') { 'uiInput' } else { 'gmInput' }
  $outName = if ($Class -eq 'APGeAction') { 'uiOutput' } else { 'gmOutput' }
  try {
    $inst = Get-CimInstance -Namespace root\WMI -ClassName $Class -ErrorAction Stop | Select-Object -First 1
    if (-not $inst) { return @{ ok = $false; text = 'class not found' } }
    $p = (Get-CimClass -Namespace root\WMI -ClassName $Class).CimClassMethods[$Method].Parameters[$inName]
    # some models take no input for some methods (e.g. GetGamingFanTable on the AN515-55)
    $args2 = if (-not $p) { @{} } elseif ($p.CimType -eq 'UInt32') { @{ $inName = [uint32]$Value } } else { @{ $inName = [uint64]$Value } }
    $r = Invoke-CimMethod -InputObject $inst -MethodName $Method -Arguments $args2 -ErrorAction Stop
    return @{ ok = $true; raw = [uint64]$r.$outName; text = (Hex $r.$outName) }
  } catch { return @{ ok = $false; text = "error: $($_.Exception.Message)" } }
}

# ---------- laptop ----------
$cs = Get-CimInstance Win32_ComputerSystem; $bios = Get-CimInstance Win32_BIOS; $os = Get-CimInstance Win32_OperatingSystem
Out-Line "=== CoolBoost Auto hardware check: $Step ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) ==="
Out-Line "Model:    $($cs.Manufacturer) $($cs.Model)  (family: $($cs.SystemFamily))"
Out-Line "BIOS:     $($bios.SMBIOSBIOSVersion)"
Out-Line "Windows:  $($os.Caption) build $($os.BuildNumber)"
Add-Type -AssemblyName System.Windows.Forms
Out-Line "Power:    $(if ([Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 'Offline') { 'on battery' } else { 'plugged in' })"
$apps = Get-AppxPackage -Name 'AcerIncorporated.*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Sense' }
Out-Line "Acer app: $(if ($apps) { ($apps | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ' } else { 'none found' })"

# ---------- what the firmware exposes (names only) ----------
Out-Line "`n--- Acer WMI classes and methods ---"
foreach ($c in Get-CimClass -Namespace root\WMI -ErrorAction SilentlyContinue | Where-Object { $_.CimClassName -match '^(APGe|AcerGaming)' }) {
  Out-Line ("{0}: {1}" -f $c.CimClassName, (($c.CimClassMethods | ForEach-Object Name) -join ', '))
}

# ---------- readings ----------
Out-Line "`n--- Readings ---"
$cb = Read-Firmware 'APGeAction' 'GetFunction' 0x0207
$cbText = if ($cb.ok -and (($cb.raw -band 0xFF) -eq 0)) { "supported, CoolBoost=$((($cb.raw -shr 8) -band 0xFF))" } elseif ($cb.ok) { 'NOT supported (status byte not 0)' } else { '' }
Out-Line "APGeAction.GetFunction(0x207)               $($cb.text)   $cbText"
$fb = Read-Firmware 'AcerGamingFunction' 'GetGamingFanBehavior' 0
$fbText = if ($fb.ok) { "status=$($fb.raw -band 0xFF) cpuMode=$((($fb.raw -shr 16) -band 3)) gpuMode=$((($fb.raw -shr 22) -band 3))  (1=auto 2=max 3=custom; status 0 = OK)" } else { '' }
Out-Line "AcerGamingFunction.GetGamingFanBehavior(0)  $($fb.text)   $fbText"
$ft = Read-Firmware 'AcerGamingFunction' 'GetGamingFanTable' 0
$ftText = if ($ft.ok) { "status=$($ft.raw -band 0xFF) table=$((($ft.raw -shr 8) -band 0xFF))  (status 0 = OK)" } else { '' }
Out-Line "AcerGamingFunction.GetGamingFanTable(0)     $($ft.text)   $ftText"
$pr = Read-Firmware 'AcerGamingFunction' 'GetGamingProfile' 0
Out-Line "AcerGamingFunction.GetGamingProfile(0)      $($pr.text)"
foreach ($s in @(@(0x0101,'CPU temp'), @(0x0201,'CPU fan rpm'), @(0x0601,'GPU fan rpm'), @(0x0501,'system fan rpm'), @(0x0A01,'GPU temp'), @(0x0301,'system temp'))) {
  $r = Read-Firmware 'AcerGamingFunction' 'GetGamingSysInfo' $s[0]
  $v = if ($r.ok) { if ($s[1] -match 'rpm') { ($r.raw -shr 8) -band 0xFFFF } else { ($r.raw -shr 8) -band 0xFF } } else { '' }
  Out-Line ("GetGamingSysInfo(0x{0:X4}) {1,-15} {2}   {3}" -f $s[0], $s[1], $r.text, $v)
}

# ---------- the Acer app's own fan settings (registry, read only) ----------
Out-Line "`n--- Acer app settings (HKLM\SOFTWARE\OEM) ---"
foreach ($k in Get-ChildItem 'HKLM:\SOFTWARE\OEM' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Sense|Predator|Nitro|Fan|Gaming' }) {
  $vals = foreach ($n in $k.GetValueNames()) { if ($n -notmatch 'serial|user|mail') { "$n=$($k.GetValue($n))" } }
  if ($vals) { Out-Line ("{0}: {1}" -f ($k.Name -replace '^HKEY_LOCAL_MACHINE', 'HKLM'), ($vals -join '; ')) }
}

# ---------- save ----------
$file = Join-Path ([Environment]::GetFolderPath('Desktop')) "CoolBoostAuto-check-$Step.txt"
$lines | Set-Content -Path $file -Encoding UTF8
try { Set-Clipboard -Value ($lines -join "`r`n") } catch {}
Write-Host "`nSaved to $file (also copied to the clipboard). Nothing on the laptop was changed." -ForegroundColor Green
if (-not $NoPause) { Read-Host "`nPress Enter to close" | Out-Null }
