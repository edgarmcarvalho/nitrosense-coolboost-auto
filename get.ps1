# CoolBoost Auto: one-line installer.
#
#   irm https://raw.githubusercontent.com/edgarmcarvalho/nitrosense-coolboost-auto/main/get.ps1 | iex
#
# To remove it the same way (same download and checksum check, then it runs the release's uninstall.ps1):
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/edgarmcarvalho/nitrosense-coolboost-auto/main/get.ps1))) -Uninstall
#
# Why this exists: files downloaded with a browser carry the "Mark of the Web", and Windows (SmartScreen,
# Smart App Control, the default PowerShell policy) blocks unsigned ones. This script downloads the release with
# PowerShell itself, which leaves no such mark, checks it against the published SHA-256 checksums and runs
# the normal install.ps1 (which asks for administrator rights itself).
# It changes nothing outside the install: a temporary folder is used and removed at the end.
param([switch]$NoAutostart, [switch]$Quiet, [switch]$KeepFiles, [switch]$Uninstall)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$repo = 'edgarmcarvalho/nitrosense-coolboost-auto'
$hdr  = @{ 'User-Agent' = 'CoolBoostAuto-get' }

# Downloads a file and draws a progress bar with the size and the speed on one console line.
function Get-FileWithProgress($url, $out) {
  $req = [Net.HttpWebRequest]::Create($url)
  $req.UserAgent = 'CoolBoostAuto-get'
  $resp = $req.GetResponse()
  try {
    $total = $resp.ContentLength
    $in = $resp.GetResponseStream()
    $fs = [IO.File]::Create($out)
    try {
      $buf = New-Object byte[] 65536
      $done = 0L
      $sw = [Diagnostics.Stopwatch]::StartNew()
      $last = -1000
      while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
        $fs.Write($buf, 0, $n); $done += $n
        if ($sw.ElapsedMilliseconds - $last -ge 100) { $last = $sw.ElapsedMilliseconds; Show-Bar $done $total $sw.Elapsed.TotalSeconds }
      }
      Show-Bar $done $total $sw.Elapsed.TotalSeconds
      Write-Host ''
    }
    finally { $fs.Dispose(); $in.Dispose() }
  }
  finally { $resp.Dispose() }
}
function Show-Bar($done, $total, $secs) {
  $speed = if ($secs -gt 0) { $done / $secs } else { 0 }
  $spd = if ($speed -ge 1MB) { '{0:N2} MB/s' -f ($speed / 1MB) } else { '{0:N0} KB/s' -f ($speed / 1KB) }
  if ($total -gt 0) {
    $pct = [Math]::Min(100, [int](100 * $done / $total)); $fill = [int]($pct / 4)
    $bar = ('#' * $fill) + ('-' * (25 - $fill))
    $line = '    [{0}] {1,3}%  {2:N2} / {3:N2} MB  {4}' -f $bar, $pct, ($done / 1MB), ($total / 1MB), $spd
  } else { $line = '    {0:N2} MB  {1}' -f ($done / 1MB), $spd }
  Write-Host ("`r" + $line.PadRight(78)) -NoNewline
}

function Fail($m) { Write-Host "`nERROR: $m" -ForegroundColor Red; Write-Host "You can also download the scripts zip by hand: https://github.com/$repo/releases/latest" -ForegroundColor Yellow; return }

Write-Host "`nCoolBoost Auto: download and $(if ($Uninstall) { 'remove' } else { 'install' })`n" -ForegroundColor White
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('CoolBoostAuto-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
try {
  Write-Host '==> Looking for the latest release' -ForegroundColor Cyan
  $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers $hdr
  $zipA  = $rel.assets | Where-Object { $_.name -like 'CoolBoostAuto-Scripts-*.zip' } | Select-Object -First 1
  $sumsA = $rel.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1
  if (-not $zipA -or -not $sumsA) { return (Fail "Release $($rel.tag_name) has no scripts zip or checksums file.") }
  Write-Host "    $($rel.tag_name)" -ForegroundColor Green

  New-Item $tmp -ItemType Directory | Out-Null
  $zip = Join-Path $tmp $zipA.name
  Write-Host '==> Downloading' -ForegroundColor Cyan
  Get-FileWithProgress $zipA.browser_download_url $zip
  $sumsFile = Join-Path $tmp 'SHA256SUMS.txt'
  Invoke-WebRequest $sumsA.browser_download_url -OutFile $sumsFile -Headers $hdr -UseBasicParsing
  $sums = Get-Content $sumsFile -Raw

  Write-Host '==> Checking the SHA-256 checksum' -ForegroundColor Cyan
  $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
  $line = ($sums -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($zipA.name) } | Select-Object -First 1
  if (-not $line -or $line.ToLower() -notmatch $hash) { return (Fail 'The download does not match the published checksum, so it was not installed.') }
  Write-Host "    OK ($hash)" -ForegroundColor Green

  Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x') -Force
  $inst = Get-ChildItem (Join-Path $tmp 'x') -Recurse -Filter install.ps1 | Select-Object -First 1
  if (-not $inst) { return (Fail 'install.ps1 was not found in the download.') }
  Get-ChildItem (Split-Path $inst.FullName) -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

  if ($Uninstall) {
    $un = Get-ChildItem (Join-Path $tmp 'x') -Recurse -Filter uninstall.ps1 | Select-Object -First 1
    if (-not $un) { return (Fail 'uninstall.ps1 was not found in the download.') }
    Write-Host '==> Removing' -ForegroundColor Cyan
    Write-Host '    Windows will ask for administrator permission. A second window then opens and shows the removal;' -ForegroundColor Gray
    Write-Host '    when it finishes, read the result there and press Enter to close that window.' -ForegroundColor Gray
    $ua = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($un.FullName)`"")
    if ($Quiet) { $ua += '-Quiet' }
    try { $pr = Start-Process powershell.exe -Verb RunAs -ArgumentList $ua -Wait -PassThru }
    catch { return (Fail 'Administrator permission was not given, so nothing was removed.') }
    if ($pr.ExitCode -eq 0) { Write-Host "`nDone. CoolBoost Auto was removed." -ForegroundColor Green }
    else { Write-Host "`nThe removal stopped (code $($pr.ExitCode))." -ForegroundColor Yellow }
    return
  }

  Write-Host '==> Installing' -ForegroundColor Cyan
  Write-Host '    Windows will ask for administrator permission. A second window then opens and shows the install;' -ForegroundColor Gray
  Write-Host '    when it finishes, read the result there and press Enter to close that window.' -ForegroundColor Gray
  $ilog = Join-Path $tmp 'install.log'
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($inst.FullName)`"", '-LogPath', "`"$ilog`"")
  if ($NoAutostart) { $a += '-NoAutostart' }
  if ($Quiet) { $a += '-Quiet' }
  try { $pr = Start-Process powershell.exe -Verb RunAs -ArgumentList $a -Wait -PassThru }
  catch { return (Fail 'Administrator permission was not given, so nothing was installed.') }
  if ($pr.ExitCode -eq 0) { Write-Host "`nDone. Look for the fan icon next to the clock (it may be under the ^ arrow)." -ForegroundColor Green }
  else {
    Write-Host "`nThe installer stopped (code $($pr.ExitCode)). Nothing was installed if the compatibility check failed. Its last lines:" -ForegroundColor Yellow
    if (Test-Path $ilog) { Get-Content $ilog -Tail 14 | ForEach-Object { Write-Host "    $_" } }
  }
}
catch { Fail $_.Exception.Message }
finally { if (-not $KeepFiles) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue } }
