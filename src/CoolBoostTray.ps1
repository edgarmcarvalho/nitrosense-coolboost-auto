# CoolBoost Auto - tray icon (runs as the logged-in user)
# https://github.com/edgarmcarvalho/nitrosense-coolboost-auto  -  MIT License
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -Namespace CB -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][CB.Dpi]::SetProcessDPIAware()
$mtx = New-Object Threading.Mutex($false,'Local\CoolBoostTray')
if (-not $mtx.WaitOne(0)) { exit }
$regPath   = 'HKLM:\SOFTWARE\OEM\NitroSense\FanControl'
$cfgPath   = "$env:ProgramData\CoolBoostAuto\settings.json"
$savedPath = "$env:ProgramFiles\CoolBoostAuto\saved_state.txt"

# ---------- settings ----------
function Get-CB { try { [int](Get-ItemProperty $regPath).CoolBoostMode } catch { -1 } }
function Get-Cfg {
  $c=[ordered]@{offOnBattery=$true; onPlugIn='restore'; gameMode=$true; gamesInclude=@(); gamesExclude=@()}
  try {
    $j=Get-Content $cfgPath -Raw | ConvertFrom-Json
    if ($j.offOnBattery -is [bool]) { $c.offOnBattery=$j.offOnBattery }
    if ($j.onPlugIn -is [string] -and $j.onPlugIn -in 'restore','on','off','keep') { $c.onPlugIn=$j.onPlugIn }
    if ($j.gameMode -is [bool]) { $c.gameMode=$j.gameMode }
    if ($j.gamesInclude) { $c.gamesInclude=@($j.gamesInclude | % { [string]$_ }) }
    if ($j.gamesExclude) { $c.gamesExclude=@($j.gamesExclude | % { [string]$_ }) }
  } catch {}
  $c
}
function Save-Cfg($c){ ConvertTo-Json -InputObject $c -Compress | Set-Content $cfgPath -Encoding UTF8; $script:cfg=$c; $script:last='' }
function Set-Cfg($key,$val){ $c=Get-Cfg; $c[$key]=$val; Save-Cfg $c }
function Restore-Pending { try { (Test-Path $savedPath) -and ((Get-Content $savedPath -Raw).Trim() -eq '1') } catch { $false } }
function On-AC { [Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -ne 'Offline' }
$script:cfg = Get-Cfg

# ---------- game detection ----------
$script:winGames=@{}; $script:roots=@(); $script:winAt=[datetime]::MinValue; $script:rootsAt=[datetime]::MinValue
$helperRx = '(?i)^(unins.*|.*crash.*|.*report.*|support|setup.*|install.*|.*launcher.*|.*updater.*|.*helper.*|vc_?redist.*|dxsetup|.*prereq.*|easyanticheat.*|beservice.*|battleye.*|.*console.*|perf_graph.*|.*benchmark.*|.*config.*|.*settings.*|cefprocess)\.exe$'
function Refresh-Sources {
  $now=Get-Date
  if (($now-$script:winAt).TotalSeconds -gt 60) {
    $h=@{}
    Get-ChildItem 'HKCU:\System\GameConfigStore\Children' -EA SilentlyContinue | % { $p=(Get-ItemProperty $_.PSPath -EA SilentlyContinue).MatchedExeFullPath; if($p){ $h[$p.ToLower()]=1 } }
    $script:winGames=$h; $script:winAt=$now
  }
  if (($now-$script:rootsAt).TotalMinutes -gt 5) {
    $r=@()
    try {
      $sp=(Get-ItemProperty 'HKCU:\Software\Valve\Steam' -EA Stop).SteamPath -replace '/','\'
      $libs=@($sp)
      $vdf=Join-Path $sp 'steamapps\libraryfolders.vdf'
      if (Test-Path $vdf) { $libs += [regex]::Matches((Get-Content $vdf -Raw),'"path"\s+"([^"]+)"') | % { $_.Groups[1].Value -replace '\\\\','\' } }
      $r += $libs | Select -Unique | % { (Join-Path $_ 'steamapps\common\').ToLower() }
    } catch {}
    foreach($rk in "$env:ProgramFiles\Rockstar Games\","${env:ProgramFiles(x86)}\Rockstar Games\"){ if(Test-Path $rk){ $r += $rk.ToLower() } }
    $script:roots=$r; $script:rootsAt=$now
  }
}
function Test-Game([string]$path){
  if (-not $path) { return $false }
  $p=$path.ToLower()
  if ($script:cfg.gamesExclude | ? { $_.ToLower() -eq $p }) { return $false }
  if ($script:cfg.gamesInclude | ? { $_.ToLower() -eq $p }) { return $true }
  if ($script:winGames.ContainsKey($p)) { return $true }
  foreach($r in $script:roots){
    if ($p.StartsWith($r)) {
      if ($p -match '\\rockstar games\\(launcher|social club)\\') { return $false }
      if ((Split-Path $p -Leaf) -match $helperRx) { return $false }
      return $true
    }
  }
  $false
}
function Get-Name([string]$path){
  try { $fv=(Get-Item $path).VersionInfo; foreach($n in $fv.ProductName,$fv.FileDescription){ if($n -and $n.Trim().Length -gt 1){ return $n.Trim() } } } catch {}
  [IO.Path]::GetFileNameWithoutExtension($path)
}
if (-not ('CB.ProcPaths' -as [type])) {
Add-Type -Namespace CB -Name ProcPaths -UsingNamespace System.Text,System.Collections.Generic -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool QueryFullProcessImageNameW(IntPtr h, int flags, StringBuilder buf, ref int size);
[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
// PROCESS_QUERY_LIMITED_INFORMATION works for elevated processes too, no admin needed
public static string GetPath(int pid) {
  IntPtr h = OpenProcess(0x1000, false, pid);
  if (h == IntPtr.Zero) return null;
  try { var sb = new StringBuilder(1024); int n = sb.Capacity; return QueryFullProcessImageNameW(h, 0, sb, ref n) ? sb.ToString() : null; }
  finally { CloseHandle(h); }
}
public static string[] GetAll() {
  var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach (var p in System.Diagnostics.Process.GetProcesses()) { try { var s = GetPath(p.Id); if (s != null) set.Add(s); } catch {} finally { p.Dispose(); } }
  var arr = new string[set.Count]; set.CopyTo(arr); return arr;
}
'@
}
function Get-RunningGames {
  Refresh-Sources
  @([CB.ProcPaths]::GetAll() | ? { Test-Game $_ })
}

# ---------- switching ----------
$script:busy=$false; $script:proc=$null; $script:until=Get-Date; $script:startCB=-1
$script:ourCmdUntil=[datetime]::MinValue
function Run-Task($name){
  $script:busy=$true; $ni.Text="CoolBoost Auto`nswitching..."
  $script:startCB=Get-CB
  $script:proc=Start-Process schtasks.exe -WindowStyle Hidden -PassThru -ArgumentList "/run /tn $name"
  $script:until=(Get-Date).AddSeconds(6); $script:ourCmdUntil=(Get-Date).AddSeconds(10)
}
function Do-Toggle {
  if ($script:busy) { return }
  if ($script:gs.active) { $script:gs.override=$true; TLog 'Manual toggle during game - automation paused until it closes' }
  Run-Task 'CoolBoostToggle'
}

# ---------- gaming state machine ----------
function New-GS { @{active=$false; preGame=-1; weTurnedOn=$false; override=$false; name=''; paths=@()} }
$script:gs=New-GS
$script:lastAC=On-AC; $script:powerAt=Get-Date; $script:prevCB=Get-CB; $script:scanAt=[datetime]::MinValue
function TLog($m){ try { $lp="$env:ProgramData\CoolBoostAuto\tray.log"; if ((Test-Path $lp) -and (Get-Item $lp).Length -gt 100KB) { Get-Content $lp -Tail 200 | Set-Content $lp }; "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $lp -Append -Encoding utf8 } catch {} }
$script:pendingOff=$false
function Game-Tick {
  $now=Get-Date; $ac=On-AC
  if ($ac -ne $script:lastAC) { $script:lastAC=$ac; $script:powerAt=$now }
  $cb=Get-CB
  $quiet = ($now -gt $script:ourCmdUntil) -and (($now-$script:powerAt).TotalSeconds -gt 10)

  if (($now-$script:scanAt).TotalSeconds -ge 4) {
    $script:scanAt=$now
    $games = if ($script:cfg.gameMode) { @(Get-RunningGames) } else { @() }
    if ($games.Count -gt 0 -and -not $script:gs.active) {
      $script:pendingOff=$false
      $script:gs=@{active=$true; preGame=$cb; weTurnedOn=$false; override=$false; name=(Get-Name $games[0]); paths=$games}
      TLog "Game started: $($script:gs.name) [$($games -join '; ')] CoolBoost=$cb AC=$ac"
      $script:last=''
    } elseif ($games.Count -eq 0 -and $script:gs.active) {
      $revert = $script:gs.weTurnedOn -and -not $script:gs.override -and $script:gs.preGame -eq 0
      TLog "Game closed: $($script:gs.name) (revert to OFF: $revert)"
      if ($revert) { $script:pendingOff=$true }
      $script:gs=New-GS; $script:last=''
    } elseif ($script:gs.active) { $script:gs.paths=$games }
  }

  if ($script:pendingOff -and -not $script:busy) {
    $script:pendingOff=$false
    if ((Get-CB) -eq 1) { TLog 'Turning CoolBoost OFF (back to pre-game state)'; Run-Task 'CoolBoostOff' }
    $script:prevCB=$cb; return
  }

  if ($script:gs.active -and -not $script:busy) {
    # user (not us, not a power change) turned it off mid-game -> respect until the game closes
    if ($script:gs.weTurnedOn -and $script:prevCB -eq 1 -and $cb -eq 0 -and $ac -and $quiet -and -not $script:gs.override) { $script:gs.override=$true; $script:last=''; TLog 'Manual change during game - automation paused until it closes' }
    elseif (-not $script:gs.override -and $ac -and $cb -eq 0 -and $quiet) { $script:gs.weTurnedOn=$true; TLog "Turning CoolBoost ON for $($script:gs.name)"; Run-Task 'CoolBoostOn' }
  }
  $script:prevCB=$cb
}

# ---------- icon ----------
$traySz = [Math]::Max(16, [Windows.Forms.SystemInformation]::SmallIconSize.Width)
# icons ship as multi-size .ico files; Windows picks the frame for the tray's real size
function Load-Icon($name) {
  try { New-Object Drawing.Icon("$env:ProgramData\CoolBoostAuto\$name.ico", $traySz, $traySz) } catch { [Drawing.SystemIcons]::Application }
}
$icons=@{ '1True'=(Load-Icon 'tray_on_game'); '1False'=(Load-Icon 'tray_on'); '0True'=(Load-Icon 'tray_off_game'); '0False'=(Load-Icon 'tray_off') }
$ni = New-Object Windows.Forms.NotifyIcon
$ni.Icon = $icons['0False']; $ni.Visible = $true
$script:last=''
function Refresh {
  $cb=Get-CB; $pend=Restore-Pending; $c=$script:cfg
  $key="$cb|$pend|$($c.onPlugIn)|$($c.offOnBattery)|$($script:gs.active)|$($script:gs.override)|$($script:gs.name)"
  if ($key -eq $script:last) { return }
  $script:last=$key
  $ni.Icon = $icons["$([int]($cb -eq 1))$([bool]$script:gs.active)"]
  $t = switch ($cb) { 1 {'CoolBoost ON'} 0 {'CoolBoost OFF'} default {'CoolBoost ?'} }
  if ($script:gs.active) { $t += " | Gaming: $($script:gs.name)"; if ($script:gs.override) { $t += ' (manual)' } }
  else {
    $plug = switch ($c.onPlugIn) { 'on' {'ON'} 'off' {'OFF'} 'keep' {'unchanged'} default { if ($pend) {'ON (restore)'} else {'previous'} } }
    $t += " | plug-in: $plug"
  }
  $t = "CoolBoost Auto`n$t"
  if ($t.Length -gt 63) { $t=$t.Substring(0,60)+'...' }
  $ni.Text=$t
}

# ---------- menu ----------
function New-MenuItem($text,$onClick){ $m=New-Object Windows.Forms.ToolStripMenuItem $text; if($onClick){ $m.add_Click($onClick) }; $m }
function Add-Include($path){ $cf=Get-Cfg; $cf.gamesInclude=@(@($cf.gamesInclude) + $path | Select -Unique); $cf.gamesExclude=@($cf.gamesExclude | ? { $_ -ne $path }); Save-Cfg $cf; $script:scanAt=[datetime]::MinValue }
function Add-Exclude($path){ $cf=Get-Cfg; $cf.gamesExclude=@(@($cf.gamesExclude) + $path | Select -Unique); $cf.gamesInclude=@($cf.gamesInclude | ? { $_ -ne $path }); Save-Cfg $cf; $script:scanAt=[datetime]::MinValue }
$menu = New-Object Windows.Forms.ContextMenuStrip
$miToggle = New-MenuItem 'Toggle CoolBoost' { Do-Toggle }
$miToggle.Font = New-Object Drawing.Font($miToggle.Font, [Drawing.FontStyle]::Bold)
$miStatus = New-MenuItem 'status' $null; $miStatus.Enabled=$false
[void]$menu.Items.Add($miToggle); [void]$menu.Items.Add($miStatus); [void]$menu.Items.Add('-')

$miAuto = New-MenuItem 'Automation' $null
$miOff = New-MenuItem 'Turn off on battery' { Set-Cfg 'offOnBattery' (-not $script:cfg.offOnBattery) }
$miPlugHdr = New-MenuItem 'When plugged in:' $null; $miPlugHdr.Enabled=$false
$plugItems=[ordered]@{ restore='Restore previous state'; on='Always turn ON'; off='Always turn OFF'; keep='Leave it as it is' }
$plugMenu=@{}
foreach($k in $plugItems.Keys){ $it=New-MenuItem ('    '+$plugItems[$k]) { param($s,$e) Set-Cfg 'onPlugIn' ([string]$s.Tag) }; $it.Tag=$k; $plugMenu[$k]=$it }
$miGame = New-MenuItem 'Turn ON while gaming' { Set-Cfg 'gameMode' (-not $script:cfg.gameMode) }
$miMark = New-MenuItem 'Mark a running app as a game' $null
$miUnmark = New-MenuItem 'Stop treating as a game' $null
[void]$miAuto.DropDownItems.Add($miOff)
[void]$miAuto.DropDownItems.Add((New-Object Windows.Forms.ToolStripSeparator))
[void]$miAuto.DropDownItems.Add($miPlugHdr)
foreach($k in $plugItems.Keys){ [void]$miAuto.DropDownItems.Add($plugMenu[$k]) }
[void]$miAuto.DropDownItems.Add((New-Object Windows.Forms.ToolStripSeparator))
[void]$miAuto.DropDownItems.Add($miGame)
[void]$miAuto.DropDownItems.Add($miMark)
[void]$miAuto.DropDownItems.Add($miUnmark)
[void]$menu.Items.Add($miAuto); [void]$menu.Items.Add('-')
function Open-NitroSense {
  # NitroSense / PredatorSense package names differ between models and versions, so look it up
  $pkg = Get-AppxPackage -Name 'AcerIncorporated.*' -EA SilentlyContinue | ? { $_.Name -match 'NitroSense|PredatorSense' } | Select -First 1
  if (-not $pkg) { return }
  $appId = 'App'; try { $appId = @((Get-AppxPackageManifest $pkg).Package.Applications.Application)[0].Id } catch {}
  Start-Process "shell:AppsFolder\$($pkg.PackageFamilyName)!$appId"
}
[void]$menu.Items.Add((New-MenuItem 'Open NitroSense' { Open-NitroSense }))
[void]$menu.Items.Add((New-MenuItem 'Open log' { Start-Process notepad "$env:ProgramFiles\CoolBoostAuto\CoolBoostAuto.log" }))
[void]$menu.Items.Add('-')
[void]$menu.Items.Add((New-MenuItem 'Exit tray icon' { $ni.Visible=$false; [Windows.Forms.Application]::Exit() }))

$skipProc='(?i)^(explorer|applicationframehost|textinputhost|systemsettings|shellexperiencehost|startmenuexperiencehost|searchhost|lockapp|powershell|pwsh|conhost|windowsterminal|nitrosense|predatorsense)$'
$menu.add_Opening({
  $c=$script:cfg; $cb=Get-CB
  $miToggle.Text = if ($cb -eq 1) { 'Turn CoolBoost OFF' } else { 'Turn CoolBoost ON' }
  $miStatus.Text = if ($script:gs.active) { "Gaming: $($script:gs.name)" + $(if($script:gs.override){' (manual control)'}else{''}) } else { 'No game running' }
  $miOff.Checked=$c.offOnBattery
  foreach($k in $plugMenu.Keys){ $plugMenu[$k].Checked=($k -eq $c.onPlugIn) }
  $miGame.Checked=$c.gameMode
  # mark: open-window apps not already detected as games
  $miMark.DropDownItems.Clear(); $seen=@{}
  foreach($p in (Get-Process -EA SilentlyContinue | ? { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -and $_.ProcessName -notmatch $skipProc })){
    $path=[CB.ProcPaths]::GetPath($p.Id)
    if (-not $path -or $seen.ContainsKey($path) -or (Test-Game $path)) { continue }
    $seen[$path]=1
    $title=$p.MainWindowTitle; if($title.Length -gt 45){ $title=$title.Substring(0,42)+'...' }
    $it=New-MenuItem "$title  ($($p.ProcessName).exe)" { param($s,$e) Add-Include ([string]$s.Tag) }
    $it.Tag=$path; [void]$miMark.DropDownItems.Add($it)
  }
  if ($miMark.DropDownItems.Count -eq 0) { $x=New-MenuItem '(no open apps to add)' $null; $x.Enabled=$false; [void]$miMark.DropDownItems.Add($x) }
  # unmark: running games + manually added ones
  $miUnmark.DropDownItems.Clear()
  foreach($path in (@($script:gs.paths) + @($c.gamesInclude) | ? { $_ } | Select -Unique)){
    $it=New-MenuItem "$(Get-Name $path)  ($(Split-Path $path -Leaf))" { param($s,$e) Add-Exclude ([string]$s.Tag) }
    $it.Tag=$path; [void]$miUnmark.DropDownItems.Add($it)
  }
  if (@($c.gamesExclude).Count -gt 0) {
    [void]$miUnmark.DropDownItems.Add((New-Object Windows.Forms.ToolStripSeparator))
    [void]$miUnmark.DropDownItems.Add((New-MenuItem "Reset exclusions ($(@($c.gamesExclude).Count))" { $cf=Get-Cfg; $cf.gamesExclude=@(); Save-Cfg $cf; $script:scanAt=[datetime]::MinValue }))
  }
  if ($miUnmark.DropDownItems.Count -eq 0) { $x=New-MenuItem '(no games running or added)' $null; $x.Enabled=$false; [void]$miUnmark.DropDownItems.Add($x) }
})
Add-Type -Namespace CB -Name Win -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);'
$ni.add_MouseUp({ param($s,$e)
  if ($e.Button -eq 'Right') {
    [void][CB.Win]::SetForegroundWindow($menu.Handle)   # so the menu closes when clicking elsewhere
    $menu.Show([Windows.Forms.Cursor]::Position, [Windows.Forms.ToolStripDropDownDirection]::AboveLeft)
  }
})
$ni.add_MouseClick({ param($s,$e) if ($e.Button -eq 'Left') { Do-Toggle } })

# ---------- loop ----------
$timer=New-Object Windows.Forms.Timer
$timer.Interval=1500
$timer.add_Tick({
  try {
    $script:cfg=Get-Cfg
    if ($script:busy -and $script:proc -and $script:proc.HasExited -and ((Get-Date) -gt $script:until -or (Get-CB) -ne $script:startCB)) { $script:busy=$false; $script:last='' }
    Game-Tick
    if (-not $script:busy) { Refresh }
  } catch {}
})
$timer.Start()
Refresh
[Windows.Forms.Application]::Run()
$ni.Dispose(); $mtx.ReleaseMutex()






