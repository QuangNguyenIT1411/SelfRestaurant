$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\diagram_eventbus_vn.png'

$bmp = New-Object System.Drawing.Bitmap 1800,980
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(242,242,242),1)
for ($x=0; $x -le 1800; $x+=24) { $g.DrawLine($gridPen,$x,0,$x,980) }
for ($y=0; $y -le 980; $y+=24) { $g.DrawLine($gridPen,0,$y,1800,$y) }

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
$fontTitle = New-Object System.Drawing.Font('Times New Roman',28,[System.Drawing.FontStyle]::Bold)
$fontHead = New-Object System.Drawing.Font('Times New Roman',14,[System.Drawing.FontStyle]::Bold)
$fontText = New-Object System.Drawing.Font('Times New Roman',12)
$fontSmall = New-Object System.Drawing.Font('Times New Roman',11)
$brushBlack = [System.Drawing.Brushes]::Black

$g.DrawString('SƠ ĐỒ KIẾN TRÚC MICROSERVICES - SELF RESTAURANT WEB', $fontTitle, $brushBlack, 275, 18)
$g.DrawString('Đề tài: Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web', $fontSmall, $brushBlack, 520, 64)

$g.DrawRectangle($pen,70,130,270,110)
$g.DrawString('CLIENT LAYER', $fontHead, $brushBlack, 130, 142)
$g.DrawString('Tablet khách / Web Admin / POS', $fontText, $brushBlack, 84, 180)

$gwBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(219,238,255))
$g.FillRectangle($gwBrush, 430, 120, 360, 130)
$g.DrawRectangle($pen,430,120,360,130)
$g.DrawString('API GATEWAY (Ocelot/Kong)', $fontHead, $brushBlack, 495, 150)
$g.DrawString('Routing - Auth - Load Balancing', $fontText, $brushBlack, 492, 185)

$idBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,248,225))
$g.FillRectangle($idBrush, 860, 120, 270, 130)
$g.DrawRectangle($pen,860,120,270,130)
$g.DrawString('IDENTITY SERVICE', $fontHead, $brushBlack, 915, 150)
$g.DrawString('JWT / Claims / Refresh Token', $fontText, $brushBlack, 892, 185)

$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,100,290,1600,560)
$g.DrawString('MICROSERVICES DOMAIN LAYER', $fontHead, $brushBlack, 730, 302)

$busBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,236,210))
$g.FillRectangle($busBrush, 380, 520, 840, 85)
$g.DrawRectangle($pen,380,520,840,85)
$g.DrawString('EVENT BUS (RabbitMQ + MassTransit)', $fontHead, $brushBlack, 590, 548)

function Bx([int]$x,[int]$y,[int]$w,[int]$h,[string]$title,[string]$sub,[System.Drawing.Color]$color) {
  $b = New-Object System.Drawing.SolidBrush($color)
  $g.FillRectangle($b,$x,$y,$w,$h)
  $g.DrawRectangle($pen,$x,$y,$w,$h)
  $g.DrawString($title,$fontHead,$brushBlack,$x+16,$y+20)
  $g.DrawString($sub,$fontText,$brushBlack,$x+16,$y+58)
  $b.Dispose()
}

Bx 150 360 260 130 'ORDER SERVICE' 'Mã món, Số lượng, Ghi chú' ([System.Drawing.Color]::FromArgb(225,236,255))
Bx 460 360 260 130 'KITCHEN SERVICE' 'FIFO, Processing -> Ready' ([System.Drawing.Color]::FromArgb(240,230,250))
Bx 770 360 260 130 'PAYMENT SERVICE' 'Tổng tiền, Mã giao dịch' ([System.Drawing.Color]::FromArgb(225,245,245))
Bx 1080 360 260 130 'NOTIFICATION SERVICE' 'SignalR/WebSocket realtime' ([System.Drawing.Color]::FromArgb(242,242,242))
Bx 1390 360 260 130 'TABLE SERVICE' 'Cập nhật trạng thái bàn' ([System.Drawing.Color]::FromArgb(250,235,228))

$dbBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232,250,232))
$g.FillRectangle($dbBrush, 430, 650, 300, 95)
$g.DrawRectangle($pen,430,650,300,95)
$g.DrawString('SQL Server (Database-per-Service)', $fontText, $brushBlack, 452, 686)
$g.FillRectangle($dbBrush, 790, 650, 180, 95)
$g.DrawRectangle($pen,790,650,180,95)
$g.DrawString('Redis Cache', $fontText, $brushBlack, 828, 686)
$dbBrush.Dispose()

$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80,80,80),2)
$g.DrawLine($linePen,340,185,430,185)
$g.DrawLine($linePen,790,185,860,185)
$g.DrawLine($linePen,610,250,610,360)
$g.DrawLine($linePen,280,490,480,520)
$g.DrawLine($linePen,590,490,620,520)
$g.DrawLine($linePen,900,490,800,520)
$g.DrawLine($linePen,1210,490,1020,520)
$g.DrawLine($linePen,1520,490,1180,520)
$g.DrawLine($linePen,580,605,580,650)
$g.DrawLine($linePen,880,605,880,650)

$g.DrawString('Luồng chính: OrderCreated -> Kitchen xử lý -> OrderPrepared -> Notification -> PaymentSuccess', $fontSmall, $brushBlack, 330, 780)
$g.DrawString('Nhóm 1 | Mục b: Biểu đồ kiến trúc trực quan', $fontSmall, $brushBlack, 730, 820)

$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)
$linePen.Dispose(); $boundaryPen.Dispose(); $busBrush.Dispose(); $gwBrush.Dispose(); $idBrush.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontHead.Dispose(); $fontText.Dispose(); $fontSmall.Dispose()
$g.Dispose(); $bmp.Dispose()
Write-Output $out
