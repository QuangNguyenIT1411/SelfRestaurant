$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\diagram_eventbus_vn_clean.png'

$bmp = New-Object System.Drawing.Bitmap 2100,1180
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(244,244,244),1)
for ($x=0; $x -le 2100; $x+=24) { $g.DrawLine($gridPen,$x,0,$x,1180) }
for ($y=0; $y -le 1180; $y+=24) { $g.DrawLine($gridPen,0,$y,2100,$y) }

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
$syncPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(34,96,191),2.4)
$asyncPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(207,121,33),2.2)
$asyncPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$dbPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(64,120,64),2)

$fontTitle = New-Object System.Drawing.Font('Times New Roman',31,[System.Drawing.FontStyle]::Bold)
$fontHead = New-Object System.Drawing.Font('Times New Roman',15,[System.Drawing.FontStyle]::Bold)
$fontText = New-Object System.Drawing.Font('Times New Roman',12)
$fontSmall = New-Object System.Drawing.Font('Times New Roman',11)
$brushBlack = [System.Drawing.Brushes]::Black

$g.DrawString('SƠ ĐỒ KIẾN TRÚC MICROSERVICES - SELF RESTAURANT WEB', $fontTitle, $brushBlack, 310, 18)
$g.DrawString('Đề tài: Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web', $fontSmall, $brushBlack, 670, 70)

# Top row blocks
$g.DrawRectangle($pen,70,150,280,120)
$g.DrawString('CLIENT LAYER', $fontHead, $brushBlack, 145, 165)
$g.DrawString('Tablet khách / Web Admin / POS', $fontText, $brushBlack, 84, 205)

$gwBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(219,238,255))
$g.FillRectangle($gwBrush, 430, 140, 360, 140)
$g.DrawRectangle($pen,430,140,360,140)
$g.DrawString('API GATEWAY (Ocelot/Kong)', $fontHead, $brushBlack, 500, 174)
$g.DrawString('Routing - Auth - Load Balancing', $fontText, $brushBlack, 500, 211)

$idBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,248,225))
$g.FillRectangle($idBrush, 860, 140, 300, 140)
$g.DrawRectangle($pen,860,140,300,140)
$g.DrawString('IDENTITY SERVICE', $fontHead, $brushBlack, 935, 174)
$g.DrawString('JWT / Claims / Refresh Token', $fontText, $brushBlack, 910, 211)

$sdBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245,245,220))
$g.FillRectangle($sdBrush, 1230, 140, 340, 140)
$g.DrawRectangle($pen,1230,140,340,140)
$g.DrawString('SERVICE DISCOVERY', $fontHead, $brushBlack, 1325, 174)
$g.DrawString('Consul / Eureka (Registry)', $fontText, $brushBlack, 1310, 211)

# Domain boundary
$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,80,330,1940,800)
$g.DrawString('MICROSERVICES DOMAIN LAYER', $fontHead, $brushBlack, 935, 350)

function Svc([int]$x,[string]$title,[string]$sub,[System.Drawing.Color]$color) {
  $w=255; $h=150; $y=420
  $b=New-Object System.Drawing.SolidBrush($color)
  $g.FillRectangle($b,$x,$y,$w,$h)
  $g.DrawRectangle($pen,$x,$y,$w,$h)
  $g.DrawString($title,$fontHead,$brushBlack,$x+14,$y+20)
  $g.DrawString($sub,$fontText,$brushBlack,$x+14,$y+64)
  $b.Dispose()
}

Svc 120  'MENU SERVICE'         'Quản lý danh mục, giá món'    ([System.Drawing.Color]::FromArgb(228,242,225))
Svc 430  'ORDER SERVICE'        'Mã món, Số lượng, Ghi chú'    ([System.Drawing.Color]::FromArgb(225,236,255))
Svc 740  'KITCHEN SERVICE'      'FIFO, Processing -> Ready'    ([System.Drawing.Color]::FromArgb(240,230,250))
Svc 1050 'PAYMENT SERVICE'      'Tổng tiền, Mã giao dịch'      ([System.Drawing.Color]::FromArgb(225,245,245))
Svc 1360 'NOTIFICATION SERVICE' 'SignalR/WebSocket realtime'   ([System.Drawing.Color]::FromArgb(242,242,242))
Svc 1670 'TABLE SERVICE'        'Cập nhật trạng thái bàn'      ([System.Drawing.Color]::FromArgb(250,235,228))

# Event bus
$busBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,236,210))
$g.FillRectangle($busBrush, 520, 670, 1060, 110)
$g.DrawRectangle($pen,520,670,1060,110)
$g.DrawString('EVENT BUS (RabbitMQ + MassTransit)', $fontHead, $brushBlack, 860, 707)
$g.DrawString('Async events: OrderCreated / OrderPrepared / PaymentSuccess', $fontSmall, $brushBlack, 770, 740)

# DB per service
function Dbx([int]$x,[string]$name) {
  $w=260; $h=100; $y=870
  $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232,250,232))
  $g.FillRectangle($b,$x,$y,$w,$h)
  $g.DrawRectangle($dbPen,$x,$y,$w,$h)
  $g.DrawString($name,$fontText,$brushBlack,$x+96,$y+40)
  $b.Dispose()
}
Dbx 120  'MenuDB'
Dbx 430  'OrderDB'
Dbx 740  'KitchenDB'
Dbx 1050 'PaymentDB'
Dbx 1360 'NotificationDB'
Dbx 1670 'TableDB'

# Sync lines (REST/gRPC)
$g.DrawLine($syncPen,350,210,430,210)    # client -> gateway
$g.DrawLine($syncPen,790,210,860,210)    # gateway -> identity
$g.DrawLine($syncPen,1160,210,1230,210)  # identity -> discovery

# gateway fan-out above service boxes
$g.DrawLine($syncPen,610,280,610,385)
$g.DrawLine($syncPen,170,385,1925,385)
$centers = @(247,557,867,1177,1487,1797)
foreach ($cx in $centers) { $g.DrawLine($syncPen,$cx,385,$cx,420) }

# gRPC service-to-service (explicit, above boxes to avoid overlap)
$g.DrawLine($syncPen,557,400,247,400)      # Order -> Menu
$g.DrawLine($syncPen,557,392,1797,392)     # Order -> Table
$g.DrawString('gRPC (sync)', $fontSmall, $brushBlack, 395, 375)
$g.DrawString('gRPC (sync)', $fontSmall, $brushBlack, 1080, 367)

# Async dashed service -> bus (from bottom center, does not cross text)
$svcBottomY = 570
$busTopY = 670
$busTargets = @(650,820,980,1120,1290,1460)
for ($i=0; $i -lt $centers.Count; $i++) {
  $g.DrawLine($asyncPen, $centers[$i], $svcBottomY, $busTargets[$i], $busTopY)
}

# Service -> own DB (solid green)
$dbTopY=870
foreach ($cx in $centers) { $g.DrawLine($dbPen, $cx, $svcBottomY, $cx, $dbTopY) }

# Legend
$g.DrawRectangle($pen,1640,670,320,170)
$g.DrawString('Legend', $fontHead, $brushBlack, 1770, 682)
$g.DrawLine($syncPen,1660,720,1760,720)
$g.DrawString('Sync: REST/gRPC', $fontSmall, $brushBlack, 1770, 712)
$g.DrawLine($asyncPen,1660,755,1760,755)
$g.DrawString('Async: Event Bus', $fontSmall, $brushBlack, 1770, 747)
$g.DrawRectangle($dbPen,1660,785,24,20)
$g.DrawString('Database-per-Service', $fontSmall, $brushBlack, 1694, 786)

$g.DrawString('Nhóm 1 | Mục b: thể hiện sync/async, gRPC service-to-service, database riêng từng service', $fontSmall, $brushBlack, 620, 1020)

$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)

$boundaryPen.Dispose(); $dbPen.Dispose(); $syncPen.Dispose(); $asyncPen.Dispose(); $busBrush.Dispose();
$gwBrush.Dispose(); $idBrush.Dispose(); $sdBrush.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontHead.Dispose(); $fontText.Dispose(); $fontSmall.Dispose(); $g.Dispose(); $bmp.Dispose()
Write-Output $out
