# CoolBoost Auto: one-line installer.
#
#   irm https://raw.githubusercontent.com/edgarmcarvalho/nitrosense-coolboost-auto/main/get.ps1 | iex
#
# Why this exists: files downloaded with a browser carry the "Mark of the Web", and Windows (SmartScreen,
# Smart App Control, the default PowerShell policy) blocks unsigned ones. This script downloads the release with
# PowerShell itself, which leaves no such mark, checks it against the published SHA-256 checksums and runs
# the normal install.ps1 (which asks for administrator rights itself).
# It changes nothing outside the install: a temporary folder is used and removed at the end.
param([switch]$NoAutostart, [switch]$Quiet, [switch]$KeepFiles)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$repo = 'edgarmcarvalho/nitrosense-coolboost-auto'
$hdr  = @{ 'User-Agent' = 'CoolBoostAuto-get' }

function Fail($m) { Write-Host "`nERROR: $m" -ForegroundColor Red; Write-Host "You can also download the scripts zip by hand: https://github.com/$repo/releases/latest" -ForegroundColor Yellow; return }

Write-Host "`nCoolBoost Auto: download and install`n" -ForegroundColor White
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
  Invoke-WebRequest $zipA.browser_download_url -OutFile $zip -Headers $hdr -UseBasicParsing
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
