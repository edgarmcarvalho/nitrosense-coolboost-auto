# Regenerates docs/screenshot.png: the icon legend plus the real tray menu (same WinForms menu as the app),
# drawn with example state. Run from the repo:  powershell -STA -File docs\make-screenshot.ps1 -Version 0.9.7
# It briefly covers the screen with a dark window while it captures the menu.
param([string]$Version = '0.9.7', [string]$Out = (Join-Path $PSScriptRoot 'screenshot.png'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace Shot -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][Shot.Dpi]::SetProcessDPIAware()   # same as the tray, so the menu looks identical

$bg = [Drawing.Color]::FromArgb(20, 21, 25)
$scr = [Windows.Forms.Screen]::PrimaryScreen.Bounds
$g0 = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $s = $g0.DpiX / 96; $g0.Dispose()
function Px([double]$v) { [int][Math]::Round($v * $s / 1.25) }   # layout below was designed at 125 %

# ---- the menu, built like CoolBoostTray.ps1 does ----
function Item($t) { New-Object Windows.Forms.ToolStripMenuItem $t }
function Info($t) { $m = Item $t; $m.Enabled = $false; $m }
function Sep { New-Object Windows.Forms.ToolStripSeparator }
function Bold($m) { $m.Font = New-Object Drawing.Font($m.Font, [Drawing.FontStyle]::Bold) }
$menu = New-Object Windows.Forms.ContextMenuStrip
$title = Info "CoolBoost Auto $Version"; Bold $title
$status = Info 'CoolBoost ON · plugged in · gaming: BeamNG.drive'
$toggle = Item 'Turn CoolBoost OFF'; Bold $toggle
$battery = Item 'On battery: turn CoolBoost off'; $battery.Checked = $true
$plug = Item 'When plugged in'
$restore = Item 'Restore state from before unplugging'; $restore.Checked = $true
$plug.DropDownItems.AddRange([Windows.Forms.ToolStripItem[]]@($restore, (Item 'Always turn CoolBoost ON'), (Item 'Always turn CoolBoost OFF'), (Item 'Keep the battery state')))
$game = Item 'While gaming: turn CoolBoost on (when plugged in)'; $game.Checked = $true
$games = Item 'Games'; [void]$games.DropDownItems.Add((Info 'x'))
$settings = Item 'Settings'; [void]$settings.DropDownItems.Add((Info 'x'))
$tools = Item 'Tools'; [void]$tools.DropDownItems.Add((Info 'x'))
$menu.Items.AddRange([Windows.Forms.ToolStripItem[]]@($title, $status, $toggle, (Sep), $battery, $plug, $game, $games, (Sep),
  (Item 'Pause automation'), $settings, $tools, (Sep), (Item 'Exit (stops all automation)')))

# ---- show it over a dark window and capture it ----
$form = New-Object Windows.Forms.Form
$form.FormBorderStyle = 'None'; $form.StartPosition = 'Manual'; $form.Bounds = $scr; $form.BackColor = $bg; $form.TopMost = $true; $form.ShowInTaskbar = $false
$form.Show(); [Windows.Forms.Application]::DoEvents()
$mx = $scr.X + (Px 330); $my = $scr.Y + (Px 40)
$menu.Show($form, (New-Object Drawing.Point((Px 330), (Px 40))))
for ($i = 0; $i -lt 10; $i++) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50 }
$plug.ShowDropDown()
for ($i = 0; $i -lt 20; $i++) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50 }
$r = [Drawing.Rectangle]::Union($menu.Bounds, $plug.DropDown.Bounds); $r.Inflate((Px 14), (Px 14))
$cap = New-Object Drawing.Bitmap $r.Width, $r.Height
$gc = [Drawing.Graphics]::FromImage($cap); $gc.CopyFromScreen($r.Location, [Drawing.Point]::Empty, $r.Size); $gc.Dispose()
$menuOff = New-Object Drawing.Point(($menu.Bounds.X - $r.X), ($menu.Bounds.Y - $r.Y))
$mh = $menu.Bounds.Height
$menu.Close(); $form.Close()

# ---- compose: legend on the left, menu on the right ----
$W = (Px 330) - $menuOff.X + $cap.Width + (Px 60)
$H = [Math]::Max((Px 470), $cap.Height + (Px 20))
$menuTop = [int](($H - $mh) / 2)   # the menu is centred vertically next to the legend
$img = New-Object Drawing.Bitmap $W, $H
$g = [Drawing.Graphics]::FromImage($img)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'; $g.InterpolationMode = 'HighQualityBicubic'
$g.Clear($bg)
$g.DrawImage($cap, (Px 330) - $menuOff.X, $menuTop - $menuOff.Y)
$white = [Drawing.Brushes]::White; $grey = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(170, 172, 178))
$red = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(226, 35, 26))
$g.DrawString('CoolBoost Auto', (New-Object Drawing.Font('Segoe UI Semibold', [single](Px 30), [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)), $white, (Px 34), (Px 38))
$g.FillRectangle($red, (Px 40), (Px 85), (Px 55), (Px 3))
$f2 = New-Object Drawing.Font('Segoe UI', [single](Px 16), [Drawing.GraphicsUnit]::Pixel)
$g.DrawString("Automatic CoolBoost for`nAcer Nitro laptops", $f2, $grey, (Px 36), (Px 100))
$icons = 'tray_on', 'ON', 'tray_off', 'OFF', 'tray_on_game', 'ON, game running', 'tray_off_game', 'OFF, game running', 'tray_on_paused', 'ON, automation paused', 'tray_off_paused', 'OFF, automation paused'
for ($i = 0; $i -lt 6; $i++) {
  $y = (Px 168) + $i * (Px 48)
  $ic = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot "icons\$($icons[2*$i]).png"))
  $g.DrawImage($ic, (Px 38), $y, (Px 36), (Px 36)); $ic.Dispose()
  $g.DrawString($icons[2*$i+1], $f2, $grey, (Px 86), $y + (Px 7))
}
$g.Dispose()
$img.Save($Out, [Drawing.Imaging.ImageFormat]::Png)
"Saved $Out ($W x $H)"
