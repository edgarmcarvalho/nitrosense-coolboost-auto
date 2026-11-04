#Requires -Version 5.1
<#
.SYNOPSIS
  Removes CoolBoost Auto (scheduled tasks, files, shortcuts).
.PARAMETER KeepSettings
  Keep your settings (settings.json) so a later reinstall picks them up.
.PARAMETER Quiet
  Don't wait for Enter at the end.
.NOTES
  CoolBoost itself is left in whatever state it is in; change it in NitroSense if needed.
#>
[CmdletBinding()]
param([switch]$KeepSettings, [switch]$Quiet)
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
  if ($KeepSettings) { $a += '-KeepSettings' }; if ($Quiet) { $a += '-Quiet' }
  Start-Process powershell.exe -Verb RunAs -ArgumentList $a
  return
}
function Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

$PF = Join-Path $env:ProgramFiles 'CoolBoostAuto'
$PD = Join-Path $env:ProgramData  'CoolBoostAuto'

Write-Host "`nCoolBoost Auto uninstaller`n" -ForegroundColor White

Step 'Closing CoolBoost Auto'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'CoolBoostTray\.ps1' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Step 'Removing scheduled tasks'
foreach ($t in 'CoolBoostAuto', 'CoolBoostToggle', 'CoolBoostOn', 'CoolBoostOff') {
  Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
}

Step 'Removing shortcuts'
foreach ($d in [Environment]::GetFolderPath('CommonPrograms'), [Environment]::GetFolderPath('CommonStartup'),
               [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Startup')) {
  Get-ChildItem $d -Filter '*CoolBoost*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force
}

Step 'Removing files'
Start-Sleep -Milliseconds 500
if (Test-Path $PF) { Remove-Item $PF -Recurse -Force }
if (Test-Path $PD) {
  if ($KeepSettings) { Get-ChildItem $PD -Force | Where-Object Name -ne 'settings.json' | Remove-Item -Recurse -Force }
  else { Remove-Item $PD -Recurse -Force }
}

Write-Host "`nCoolBoost Auto was uninstalled.$(if ($KeepSettings) { ' Your settings were kept.' })" -ForegroundColor Green
if (-not $Quiet) { Read-Host "`nPress Enter to close" | Out-Null }
