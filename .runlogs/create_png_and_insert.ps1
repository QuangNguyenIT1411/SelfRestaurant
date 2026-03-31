$ErrorActionPreference='Stop'

$base='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$imgDir=Join-Path $base '.runlogs'
$img1=Join-Path $imgDir 'diagram_b1.png'
$img2=Join-Path $imgDir 'diagram_b2.png'
$docPath=Join-Path $base 'Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'

Add-Type -AssemblyName System.Drawing

function Draw-LineArrow([System.Drawing.Graphics]$g,[single]$x1,[single]$y1,[single]$x2,[single]$y2){
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,3)
  $g.DrawLine($pen,$x1,$y1,$x2,$y2)
  # simple arrow head
  $angle = [Math]::Atan2($y2-$y1,$x2-$x1)
  $len = 12
  $a1 = $angle + 2.6
  $a2 = $angle - 2.6
  $p1x = $x2 + $len * [Math]::Cos($a1)
  $p1y = $y2 + $len * [Math]::Sin($a1)
  $p2x = $x2 + $len * [Math]::Cos($a2)
  $p2y = $y2 + $len * [Math]::Sin($a2)
  $g.DrawLine($pen,$x2,$y2,$p1x,$p1y)
  $g.DrawLine($pen,$x2,$y2,$p2x,$p2y)
  $pen.Dispose()
}

function New-Diagram1($path) {
  $bmp = New-Object System.Drawing.Bitmap 1400, 520
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::White)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 3)
  $font = New-Object System.Drawing.Font('Times New Roman', 18)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

  function Box($x,$y,$w,$h,$text,[System.Drawing.Color]$color){
    $brush=New-Object System.Drawing.SolidBrush($color)
    $g.FillRectangle($brush,$x,$y,$w,$h)
    $g.DrawRectangle($pen,$x,$y,$w,$h)
    $g.DrawString($text,$font,[System.Drawing.Brushes]::Black,(New-Object System.Drawing.RectangleF($x,$y,$w,$h)),$sf)
    $brush.Dispose()
  }

  Box 40 140 200 100 "Users\n(Web/Mobile/POS)" ([System.Drawing.Color]::FromArgb(220,240,255))
  Box 300 140 220 100 "API Gateway\nAuth + Routing" ([System.Drawing.Color]::FromArgb(220,255,220))
  Box 580 140 310 100 "Microservices\nOrder/Menu/Table/Payment/Customer" ([System.Drawing.Color]::FromArgb(255,245,220))
  Box 950 140 250 100 "Database per Service" ([System.Drawing.Color]::FromArgb(245,230,255))
  Box 680 320 220 80 "Message Broker" ([System.Drawing.Color]::FromArgb(235,235,235))
  Box 960 320 240 80 "Logging + Monitoring" ([System.Drawing.Color]::FromArgb(235,235,235))

  Draw-LineArrow $g 240 190 300 190
  Draw-LineArrow $g 520 190 580 190
  Draw-LineArrow $g 890 190 950 190
  Draw-LineArrow $g 735 240 790 320
  Draw-LineArrow $g 1040 240 1075 320

  $titleFont = New-Object System.Drawing.Font('Times New Roman', 24, [System.Drawing.FontStyle]::Bold)
  $g.DrawString('Diagram 1 - System Overview', $titleFont, [System.Drawing.Brushes]::Black, 40, 40)

  $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $pen.Dispose(); $font.Dispose(); $titleFont.Dispose(); $sf.Dispose()
}

function New-Diagram2($path) {
  $bmp = New-Object System.Drawing.Bitmap 1400, 420
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::White)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 3)
  $font = New-Object System.Drawing.Font('Times New Roman', 18)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

  function Box2($x,$y,$w,$h,$text,[System.Drawing.Color]$color){
    $brush=New-Object System.Drawing.SolidBrush($color)
    $g.FillRectangle($brush,$x,$y,$w,$h)
    $g.DrawRectangle($pen,$x,$y,$w,$h)
    $g.DrawString($text,$font,[System.Drawing.Brushes]::Black,(New-Object System.Drawing.RectangleF($x,$y,$w,$h)),$sf)
    $brush.Dispose()
  }

  $titleFont = New-Object System.Drawing.Font('Times New Roman', 24, [System.Drawing.FontStyle]::Bold)
  $g.DrawString('Diagram 2 - Clean Architecture Layers', $titleFont, [System.Drawing.Brushes]::Black, 40, 30)

  Box2 80 180 220 110 "API Layer\nControllers" ([System.Drawing.Color]::FromArgb(220,240,255))
  Box2 360 180 250 110 "Application Layer\nUse Cases" ([System.Drawing.Color]::FromArgb(220,255,220))
  Box2 670 180 220 110 "Domain Layer\nEntities + Rules" ([System.Drawing.Color]::FromArgb(255,245,220))
  Box2 950 180 300 110 "Infrastructure\nDB/Cache/Broker/Repo" ([System.Drawing.Color]::FromArgb(245,230,255))

  Draw-LineArrow $g 300 235 360 235
  Draw-LineArrow $g 610 235 670 235
  Draw-LineArrow $g 950 235 890 235

  $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $pen.Dispose(); $font.Dispose(); $titleFont.Dispose(); $sf.Dispose()
}

New-Diagram1 $img1
New-Diagram2 $img2

$word = New-Object -ComObject Word.Application
$word.Visible = $false

try {
  $doc = $word.Documents.Open($docPath,$false,$false)
  $sel = $word.Selection
  $sel.EndKey(6) | Out-Null
  $sel.InsertBreak(7) | Out-Null
  $sel.TypeText('PHAN B - BIEU DO VE TRUC QUAN')
  $sel.TypeParagraph()
  $sel.TypeText('Bieu do 1: Kien truc tong quan he thong')
  $sel.TypeParagraph()

  $pic1 = $sel.InlineShapes.AddPicture($img1)
  $pic1.Width = 500
  $pic1.Height = 186
  $sel.TypeParagraph()
  $sel.TypeParagraph()

  $sel.TypeText('Bieu do 2: Kien truc ben trong mot microservice')
  $sel.TypeParagraph()
  $pic2 = $sel.InlineShapes.AddPicture($img2)
  $pic2.Width = 500
  $pic2.Height = 150

  $doc.Save()
  $pdfPath = [System.IO.Path]::ChangeExtension($docPath,'pdf')
  $doc.ExportAsFixedFormat($pdfPath,17)
  $doc.Close()

  Write-Output "Updated: $docPath"
  Write-Output "Updated: $pdfPath"
  Write-Output "Images: $img1 ; $img2"
}
finally {
  try { $word.Quit() } catch {}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
}
