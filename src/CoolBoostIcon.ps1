# nitrosense-coolboost-auto - icon drawing (tray + Start menu)  -  MIT License
Add-Type -AssemblyName System.Drawing
function New-CBBitmap([int]$size,[bool]$on,[bool]$game){
  $s = $size / 32.0
  $bmp = New-Object Drawing.Bitmap $size,$size
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.PixelOffsetMode='HighQuality'
  $fill = if($on){ [Drawing.Color]::FromArgb(0,160,255) } else { [Drawing.Color]::FromArgb(120,120,120) }
  $g.FillEllipse((New-Object Drawing.SolidBrush $fill), [single](0.5*$s), [single](0.5*$s), [single](31*$s), [single](31*$s))
  $pen = New-Object Drawing.Pen ([Drawing.Color]::White), ([single][Math]::Max(1.6, 3.2*$s))
  $pen.StartCap='Round'; $pen.EndCap='Round'
  foreach($a in 90,30,150){
    $r=$a*[Math]::PI/180; $dx=[Math]::Cos($r)*10.5*$s; $dy=[Math]::Sin($r)*10.5*$s; $c=16*$s
    $g.DrawLine($pen,[single]($c-$dx),[single]($c-$dy),[single]($c+$dx),[single]($c+$dy))
  }
  if(-not $on){
    $p2 = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(235,50,50)), ([single][Math]::Max(1.8, 3.6*$s))
    $p2.StartCap='Round'; $p2.EndCap='Round'
    $g.DrawLine($p2,[single](6*$s),[single](26*$s),[single](26*$s),[single](6*$s))
  }
  if($game){
    # big badge, bottom-right: dark ring + bright green core
    $g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(20,20,20))), [single](11*$s), [single](11*$s), [single](21*$s), [single](21*$s))
    $g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(40,230,80))), [single](13.5*$s), [single](13.5*$s), [single](16*$s), [single](16*$s))
  }
  $g.Dispose(); $bmp
}
function Save-CBIco([string]$path,[int[]]$sizes,[bool]$on,[bool]$game){
  $frames = foreach($z in $sizes){ $b=New-CBBitmap $z $on $game; $ms=New-Object IO.MemoryStream; $b.Save($ms,[Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); ,@($z,$ms.ToArray()) }
  $fs=[IO.File]::Create($path); $w=New-Object IO.BinaryWriter $fs
  $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$frames.Count)
  $off = 6 + 16*$frames.Count
  foreach($f in $frames){ $z=$f[0]; $len=$f[1].Length; $dim=[byte]$(if($z -ge 256){0}else{$z})
    $w.Write($dim); $w.Write($dim); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$len); $w.Write([uint32]$off); $off+=$len }
  foreach($f in $frames){ $w.Write($f[1]) }
  $w.Close()
}

