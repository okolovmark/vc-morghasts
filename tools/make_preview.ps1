$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$size = 512
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# background: dark teal-black gradient (necromantic)
$rect = New-Object System.Drawing.Rectangle(0,0,$size,$size)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(16,38,36), [System.Drawing.Color]::FromArgb(6,10,12), 90)
$g.FillRectangle($bgBrush, $rect)

# radial glow behind emblem (spectral green)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(96, 130, 320, 320)
$glow = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
$glow.CenterColor = [System.Drawing.Color]::FromArgb(85, 90, 220, 170)
$glow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 90, 220, 170))
$g.FillEllipse($glow, 96, 130, 320, 320)

$bone = [System.Drawing.Color]::FromArgb(222,214,186)
$boneDim = [System.Drawing.Color]::FromArgb(140,132,108)
$spectral = [System.Drawing.Color]::FromArgb(120,230,185)
$bonePen = New-Object System.Drawing.Pen($bone, 3)
$thinPen = New-Object System.Drawing.Pen($boneDim, 1)

# double frame
$g.DrawRectangle($bonePen, 10, 10, $size-21, $size-21)
$g.DrawRectangle($thinPen, 20, 20, $size-41, $size-41)

# corner diamonds
$boneBrush = New-Object System.Drawing.SolidBrush($bone)
$spectralBrush = New-Object System.Drawing.SolidBrush($spectral)
$corners = @()
$corners += ,(10,10)
$corners += ,(501,10)
$corners += ,(10,501)
$corners += ,(501,501)
foreach ($c in $corners) {
    $cx = [int]$c[0]; $cy = [int]$c[1]
    $pts = @(
        (New-Object System.Drawing.PointF($cx, ($cy-9))),
        (New-Object System.Drawing.PointF(($cx+9), $cy)),
        (New-Object System.Drawing.PointF($cx, ($cy+9))),
        (New-Object System.Drawing.PointF(($cx-9), $cy))
    )
    $g.FillPolygon($boneBrush, $pts)
}

$black = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,0,0,0))
$grayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150,160,150))
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center

function Draw-Text([string]$text, [System.Drawing.Font]$font, [System.Drawing.Brush]$brush, [single]$y) {
    $g.DrawString($text, $font, $black, [single]($size/2 + 3), [single]($y + 3), $fmt)
    $g.DrawString($text, $font, $brush, [single]($size/2), [single]$y, $fmt)
}

$titleFont1 = New-Object System.Drawing.Font("Georgia", 44, [System.Drawing.FontStyle]::Bold)
$emblemFont = New-Object System.Drawing.Font("Segoe UI Symbol", 140, [System.Drawing.FontStyle]::Bold)
$smallFont  = New-Object System.Drawing.Font("Georgia", 22, [System.Drawing.FontStyle]::Bold)
$tinyFont   = New-Object System.Drawing.Font("Georgia", 13, [System.Drawing.FontStyle]::Regular)

Draw-Text "MORGHASTS" $titleFont1 $boneBrush 48

# separator ornament
$g.DrawLine($bonePen, 90, 132, 210, 132)
$g.DrawLine($bonePen, 302, 132, 422, 132)
$pts = @(
    (New-Object System.Drawing.PointF(256, 123)),
    (New-Object System.Drawing.PointF(268, 132)),
    (New-Object System.Drawing.PointF(256, 141)),
    (New-Object System.Drawing.PointF(244, 132))
)
$g.FillPolygon($boneBrush, $pts)

# emblem: skull
Draw-Text ([string][char]0x2620) $emblemFont $spectralBrush 128

# bottom captions
Draw-Text "FOR  VAMPIRE  COUNTS" $smallFont $boneBrush 388
Draw-Text "+ ASHIGAROTH  MOUNTS" $tinyFont $spectralBrush 442
$g.DrawString("Total War: WARHAMMER III", $tinyFont, $grayBrush, [single]($size/2), [single]470, $fmt)

$outDir = "C:\Users\okolo\Downloads\vc-morghasts"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory $outDir | Out-Null }
$out = "$outDir\preview.png"
$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "saved $out ($((Get-Item $out).Length) bytes)"
