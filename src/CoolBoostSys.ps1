# CoolBoost Auto - background worker (runs as SYSTEM via scheduled tasks)
# CoolBoost is read/set through Acer's ACPI WMI interface APGeAction (GetFunction 0x207 / SetFunction (state<<16)|7),
# the same call NitroSense uses. Command found thanks to the OpenPredator project (MIT): https://github.com/KRWCLASSIC/OpenPredator
# MIT License
param([ValidateSet('auto','toggle','on','off')][string]$Mode='auto')
$ErrorActionPreference='Stop'
$dir="$env:ProgramFiles\CoolBoostAuto"; $saved="$dir\saved_state.txt"; $log="$dir\CoolBoostAuto.log"; $lastPwr="$dir\last_power.txt"
$cfgPath="$env:ProgramData\CoolBoostAuto\settings.json"
function Log($m){ "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $log -Append -Encoding utf8 }
if ((Test-Path $log) -and (Get-Item $log).Length -gt 200KB) { Get-Content $log -Tail 300 | Set-Content $log }
function Get-Cfg {
  $c=@{offOnBattery=$true; onPlugIn='restore'}
  try {
    $j=Get-Content $cfgPath -Raw | ConvertFrom-Json
    if ($j.offOnBattery -is [bool]) { $c.offOnBattery=$j.offOnBattery }
    if ($j.onPlugIn -is [string] -and $j.onPlugIn -in 'restore','on','off','keep') { $c.onPlugIn=$j.onPlugIn }
  } catch {}
  $c
}
$mtx=New-Object Threading.Mutex($false,'Global\CoolBoostAutoSys'); [void]$mtx.WaitOne(15000)
try {
  $ap=Get-CimInstance -Namespace root\WMI -ClassName APGeAction
  function Get-CB { [int]((((Invoke-CimMethod -InputObject $ap -MethodName GetFunction -Arguments @{uiInput=[uint32]0x207}).uiOutput) -shr 8) -band 0xFF) }
  function Set-CB([int]$v){
    [void](Invoke-CimMethod -InputObject $ap -MethodName SetFunction -Arguments @{uiInput=[uint64](([uint64]$v -shl 16) -bor 7)})
    # keep NitroSense's own setting in sync so its app (and the tray icon) show the right state
    $nk='HKLM:\SOFTWARE\OEM\NitroSense\FanControl'; if (Test-Path $nk) { Set-ItemProperty $nk -Name CoolBoostMode -Value $v -Type DWord }
    Start-Sleep -Milliseconds 300; return ((Get-CB) -eq $v)
  }
  $cur=Get-CB
  switch($Mode){
    'toggle' { $ok=Set-CB (1-$cur); Log "Manual toggle: $cur -> $(1-$cur) (ok=$ok)"; return }
    'on'     { $ok=Set-CB 1; Log "Manual: ON (ok=$ok)"; return }
    'off'    { $ok=Set-CB 0; Log "Manual: OFF (ok=$ok)"; return }
  }
  Start-Sleep 2
  $cfg=Get-Cfg
  $onAC=$true; try { $onAC=[bool](Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus | Select -First 1).PowerOnline } catch {}
  $prevPwr = if (Test-Path $lastPwr) { (Get-Content $lastPwr -Raw).Trim() } else { '' }
  Set-Content $lastPwr ($(if($onAC){'ac'}else{'battery'}))
  if (-not $onAC) {
    if (-not $cfg.offOnBattery) { return }
    if ($cur -eq 1) { Set-Content $saved '1'; $ok=Set-CB 0; Log "Battery: CoolBoost was ON -> OFF (ok=$ok)" }
    elseif (-not (Test-Path $saved)) { Set-Content $saved '0'; Log 'Battery: CoolBoost already OFF (remembered OFF)' }
  } else {
    $pluggedIn = ($prevPwr -eq 'battery') -or (Test-Path $saved)
    if (-not $pluggedIn) { return }
    $prev = if (Test-Path $saved) { [int](Get-Content $saved -Raw).Trim() } else { $cur }
    switch ($cfg.onPlugIn) {
      'restore' { if ($prev -ne $cur) { $ok=Set-CB $prev; Log "Plugged in: restored previous state $prev (ok=$ok)" } else { Log "Plugged in: already at previous state $prev" } }
      'on'      { if ($cur -ne 1) { $ok=Set-CB 1; Log "Plugged in: rule 'always ON' -> ON (ok=$ok)" } }
      'off'     { if ($cur -ne 0) { $ok=Set-CB 0; Log "Plugged in: rule 'always OFF' -> OFF (ok=$ok)" } }
      'keep'    { Log "Plugged in: rule 'leave as is' (CoolBoost=$cur)" }
    }
    if (Test-Path $saved) { Remove-Item $saved -Force }
  }
} catch { Log "ERROR: $_" } finally { try{$mtx.ReleaseMutex()}catch{} }
