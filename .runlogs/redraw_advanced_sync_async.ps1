$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\diagram_eventbus_vn.png'

$bmp = New-Object System.Drawing.Bitmap 2000,1120
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(242,242,242),1)
for ($x=0; $x -le 2000; $x+=24) { $g.DrawLine($gridPen,$x,0,$x,1120) }
for ($y=0; $y -le 1120; $y+=24) { $g.DrawLine($gridPen,0,$y,2000,$y) }

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
$syncPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(39,93,173),2.2)
$asyncPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(207,121,33),2.2)
$asyncPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$dbPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(67,120,67),2)

$fontTitle = New-Object System.Drawing.Font('Times New Roman',30,[System.Drawing.FontStyle]::Bold)
$fontHead = New-Object System.Drawing.Font('Times New Roman',14,[System.Drawing.FontStyle]::Bold)
$fontText = New-Object System.Drawing.Font('Times New Roman',12)
$fontSmall = New-Object System.Drawing.Font('Times New Roman',11)
$brushBlack = [System.Drawing.Brushes]::Black

$g.DrawString('SƠ ĐỒ KIẾN TRÚC MICROSERVICES - SELF RESTAURANT WEB', $fontTitle, $brushBlack, 285, 18)
$g.DrawString('Đề tài: Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web', $fontSmall, $brushBlack, 615, 68)

# Top layer
$g.DrawRectangle($pen,60,150,280,120)
$g.DrawString('CLIENT LAYER', $fontHead, $brushBlack, 135, 166)
$g.DrawString('Tablet khách / Web Admin / POS', $fontText, $brushBlack, 74, 206)

$gwBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(219,238,255))
$g.FillRectangle($gwBrush, 410, 140, 360, 140)
$g.DrawRectangle($pen,410,140,360,140)
$g.DrawString('API GATEWAY (Ocelot/Kong)', $fontHead, $brushBlack, 477, 174)
$g.DrawString('Routing - Auth - Load Balancing', $fontText, $brushBlack, 476, 210)

$idBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,248,225))
$g.FillRectangle($idBrush, 840, 140, 300, 140)
$g.DrawRectangle($pen,840,140,300,140)
$g.DrawString('IDENTITY SERVICE', $fontHead, $brushBlack, 915, 174)
$g.DrawString('JWT / Claims / Refresh Token', $fontText, $brushBlack, 890, 210)

$sdBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245,245,220))
$g.FillRectangle($sdBrush, 1220, 140, 330, 140)
$g.DrawRectangle($pen,1220,140,330,140)
$g.DrawString('SERVICE DISCOVERY', $fontHead, $brushBlack, 1310, 174)
$g.DrawString('Consul / Eureka (Registry)', $fontText, $brushBlack, 1292, 210)

# Domain boundary
$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,80,320,1840,760)
$g.DrawString('MICROSERVICES DOMAIN LAYER', $fontHead, $brushBlack, 860, 338)

function Svc([int]$x,[string]$title,[string]$sub,[System.Drawing.Color]$color) {
  $w=250; $h=140; $y=400
  $b=New-Object System.Drawing.SolidBrush($color)
  $g.FillRectangle($b,$x,$y,$w,$h)
  $g.DrawRectangle($pen,$x,$y,$w,$h)
  $g.DrawString($title,$fontHead,$brushBlack,$x+14,$y+20)
  $g.DrawString($sub,$fontText,$brushBlack,$x+14,$y+62)
  $b.Dispose()
}

$svcY=400
Svc 120  'MENU SERVICE'         'Quản lý danh mục, giá món'    ([System.Drawing.Color]::FromArgb(228,242,225))
Svc 410  'ORDER SERVICE'        'Mã món, Số lượng, Ghi chú'    ([System.Drawing.Color]::FromArgb(225,236,255))
Svc 700  'KITCHEN SERVICE'      'FIFO, Processing -> Ready'    ([System.Drawing.Color]::FromArgb(240,230,250))
Svc 990  'PAYMENT SERVICE'      'Tổng tiền, Mã giao dịch'      ([System.Drawing.Color]::FromArgb(225,245,245))
Svc 1280 'NOTIFICATION SERVICE' 'SignalR/WebSocket realtime'   ([System.Drawing.Color]::FromArgb(242,242,242))
Svc 1570 'TABLE SERVICE'        'Cập nhật trạng thái bàn'      ([System.Drawing.Color]::FromArgb(250,235,228))

# Event bus
$busBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,236,210))
$g.FillRectangle($busBrush, 470, 620, 980, 105)
$g.DrawRectangle($pen,470,620,980,105)
$g.DrawString('EVENT BUS (RabbitMQ + MassTransit)', $fontHead, $brushBlack, 760, 660)
$g.DrawString('Async events: OrderCreated / OrderPrepared / PaymentSuccess', $fontSmall, $brushBlack, 690, 690)

# DB per service
function Dbx([int]$x,[string]$name) {
  $w=255; $h=95; $y=800
  $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232,250,232))
  $g.FillRectangle($b,$x,$y,$w,$h)
  $g.DrawRectangle($dbPen,$x,$y,$w,$h)
  $g.DrawString($name,$fontText,$brushBlack,$x+70,$y+38)
  $b.Dispose()
}
Dbx 120  'MenuDB'
Dbx 395  'OrderDB'
Dbx 670  'KitchenDB'
Dbx 945  'PaymentDB'
Dbx 1220 'NotificationDB'
Dbx 1495 'TableDB'

# Sync lines gateway -> services
$g.DrawLine($syncPen,770,210,840,210)   # gateway -> identity
$g.DrawLine($syncPen,1140,210,1220,210) # identity -> discovery
$g.DrawLine($syncPen,340,210,410,210)   # client -> gateway
$g.DrawLine($syncPen,590,280,590,400)   # gateway down
$g.DrawLine($syncPen,590,360,245,400)
$g.DrawLine($syncPen,590,360,535,400)
$g.DrawLine($syncPen,590,360,825,400)
$g.DrawLine($syncPen,590,360,1115,400)
$g.DrawLine($syncPen,590,360,1405,400)
$g.DrawLine($syncPen,590,360,1695,400)

# Service-to-service gRPC (sync)
$g.DrawLine($syncPen,660,470,410,470)   # Order -> Menu
$g.DrawLine($syncPen,660,500,1570,500)  # Order -> Table
$g.DrawString('gRPC (sync)', $fontSmall, $brushBlack, 515, 448)
$g.DrawString('gRPC (sync)', $fontSmall, $brushBlack, 1000, 478)

# Async lines service -> bus
$g.DrawLine($asyncPen,245,540,620,620)
$g.DrawLine($asyncPen,535,540,760,620)
$g.DrawLine($asyncPen,825,540,900,620)
$g.DrawLine($asyncPen,1115,540,1040,620)
$g.DrawLine($asyncPen,1405,540,1180,620)
$g.DrawLine($asyncPen,1695,540,1320,620)

# Service -> DB lines
$g.DrawLine($dbPen,245,540,245,800)
$g.DrawLine($dbPen,535,540,520,800)
$g.DrawLine($dbPen,825,540,795,800)
$g.DrawLine($dbPen,1115,540,1070,800)
$g.DrawLine($dbPen,1405,540,1345,800)
$g.DrawLine($dbPen,1695,540,1620,800)

# Legend
$g.DrawRectangle($pen,1600,620,280,150)
$g.DrawString('Legend', $fontHead, $brushBlack, 1705, 632)
$g.DrawLine($syncPen,1620,668,1700,668)
$g.DrawString('Sync: REST/gRPC', $fontSmall, $brushBlack, 1710, 660)
$g.DrawLine($asyncPen,1620,700,1700,700)
$g.DrawString('Async: Event Bus', $fontSmall, $brushBlack, 1710, 692)
$g.DrawRectangle($dbPen,1620,726,22,18)
$g.DrawString('Database-per-Service', $fontSmall, $brushBlack, 1650, 724)

$g.DrawString('Nhóm 1 | Mục b: phân tách sync/async, gRPC, database riêng cho từng service', $fontSmall, $brushBlack, 610, 950)

$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)

$boundaryPen.Dispose(); $dbPen.Dispose(); $syncPen.Dispose(); $asyncPen.Dispose(); $busBrush.Dispose();
$gwBrush.Dispose(); $idBrush.Dispose(); $sdBrush.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontHead.Dispose(); $fontText.Dispose(); $fontSmall.Dispose(); $g.Dispose(); $bmp.Dispose()
Write-Output $out
