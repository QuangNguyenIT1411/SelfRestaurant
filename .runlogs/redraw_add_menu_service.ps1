$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\diagram_eventbus_vn.png'

$bmp = New-Object System.Drawing.Bitmap 1900,1020
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(242,242,242),1)
for ($x=0; $x -le 1900; $x+=24) { $g.DrawLine($gridPen,$x,0,$x,1020) }
for ($y=0; $y -le 1020; $y+=24) { $g.DrawLine($gridPen,0,$y,1900,$y) }

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
$fontTitle = New-Object System.Drawing.Font('Times New Roman',30,[System.Drawing.FontStyle]::Bold)
$fontHead = New-Object System.Drawing.Font('Times New Roman',14,[System.Drawing.FontStyle]::Bold)
$fontText = New-Object System.Drawing.Font('Times New Roman',12)
$fontSmall = New-Object System.Drawing.Font('Times New Roman',11)
$brushBlack = [System.Drawing.Brushes]::Black

$g.DrawString('SƠ ĐỒ KIẾN TRÚC MICROSERVICES - SELF RESTAURANT WEB', $fontTitle, $brushBlack, 245, 18)
$g.DrawString('Đề tài: Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web', $fontSmall, $brushBlack, 565, 68)

# Client
$g.DrawRectangle($pen,70,140,280,115)
$g.DrawString('CLIENT LAYER', $fontHead, $brushBlack, 145, 154)
$g.DrawString('Tablet khách / Web Admin / POS', $fontText, $brushBlack, 84, 194)

# API Gateway
$gwBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(219,238,255))
$g.FillRectangle($gwBrush, 430, 130, 370, 135)
$g.DrawRectangle($pen,430,130,370,135)
$g.DrawString('API GATEWAY (Ocelot/Kong)', $fontHead, $brushBlack, 500, 162)
$g.DrawString('Routing - Auth - Load Balancing', $fontText, $brushBlack, 500, 198)

# Identity
$idBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,248,225))
$g.FillRectangle($idBrush, 880, 130, 300, 135)
$g.DrawRectangle($pen,880,130,300,135)
$g.DrawString('IDENTITY SERVICE', $fontHead, $brushBlack, 960, 162)
$g.DrawString('JWT / Claims / Refresh Token', $fontText, $brushBlack, 930, 198)

# Domain boundary
$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,90,300,1710,640)
$g.DrawString('MICROSERVICES DOMAIN LAYER', $fontHead, $brushBlack, 790, 315)

# Service boxes (now includes Menu Service)
function Bx([int]$x,[int]$y,[int]$w,[int]$h,[string]$title,[string]$sub,[System.Drawing.Color]$color) {
  $b = New-Object System.Drawing.SolidBrush($color)
  $g.FillRectangle($b,$x,$y,$w,$h)
  $g.DrawRectangle($pen,$x,$y,$w,$h)
  $g.DrawString($title,$fontHead,$brushBlack,$x+14,$y+18)
  $g.DrawString($sub,$fontText,$brushBlack,$x+14,$y+58)
  $b.Dispose()
}

$w=240; $h=135; $y=370
Bx 110  $y $w $h 'MENU SERVICE'         'Quản lý danh mục, giá món'            ([System.Drawing.Color]::FromArgb(228,242,225))
Bx 380  $y $w $h 'ORDER SERVICE'        'Mã món, Số lượng, Ghi chú'            ([System.Drawing.Color]::FromArgb(225,236,255))
Bx 650  $y $w $h 'KITCHEN SERVICE'      'FIFO, Processing -> Ready'            ([System.Drawing.Color]::FromArgb(240,230,250))
Bx 920  $y $w $h 'PAYMENT SERVICE'      'Tổng tiền, Mã giao dịch'              ([System.Drawing.Color]::FromArgb(225,245,245))
Bx 1190 $y $w $h 'NOTIFICATION SERVICE' 'SignalR/WebSocket realtime'           ([System.Drawing.Color]::FromArgb(242,242,242))
Bx 1460 $y $w $h 'TABLE SERVICE'        'Cập nhật trạng thái bàn'              ([System.Drawing.Color]::FromArgb(250,235,228))

# Event bus
$busBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,236,210))
$g.FillRectangle($busBrush, 420, 565, 980, 95)
$g.DrawRectangle($pen,420,565,980,95)
$g.DrawString('EVENT BUS (RabbitMQ + MassTransit)', $fontHead, $brushBlack, 700, 600)

# Data
$dbBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232,250,232))
$g.FillRectangle($dbBrush, 500, 710, 340, 105)
$g.DrawRectangle($pen,500,710,340,105)
$g.DrawString('SQL Server (Database-per-Service)', $fontText, $brushBlack, 540, 753)
$g.FillRectangle($dbBrush, 930, 710, 210, 105)
$g.DrawRectangle($pen,930,710,210,105)
$g.DrawString('Redis Cache', $fontText, $brushBlack, 995, 753)
$dbBrush.Dispose()

# Lines
$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(85,85,85),2)
$g.DrawLine($linePen,350,198,430,198)  # client->gateway
$g.DrawLine($linePen,800,198,880,198)  # gateway->identity
$g.DrawLine($linePen,615,265,615,370)  # gateway down

# service->bus
$g.DrawLine($linePen,230,505,540,565)   # menu
$g.DrawLine($linePen,500,505,670,565)   # order
$g.DrawLine($linePen,770,505,810,565)   # kitchen
$g.DrawLine($linePen,1040,505,940,565)  # payment
$g.DrawLine($linePen,1310,505,1110,565) # notification
$g.DrawLine($linePen,1580,505,1260,565) # table

# bus->data
$g.DrawLine($linePen,670,660,670,710)
$g.DrawLine($linePen,1035,660,1035,710)

$g.DrawString('Luồng chính: OrderCreated -> Kitchen xử lý -> OrderPrepared -> Notification -> PaymentSuccess', $fontSmall, $brushBlack, 460, 860)
$g.DrawString('Nhóm 1 | Mục b: Biểu đồ kiến trúc trực quan', $fontSmall, $brushBlack, 790, 900)

$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)
$linePen.Dispose(); $boundaryPen.Dispose(); $busBrush.Dispose(); $gwBrush.Dispose(); $idBrush.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontHead.Dispose(); $fontText.Dispose(); $fontSmall.Dispose()
$g.Dispose(); $bmp.Dispose()
Write-Output $out
