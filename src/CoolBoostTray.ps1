# CoolBoost Auto - tray icon (runs as the logged-in user)
# https://github.com/edgarmcarvalho/nitrosense-coolboost-auto  -  MIT License
param([switch]$Autostart)   # passed by the startup shortcut
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -Namespace CB -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][CB.Dpi]::SetProcessDPIAware()
$mtx = New-Object Threading.Mutex($false,'Local\CoolBoostTray')
if (-not $mtx.WaitOne(0)) { exit }
$cfgPath   = "$env:ProgramData\CoolBoostAuto\settings.json"
$savedPath = "$env:ProgramFiles\CoolBoostAuto\saved_state.txt"

# ---------- settings ----------
# read straight through .NET: ~35x faster than Get-ItemProperty, and this runs several times a second
function Get-CB { try { $v=[Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\OEM\NitroSense\FanControl','CoolBoostMode',$null); if ($null -eq $v) { -1 } else { [int]$v } } catch { -1 } }
function Get-Cfg {
  $c=[ordered]@{offOnBattery=$true; onPlugIn='restore'; gameMode=$true; paused=$false; startWithWindows=$true; osd=$true; gamesInclude=@(); gamesExclude=@()}
  $script:cfgReadOk=$false
  try {
    $j=Get-Content $cfgPath -Raw -EA Stop | ConvertFrom-Json -EA Stop
    if ($null -eq $j) { throw 'empty settings file' }
    $script:cfgReadOk=$true
    if ($j.offOnBattery -is [bool]) { $c.offOnBattery=$j.offOnBattery }
    if ($j.onPlugIn -is [string] -and $j.onPlugIn -in 'restore','on','off','keep') { $c.onPlugIn=$j.onPlugIn }
    if ($j.gameMode -is [bool]) { $c.gameMode=$j.gameMode }
    if ($j.paused -is [bool]) { $c.paused=$j.paused }
    if ($j.startWithWindows -is [bool]) { $c.startWithWindows=$j.startWithWindows }
    if ($j.osd -is [bool]) { $c.osd=$j.osd }
    if ($j.gamesInclude) { $c.gamesInclude=@($j.gamesInclude | % { [string]$_ }) }
    if ($j.gamesExclude) { $c.gamesExclude=@($j.gamesExclude | % { [string]$_ }) }
  } catch {}
  $c
}
# re-read settings.json only when it has changed (it's checked twice a second).
# A failed read (file half-written, locked, missing) keeps the current settings and is retried on the next check.
$script:cfgStamp = ''
function Update-Cfg {
  $fi = New-Object IO.FileInfo $cfgPath
  $stamp = if ($fi.Exists) { "$($fi.LastWriteTimeUtc.Ticks)|$($fi.Length)" } else { 'none' }
  if ($stamp -eq $script:cfgStamp) { return }
  $c = Get-Cfg
  if ($script:cfgReadOk) { $script:cfg = $c; $script:cfgStamp = $stamp; $script:last = '' }
}
function Save-Cfg($c){ ConvertTo-Json -InputObject $c -Compress | Set-Content $cfgPath -Encoding UTF8; $script:cfg=$c; $script:last='' }
# for saving: the file as it is now, or the settings in memory if it can't be read (never save defaults over it)
function Read-Cfg { $c=Get-Cfg; if ($script:cfgReadOk) { $c } else { $script:cfg } }
function Set-Cfg($key,$val){ $c=Read-Cfg; $c[$key]=$val; Save-Cfg $c; $script:cfg=$c }
function Restore-Pending { try { (Test-Path $savedPath) -and ((Get-Content $savedPath -Raw).Trim() -eq '1') } catch { $false } }
function On-AC { [Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -ne 'Offline' }
$script:cfg = Get-Cfg
if ($Autostart -and -not $script:cfg.startWithWindows) { exit }   # 'Start with Windows' is off

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
// paths already looked up, by process id (with the process name, because Windows reuses ids)
static Dictionary<int, KeyValuePair<string, string>> cache = new Dictionary<int, KeyValuePair<string, string>>();
public static string[] GetAll() {
  var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  var seen = new HashSet<int>();
  foreach (var p in System.Diagnostics.Process.GetProcesses()) {
    try {
      int id = p.Id; string name = p.ProcessName; seen.Add(id);
      KeyValuePair<string, string> e; string s;
      if (cache.TryGetValue(id, out e) && e.Key == name) { s = e.Value; }
      else { s = GetPath(id); if (s != null) cache[id] = new KeyValuePair<string, string>(name, s); }   // failures are retried next time
      if (s != null) set.Add(s);
    } catch {} finally { p.Dispose(); }
  }
  var gone = new List<int>();
  foreach (var k in cache.Keys) if (!seen.Contains(k)) gone.Add(k);
  foreach (var k in gone) cache.Remove(k);   // the process ended: forget it
  var arr = new string[set.Count]; set.CopyTo(arr); return arr;
}
'@
}
function Get-RunningGames {
  Refresh-Sources
  @([CB.ProcPaths]::GetAll() | ? { Test-Game $_ })
}

# ---------- switching ----------
$script:busy=$false; $script:expect=-1; $script:until=Get-Date
$script:ourCmdUntil=[datetime]::MinValue
function Run-Task($name, [int]$expect, [string]$reason=''){
  $script:busy=$true; $script:expect=$expect; $script:osdReason=$reason; $script:cmdAt=Get-Date
  Start-Process schtasks.exe -WindowStyle Hidden -ArgumentList "/run /tn $name"
  $script:until=(Get-Date).AddSeconds(4); $script:ourCmdUntil=(Get-Date).AddSeconds(10)
  $timer.Interval=100   # check every 0.1 s until the hardware confirms
}
function Do-Toggle {
  if ($script:busy) { return }
  if ($script:gs.active) { $script:gs.override=$true; TLog 'Manual toggle during game - automation paused until it closes' }
  $want = if ((Get-CB) -eq 1) { 0 } else { 1 }
  # the icon changes only once the hardware confirms (the timer checks every 0.1 s while switching)
  $ni.Text = "CoolBoost Auto`nturning CoolBoost $(if($want){'ON'}else{'OFF'})..."
  Run-Task $(if ($want) { 'CoolBoostOn' } else { 'CoolBoostOff' }) $want $(if ($script:gs.active) { 'manual, until the game closes' } else { '' })
}

# ---------- gaming state machine ----------
function New-GS { @{active=$false; preGame=-1; weTurnedOn=$false; override=$false; name=''; paths=@()} }
$script:gs=New-GS
$script:lastAC=On-AC; $script:powerAt=Get-Date; $script:acChangedAt=[datetime]::MinValue; $script:prevCB=Get-CB; $script:scanAt=[datetime]::MinValue
function TLog($m){ try { $lp="$env:ProgramData\CoolBoostAuto\tray.log"; if ((Test-Path $lp) -and (Get-Item $lp).Length -gt 100KB) { Get-Content $lp -Tail 200 | Set-Content $lp }; "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $lp -Append -Encoding utf8 } catch {} }
$script:pendingOff=$false
function Game-Tick {
  $now=Get-Date; $ac=On-AC
  if ($ac -ne $script:lastAC) { $script:lastAC=$ac; $script:powerAt=$now; $script:acChangedAt=$now; $script:scanAt=[datetime]::MinValue }   # look for games right away
  $cb=Get-CB
  if ($script:cfg.paused) { $script:prevCB=$cb; return }   # paused: watch nothing, change nothing
  $quiet = ($now -gt $script:ourCmdUntil) -and (($now-$script:powerAt).TotalSeconds -gt 10)

  # every 4 s when plugged in; on battery the game rule can't act, so every 15 s is enough (keeps the status right)
  if (($now-$script:scanAt).TotalSeconds -ge $(if ($ac) { 4 } else { 15 }) -and -not $script:osdForm) {   # the scan can take a moment: not while a notice is moving
    $script:scanAt=$now
    $games = @(if ($script:cfg.gameMode -and -not $script:cfg.paused) { Get-RunningGames })   # @() outside: one game must stay a list, not a string
    if ($games.Count -gt 0 -and -not $script:gs.active) {
      $script:pendingOff=$false
      $script:gs=@{active=$true; preGame=$cb; weTurnedOn=$false; override=$false; name=(Get-Name $games[0]); paths=$games}
      TLog "Game started: $($script:gs.name) [$($games -join '; ')] CoolBoost=$cb AC=$ac"
      $script:last=''
    } elseif ($games.Count -eq 0 -and $script:gs.active) {
      $revert = $script:gs.weTurnedOn -and -not $script:gs.override -and $script:gs.preGame -eq 0 -and -not $script:cfg.paused
      TLog "Game closed: $($script:gs.name) (revert to OFF: $revert)"
      if ($revert) { $script:pendingOff=$true }
      $script:gs=New-GS; $script:last=''
    } elseif ($script:gs.active) { $script:gs.paths=$games }
  }

  if ($script:pendingOff -and -not $script:busy) {
    $script:pendingOff=$false
    if ((Get-CB) -eq 1) { TLog 'Turning CoolBoost OFF (back to pre-game state)'; Run-Task 'CoolBoostOff' 0 'game closed' }
    $script:prevCB=$cb; return
  }

  if ($script:gs.active -and -not $script:busy) {
    # user (not us, not a power change) turned it off mid-game -> respect until the game closes
    if ($script:prevCB -eq 1 -and $cb -eq 0 -and $ac -and $quiet -and -not $script:gs.override) { $script:gs.override=$true; $script:last=''; TLog 'Manual change during game - automation paused until it closes' }
    elseif (-not $script:gs.override -and $ac -and $cb -eq 0 -and $quiet) { $script:gs.weTurnedOn=$true; TLog "Turning CoolBoost ON for $($script:gs.name)"; Run-Task 'CoolBoostOn' 1 "gaming: $($script:gs.name)" }
  }
  $script:prevCB=$cb
}

# ---------- icon ----------
$traySz = [Math]::Max(16, [Windows.Forms.SystemInformation]::SmallIconSize.Width)
# icons ship as multi-size .ico files; Windows picks the frame for the tray's real size
function Load-Icon($name) {
  try { New-Object Drawing.Icon("$env:ProgramData\CoolBoostAuto\$name.ico", $traySz, $traySz) } catch { [Drawing.SystemIcons]::Application }
}
$icons=@{ '1True'=(Load-Icon 'tray_on_game'); '1False'=(Load-Icon 'tray_on'); '0True'=(Load-Icon 'tray_off_game'); '0False'=(Load-Icon 'tray_off'); '1P'=(Load-Icon 'tray_on_paused'); '0P'=(Load-Icon 'tray_off_paused') }
$ni = New-Object Windows.Forms.NotifyIcon
$ni.Icon = $icons['0False']; $ni.Visible = $true
$script:last=''
function Get-StatusText([switch]$Short) {
  $d = " $([char]0x00B7) "
  $c = $script:cfg; $cb = Get-CB
  $s = switch ($cb) { 1 {'CoolBoost ON'} 0 {'CoolBoost OFF'} default {'CoolBoost ?'} }
  $s += $d + $(if (On-AC) { 'plugged in' } else { 'on battery' })
  if ($c.paused) { $s += $d + $(if ($Short) { 'paused' } else { 'automation paused' }) }
  elseif ($script:gs.active -and $script:gs.override) { $s += $d + $(if ($Short) { 'manual (game)' } else { 'manual until the game closes' }) }
  elseif ($script:gs.active) { $s += $d + "gaming: $($script:gs.name)" }
  else { $s += $d + 'automatic' }
  $s
}
function Refresh {
  $cb=Get-CB; $c=$script:cfg; $ac=On-AC
  $key="$cb|$ac|$($c.paused)|$($script:gs.active)|$($script:gs.override)|$($script:gs.name)"
  if ($key -eq $script:last) { return }
  $script:last=$key
  $ni.Icon = $icons["$([int]($cb -eq 1))$(if ($script:cfg.paused) { 'P' } else { [bool]$script:gs.active })"]   # paused badge wins: no rule acts while paused
  $t = "CoolBoost Auto`n" + (Get-StatusText -Short)
  if ($t.Length -gt 63) { $t=$t.Substring(0,60)+'...' }
  $ni.Text=$t
}

# ---------- menu ----------
function New-MenuItem($text,$onClick){ $m=New-Object Windows.Forms.ToolStripMenuItem $text; if($onClick){ $m.add_Click($onClick) }; $m }
function New-Info($text){ $m=New-MenuItem $text $null; $m.Enabled=$false; $m }
function New-Sep { New-Object Windows.Forms.ToolStripSeparator }
function Set-Bold($m){ $m.Font = New-Object Drawing.Font($m.Font, [Drawing.FontStyle]::Bold) }
function Add-Include($path){ $cf=Read-Cfg; $cf.gamesInclude=@(@($cf.gamesInclude) + $path | Select -Unique); $cf.gamesExclude=@($cf.gamesExclude | ? { $_ -ne $path }); Save-Cfg $cf; $script:scanAt=[datetime]::MinValue }
function Add-Exclude($path){ $cf=Read-Cfg; $cf.gamesExclude=@(@($cf.gamesExclude) + $path | Select -Unique); $cf.gamesInclude=@($cf.gamesInclude | ? { $_ -ne $path }); Save-Cfg $cf; $script:scanAt=[datetime]::MinValue }
function Remove-Exclude($path){ $cf=Read-Cfg; $cf.gamesExclude=@($cf.gamesExclude | ? { $_ -ne $path }); Save-Cfg $cf; $script:scanAt=[datetime]::MinValue }
# re-apply the plug/unplug rules now (used at startup and when automation resumes)
function Run-Auto([string]$reason) { $script:ourCmdUntil=(Get-Date).AddSeconds(10); $script:osdReason=$reason; $script:cmdAt=Get-Date; Start-Process schtasks.exe -WindowStyle Hidden -ArgumentList '/run /tn CoolBoostAuto' }
function Open-NitroSense {
  # NitroSense / PredatorSense package names differ between models and versions, so look it up
  $pkg = Get-AppxPackage -Name 'AcerIncorporated.*' -EA SilentlyContinue | ? { $_.Name -match 'NitroSense|PredatorSense' } | Select -First 1
  if (-not $pkg) { return }
  $appId = 'App'; try { $appId = @((Get-AppxPackageManifest $pkg).Package.Applications.Application)[0].Id } catch {}
  Start-Process "shell:AppsFolder\$($pkg.PackageFamilyName)!$appId"
}
$appVersion = 'dev'; try { $v = (Get-Content "$env:ProgramData\CoolBoostAuto\version.txt" -Raw -EA Stop).Trim(); if ($v) { $appVersion = $v } } catch {}

$menu = New-Object Windows.Forms.ContextMenuStrip
$miTitle  = New-Info "CoolBoost Auto $appVersion"; Set-Bold $miTitle
$miStatus = New-Info 'status'
$miToggle = New-MenuItem 'Turn CoolBoost ON' { Do-Toggle }; Set-Bold $miToggle
$miBattery = New-MenuItem 'On battery: turn CoolBoost off' { Set-Cfg 'offOnBattery' (-not $script:cfg.offOnBattery) }
$miPlug = New-MenuItem 'When plugged in' $null
$plugItems = [ordered]@{ restore='Restore state from before unplugging'; on='Always turn CoolBoost ON'; off='Always turn CoolBoost OFF'; keep='Keep the battery state' }
$plugMenu = @{}
foreach ($k in $plugItems.Keys) { $it=New-MenuItem $plugItems[$k] { param($s,$e) Set-Cfg 'onPlugIn' ([string]$s.Tag) }; $it.Tag=$k; $plugMenu[$k]=$it; [void]$miPlug.DropDownItems.Add($it) }
$miGame = New-MenuItem 'While gaming: turn CoolBoost on (when plugged in)' { Set-Cfg 'gameMode' (-not $script:cfg.gameMode) }
$miGames = New-MenuItem 'Games' $null
$miDetected = New-Info 'No game running'
$miAdd = New-MenuItem 'Add a running app' $null
$miIgnore = New-MenuItem 'Ignore a game' $null
$miIgnored = New-MenuItem 'Ignored apps' $null
$miGames.DropDownItems.AddRange([Windows.Forms.ToolStripItem[]]@($miDetected, (New-Sep), $miAdd, $miIgnore, $miIgnored))
$miPause = New-MenuItem 'Pause automation' { $p = -not $script:cfg.paused; Set-Cfg 'paused' $p; if ($p) { TLog 'Automation paused' } else { TLog 'Automation resumed'; Run-Auto 'automation resumed' }; $script:last=''; Refresh }
$miStart = New-MenuItem 'Start with Windows' { Set-Cfg 'startWithWindows' (-not $script:cfg.startWithWindows) }
$miOsd = New-MenuItem 'On-screen notice' { Set-Cfg 'osd' (-not $script:cfg.osd) }
$miOsd.ToolTipText = 'Show a notice above the taskbar when CoolBoost turns on or off'
$miOpenNS = New-MenuItem 'Open NitroSense' { Open-NitroSense }
$miLogs = New-MenuItem 'Open log' $null
[void]$miLogs.DropDownItems.Add((New-MenuItem 'Power and manual switching' { Start-Process notepad "$env:ProgramFiles\CoolBoostAuto\CoolBoostAuto.log" }))
[void]$miLogs.DropDownItems.Add((New-MenuItem 'Gaming automation' { $p = "$env:ProgramData\CoolBoostAuto\tray.log"; if (-not (Test-Path $p)) { New-Item $p -ItemType File -Force | Out-Null }; Start-Process notepad $p }))
$miExit = New-MenuItem 'Exit (stops all automation)' { TLog 'Exited - all automation stopped'; $ni.Visible=$false; [Windows.Forms.Application]::Exit() }
$menu.Items.AddRange([Windows.Forms.ToolStripItem[]]@($miTitle, $miStatus, $miToggle, (New-Sep), $miBattery, $miPlug, $miGame, $miGames, (New-Sep), $miPause, $miStart, $miOsd, $miOpenNS, $miLogs, (New-Sep), $miExit))

$skipProc='(?i)^(explorer|applicationframehost|textinputhost|systemsettings|shellexperiencehost|startmenuexperiencehost|searchhost|lockapp|powershell|pwsh|conhost|windowsterminal|nitrosense|predatorsense)$'
function Fill-List($parent, $items, $emptyText) {
  $parent.DropDownItems.Clear()
  foreach ($i in $items) { [void]$parent.DropDownItems.Add($i) }
  if ($parent.DropDownItems.Count -eq 0) { [void]$parent.DropDownItems.Add((New-Info $emptyText)) }
}
$menu.add_Opening({
  Update-Cfg; $c=$script:cfg; $cb=Get-CB
  $miStatus.Text = Get-StatusText
  $miToggle.Text = if ($cb -eq 1) { 'Turn CoolBoost OFF' } else { 'Turn CoolBoost ON' }
  $miBattery.Checked = $c.offOnBattery
  foreach ($k in $plugMenu.Keys) { $plugMenu[$k].Checked = ($k -eq $c.onPlugIn) }
  $plugMenu['restore'].Text = if ($c.offOnBattery) { $plugItems['restore'] } else { $plugItems['restore'] + ' (needs the battery rule)' }
  $miGame.Checked = $c.gameMode
  $miPause.Checked = $c.paused
  $miStart.Checked = $c.startWithWindows
  $miOsd.Checked = $c.osd
  # Games > Detected now
  $miDetected.Text = if ($script:gs.active) { 'Detected now: ' + ((@($script:gs.paths) | % { Get-Name $_ } | Select -Unique) -join ', ') } else { 'No game running' }
  # Games > Add a running app: open windows that aren't games yet
  $add=@(); $seen=@{}
  foreach ($p in (Get-Process -EA SilentlyContinue | ? { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -and $_.ProcessName -notmatch $skipProc })) {
    $path=[CB.ProcPaths]::GetPath($p.Id)
    if (-not $path -or $seen.ContainsKey($path) -or (Test-Game $path)) { continue }
    $seen[$path]=1
    $title=$p.MainWindowTitle; if ($title.Length -gt 45) { $title=$title.Substring(0,42)+'...' }
    $it=New-MenuItem "$title  ($($p.ProcessName).exe)" { param($s,$e) Add-Include ([string]$s.Tag) }; $it.Tag=$path; $add += $it
  }
  Fill-List $miAdd $add '(no open apps to add)'
  # Games > Ignore a game: running games + apps you added
  $ign=@()
  foreach ($path in (@($script:gs.paths) + @($c.gamesInclude) | ? { $_ } | Select -Unique)) {
    $it=New-MenuItem "$(Get-Name $path)  ($(Split-Path $path -Leaf))" { param($s,$e) Add-Exclude ([string]$s.Tag) }; $it.Tag=$path; $ign += $it
  }
  Fill-List $miIgnore $ign '(no game running or added)'
  # Games > Ignored apps: click one to stop ignoring it
  $igd=@()
  foreach ($path in @($c.gamesExclude)) {
    $it=New-MenuItem "$(Get-Name $path)  ($(Split-Path $path -Leaf))" { param($s,$e) Remove-Exclude ([string]$s.Tag) }; $it.Tag=$path; $it.ToolTipText='Click to stop ignoring'; $igd += $it
  }
  Fill-List $miIgnored $igd '(none)'
})
Add-Type -Namespace CB -Name Win -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);'
$ni.add_MouseUp({ param($s,$e)
  if ($e.Button -eq 'Right') {
    [void][CB.Win]::SetForegroundWindow($menu.Handle)   # so the menu closes when clicking elsewhere
    $menu.Show([Windows.Forms.Cursor]::Position, [Windows.Forms.ToolStripDropDownDirection]::AboveLeft)
  }
})
$ni.add_MouseClick({ param($s,$e) if ($e.Button -eq 'Left') { Do-Toggle } })

# ---------- on-screen notice ----------
# Windows 11 flyout style: rises from behind the taskbar on Fluent's "decelerate" curve, stays ~2.7 s,
# drops back. Never takes focus, clicks pass through it, not in Alt+Tab.
Add-Type -Namespace CB -Name Rgn -MemberDefinition @'
[DllImport("gdi32.dll")] public static extern IntPtr CreateRoundRectRgn(int x1, int y1, int x2, int y2, int w, int h);
[DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int x1, int y1, int x2, int y2);
[DllImport("gdi32.dll")] public static extern int CombineRgn(IntPtr dst, IntPtr a, IntPtr b, int mode);
[DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
[DllImport("user32.dll")] public static extern int SetWindowRgn(IntPtr h, IntPtr rgn, bool redraw);
'@
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System.Windows.Forms;
public class CoolBoostOsdForm : Form {
  public CoolBoostOsdForm() { this.DoubleBuffered = true; }
  protected override bool ShowWithoutActivation { get { return true; } }
  // NOACTIVATE | TOOLWINDOW | TRANSPARENT (click-through) | TOPMOST
  protected override CreateParams CreateParams { get { var p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x00000080 | 0x00000020 | 0x00000008; return p; } }
}
'@
$script:osdDpi = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero).DpiX / 96.0
function Px([double]$v) { [int][Math]::Round($v * $script:osdDpi) }   # (not "Sc": that's an alias of Set-Content)
# the best PNG frame straight from the .ico (Drawing.Icon can't draw PNG-compressed frames)
function Load-IcoFrame($file, $want) {
  $b = [IO.File]::ReadAllBytes($file); $n = [BitConverter]::ToUInt16($b, 4); $best = $null; $bw = 9999
  for ($i = 0; $i -lt $n; $i++) { $o = 6 + 16*$i; $w = $b[$o]; if ($w -eq 0) { $w = 256 }
    $sz = [BitConverter]::ToInt32($b, $o+8); $off = [BitConverter]::ToInt32($b, $o+12)
    if ($w -ge $want -and $w -lt $bw) { $bw = $w; $best = [byte[]]$b[$off..($off+$sz-1)] } }
  if ($best) { [Drawing.Image]::FromStream((New-Object IO.MemoryStream (,$best))) }
}
$script:osdImg = @{}
foreach ($k in 'on','off') { try { $script:osdImg[$k] = Load-IcoFrame "$env:ProgramData\CoolBoostAuto\tray_$k.ico" (Px 24) } catch {} }
$script:osdFontT = New-Object Drawing.Font 'Segoe UI Variable Text', 10.5, ([Drawing.FontStyle]::Bold)
if ($script:osdFontT.Name -ne 'Segoe UI Variable Text') { $script:osdFontT = New-Object Drawing.Font 'Segoe UI', 10.5, ([Drawing.FontStyle]::Bold) }
$script:osdFontR = New-Object Drawing.Font $script:osdFontT.FontFamily, 8.5
$script:osdGrey = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(190, 190, 190))
$script:osdForm = $null; $script:osdCB = Get-CB; $script:osdReason = ''; $script:cmdAt = [datetime]::MinValue
$osdSw = New-Object Diagnostics.Stopwatch
$osdTimer = New-Object Windows.Forms.Timer; $osdTimer.Interval = 8

# show only the part above the taskbar, with rounded corners
function Osd-Clip([int]$top) {
  $f = $script:osdForm; if ($top -eq $script:osdLastTop) { return }; $script:osdLastTop = $top
  $vis = [Math]::Max(0, [Math]::Min($f.Height, $script:osdWa.Bottom - $top))
  $r = Px 8
  $round = [CB.Rgn]::CreateRoundRectRgn(0, 0, $f.Width + 1, $f.Height + 1, 2 * $r, 2 * $r)
  $rect = [CB.Rgn]::CreateRectRgn(0, 0, $f.Width, $vis)
  [void][CB.Rgn]::CombineRgn($round, $round, $rect, 1)      # RGN_AND
  [void][CB.Rgn]::SetWindowRgn($f.Handle, $round, $true)    # Windows owns the region now
  [void][CB.Rgn]::DeleteObject($rect)
}
function Close-Osd {
  $osdTimer.Stop(); $osdSw.Reset()
  if ($script:osdForm -and -not $script:osdForm.IsDisposed) { $script:osdForm.Close(); $script:osdForm.Dispose() }
  $script:osdForm = $null
}
$osdTimer.add_Tick({
  try {
    $f = $script:osdForm; if (-not $f -or $f.IsDisposed) { $osdTimer.Stop(); return }
    $ms = $osdSw.ElapsedMilliseconds
    if ($ms -lt 270)      { $u = [Math]::Pow($ms / 270.0, 1/3.0); $k = 3*$u*$u - 2*$u*$u*$u }   # cubic-bezier(0,0,0,1)
    elseif ($ms -lt 2970) { $k = 1 }
    elseif ($ms -lt 3090) { $p = ($ms - 2970) / 120.0; $k = 1 - $p*$p*$p }                       # accelerate out
    else { Close-Osd; return }
    $top = [int][Math]::Round($script:osdStart + ($script:osdEnd - $script:osdStart) * $k)
    if ($f.Top -ne $top) { $f.Top = $top }
    Osd-Clip $top
  } catch { TLog "On-screen notice error: $_"; Close-Osd }
})
function Show-Osd([int]$state, [string]$reason) {
  Close-Osd   # a newer notice replaces the one on screen
  $f = New-Object CoolBoostOsdForm
  $f.FormBorderStyle = 'None'; $f.ShowInTaskbar = $false; $f.TopMost = $true; $f.StartPosition = 'Manual'
  $f.BackColor = [Drawing.Color]::FromArgb(44, 44, 44)
  $f.Size = New-Object Drawing.Size (Px 210), (Px 46)
  $f.Tag = @{ title = "CoolBoost $(if ($state) { 'ON' } else { 'OFF' })"; reason = $reason; img = $script:osdImg[$(if ($state) { 'on' } else { 'off' })] }
  $f.add_Paint({ param($snd, $ev)
    $d = $snd.Tag; $g = $ev.Graphics
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'; $g.InterpolationMode = 'HighQualityBicubic'
    if ($d.img) { $g.DrawImage($d.img, [Drawing.Rectangle]::new((Px 14), [int](($snd.Height - (Px 24)) / 2), (Px 24), (Px 24))) }
    if ($d.reason) {
      $g.DrawString($d.title, $script:osdFontT, [Drawing.Brushes]::White, (Px 48), (Px 5))
      $g.DrawString($d.reason, $script:osdFontR, $script:osdGrey, (Px 48), (Px 24))
    } else { $g.DrawString($d.title, $script:osdFontT, [Drawing.Brushes]::White, (Px 48), [int](($snd.Height - $g.MeasureString($d.title, $script:osdFontT).Height) / 2)) }
  })
  # bottom centre of the main screen; the taskbar's top edge is the bottom of the working area
  $script:osdWa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $script:osdStart = $script:osdWa.Bottom
  $script:osdEnd = $script:osdWa.Bottom - $f.Height - (Px 14)
  $f.Location = New-Object Drawing.Point ($script:osdWa.X + [int](($script:osdWa.Width - $f.Width) / 2)), $script:osdStart
  $script:osdLastTop = -99999
  $script:osdForm = $f
  $f.add_HandleCreated({ Osd-Clip $script:osdStart })   # hidden before it is ever drawn: no flash over the taskbar
  $f.add_Shown({ $osdSw.Restart(); $osdTimer.Start() })
  $f.Show()
}
# why it switched: our own command, a plug/unplug, or nothing to say (manual: NitroSense, a hotkey, the tray click).
# whichever happened last wins, and a command explains only one switch
function Get-OsdReason {
  $now = Get-Date; $ac = On-AC
  $powerAt = if ($ac -ne $script:lastAC) { $now } else { $script:acChangedAt }
  $power = ($now - $powerAt).TotalSeconds -lt 15
  $cmd = ($now - $script:cmdAt).TotalSeconds -lt 10
  $r = if ($cmd -and (-not $power -or $script:cmdAt -gt $powerAt)) { $script:osdReason }
       elseif ($power) { if ($ac) { 'plugged in' } else { 'unplugged' } }
       else { '' }
  $script:cmdAt = [datetime]::MinValue
  $r
}
function Check-Osd {
  $cb = Get-CB
  if ($cb -notin 0,1 -or $cb -eq $script:osdCB) { return }
  $prev = $script:osdCB; $script:osdCB = $cb
  if ($prev -in 0,1 -and $script:cfg.osd) { try { Show-Osd $cb (Get-OsdReason) } catch { TLog "On-screen notice failed: $_" } }
}

# ---------- loop ----------
$timer=New-Object Windows.Forms.Timer
$timer.Interval=500
$timer.add_Tick({
  try {
    Check-Osd
    if ($script:busy) {
      if ((Get-CB) -eq $script:expect -or (Get-Date) -gt $script:until) { $script:busy=$false; $timer.Interval=500; $script:last=''; Refresh }
      return
    }
    Update-Cfg
    Game-Tick
    if (-not $script:busy) { Refresh }
  } catch {}
})
$timer.Start()
Refresh
Run-Auto $(if (On-AC) { 'plugged in' } else { 'on battery' })
[Windows.Forms.Application]::Run()
$ni.Dispose(); $mtx.ReleaseMutex()






