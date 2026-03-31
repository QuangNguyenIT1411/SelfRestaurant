$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\current_image1_vn.png'

$bmp = New-Object System.Drawing.Bitmap 1900,980
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(238,238,238),1)
for ($x=0; $x -le 1900; $x+=24) { $g.DrawLine($gridPen,$x,0,$x,980) }
for ($y=0; $y -le 980; $y+=24) { $g.DrawLine($gridPen,0,$y,1900,$y) }

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
$fontTitle = New-Object System.Drawing.Font('Times New Roman',24,[System.Drawing.FontStyle]::Bold)
$fontContext = New-Object System.Drawing.Font('Times New Roman',12,[System.Drawing.FontStyle]::Bold)
$fontUse = New-Object System.Drawing.Font('Times New Roman',11)
$fontSmall = New-Object System.Drawing.Font('Times New Roman',10)
$brushText = [System.Drawing.Brushes]::Black

function VActor([System.Drawing.Graphics]$g, [int]$cx, [int]$y) {
  $p = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
  $g.DrawEllipse($p,$cx-14,$y,28,28)
  $g.DrawLine($p,$cx,$y+28,$cx,$y+90)
  $g.DrawLine($p,$cx-34,$y+52,$cx+34,$y+52)
  $g.DrawLine($p,$cx,$y+90,$cx-24,$y+130)
  $g.DrawLine($p,$cx,$y+90,$cx+24,$y+130)
  $p.Dispose()
}

function FillM([int]$r,[int]$g,[int]$b) { return [System.Drawing.Color]::FromArgb($r,$g,$b) }

$g.DrawString('USE CASE DIAGRAM - SELF RESTAURANT SYSTEM', $fontTitle, $brushText, 530, 18)
$g.DrawString('(Theo style Task2 - Nhóm 1)', $fontSmall, $brushText, 790, 54)

VActor $g 910 95
$g.DrawString('Actor chính: Nhân viên / Khách hàng', $fontSmall, $brushText, 825, 240)

$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,70,280,1560,620)
$g.DrawString('HỆ THỐNG NHÀ HÀNG TỰ PHỤC VỤ (SELF RESTAURANT)', $fontContext, $brushText, 470, 292)

function ContextV([int]$x,[int]$y,[int]$w,[int]$h,[string]$title,[System.Drawing.Color]$fill,[string]$u1,[string]$u2,[ref]$centers) {
  $rect = New-Object System.Drawing.Rectangle $x,$y,$w,$h
  $brush = New-Object System.Drawing.SolidBrush($fill)
  $g.FillRectangle($brush,$rect)
  $g.DrawRectangle($pen,$rect)
  $g.DrawString($title,$fontContext,$brushText,$x+10,$y+10)

  $oval1 = New-Object System.Drawing.Rectangle ($x+18),($y+48),($w-36),44
  $g.FillEllipse([System.Drawing.Brushes]::White,$oval1)
  $g.DrawEllipse($pen,$oval1)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $g.DrawString($u1,$fontUse,$brushText,[System.Drawing.RectangleF]$oval1,$sf)
  $centers.Value += ,([System.Tuple]::Create($oval1.X + [int]($oval1.Width/2), $oval1.Y + [int]($oval1.Height/2)))

  if ($u2 -ne '') {
    $oval2 = New-Object System.Drawing.Rectangle ($x+18),($y+102),($w-36),44
    $g.FillEllipse([System.Drawing.Brushes]::White,$oval2)
    $g.DrawEllipse($pen,$oval2)
    $g.DrawString($u2,$fontUse,$brushText,[System.Drawing.RectangleF]$oval2,$sf)
    $centers.Value += ,([System.Tuple]::Create($oval2.X + [int]($oval2.Width/2), $oval2.Y + [int]($oval2.Height/2)))
  }

  $sf.Dispose()
  $brush.Dispose()
}

$centers = @()
ContextV 95 360 240 170 'AUTHENTICATION CONTEXT' (FillM 255 245 210) 'Đăng nhập' '' ([ref]$centers)
ContextV 355 340 300 210 'MENU CATALOG CONTEXT' (FillM 220 240 220) 'Xem danh sách món' 'Tìm kiếm món' ([ref]$centers)
ContextV 675 340 330 210 'ORDER MANAGEMENT CONTEXT' (FillM 220 230 250) 'Tạo / cập nhật đơn' 'Theo dõi trạng thái đơn' ([ref]$centers)
ContextV 1025 340 290 210 'KITCHEN CONTEXT' (FillM 235 225 245) 'Nhận đơn cho bếp' 'Đánh dấu món hoàn tất' ([ref]$centers)
ContextV 1335 340 270 210 'PAYMENT CONTEXT' (FillM 220 245 250) 'Thanh toán' 'Xuất hóa đơn' ([ref]$centers)
ContextV 500 590 280 170 'TABLE CONTEXT' (FillM 245 225 225) 'Đặt / đổi bàn' '' ([ref]$centers)
ContextV 810 590 280 170 'CUSTOMER CONTEXT' (FillM 250 235 220) 'Lưu lịch sử + điểm' '' ([ref]$centers)
ContextV 1120 590 300 170 'NOTIFICATION CONTEXT' (FillM 240 240 240) 'Gửi thông báo trạng thái' '' ([ref]$centers)

$arrowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,1.3)
foreach ($c in $centers) { $g.DrawLine($arrowPen,910,225,$c.Item1,$c.Item2) }

$g.DrawRectangle($pen,1645,380,220,250)
$g.DrawString('Legend', $fontContext, $brushText, 1725, 390)
$g.DrawString('Authentication -> Auth Service', $fontSmall, $brushText, 1655, 425)
$g.DrawString('Menu Catalog -> Menu Service', $fontSmall, $brushText, 1655, 448)
$g.DrawString('Order Management -> Order Service', $fontSmall, $brushText, 1655, 471)
$g.DrawString('Kitchen -> Kitchen Service', $fontSmall, $brushText, 1655, 494)
$g.DrawString('Payment -> Payment Service', $fontSmall, $brushText, 1655, 517)
$g.DrawString('Table -> Table Service', $fontSmall, $brushText, 1655, 540)
$g.DrawString('Customer -> CRM Service', $fontSmall, $brushText, 1655, 563)
$g.DrawString('Notification -> Notify Service', $fontSmall, $brushText, 1655, 586)
$g.DrawString('Tổng: 8 context | 8 service', $fontContext, $brushText, 1655, 612)

$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)
$arrowPen.Dispose(); $boundaryPen.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontContext.Dispose(); $fontUse.Dispose(); $fontSmall.Dispose()
$g.Dispose(); $bmp.Dispose()
Write-Output $out
