$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\part_b_diagram_vn_big.png'

$bmp = New-Object System.Drawing.Bitmap 1700,760
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

# Light grid
$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(242,242,242),1)
for ($x=0; $x -le 1700; $x+=20) { $g.DrawLine($gridPen,$x,0,$x,760) }
for ($y=0; $y -le 760; $y+=20) { $g.DrawLine($gridPen,0,$y,1700,$y) }

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
$fontTitle = New-Object System.Drawing.Font('Times New Roman',30,[System.Drawing.FontStyle]::Bold)
$fontContext = New-Object System.Drawing.Font('Times New Roman',14,[System.Drawing.FontStyle]::Bold)
$fontUse = New-Object System.Drawing.Font('Times New Roman',14)
$fontSmall = New-Object System.Drawing.Font('Times New Roman',12)
$brushText = [System.Drawing.Brushes]::Black

function DrawActor([int]$cx,[int]$y) {
  $p = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2.4)
  $g.DrawEllipse($p,$cx-14,$y,28,28)
  $g.DrawLine($p,$cx,$y+28,$cx,$y+88)
  $g.DrawLine($p,$cx-34,$y+52,$cx+34,$y+52)
  $g.DrawLine($p,$cx,$y+88,$cx-24,$y+126)
  $g.DrawLine($p,$cx,$y+88,$cx+24,$y+126)
  $p.Dispose()
}

function FillC([int]$r,[int]$g,[int]$b){ return [System.Drawing.Color]::FromArgb($r,$g,$b) }

$g.DrawString('SƠ ĐỒ USE CASE - HỆ THỐNG SELF RESTAURANT', $fontTitle, $brushText, 360, 12)
$g.DrawString('(Nhóm 1 - Mục b: Biểu đồ kiến trúc trực quan)', $fontSmall, $brushText, 600, 54)

DrawActor 850 85
$g.DrawString('Actor chính: Nhân viên / Khách hàng', $fontSmall, $brushText, 760, 224)

$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,55,240,1460,470)
$g.DrawString('HỆ THỐNG NHÀ HÀNG TỰ PHỤC VỤ (SELF RESTAURANT)', $fontContext, $brushText, 470, 252)

function DrawContext([int]$x,[int]$y,[int]$w,[int]$h,[string]$title,[System.Drawing.Color]$fill,[string]$u1,[string]$u2,[ref]$centers) {
  $rect = New-Object System.Drawing.Rectangle $x,$y,$w,$h
  $brush = New-Object System.Drawing.SolidBrush($fill)
  $g.FillRectangle($brush,$rect)
  $g.DrawRectangle($pen,$rect)
  $g.DrawString($title,$fontContext,$brushText,$x+10,$y+8)

  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

  $oval1 = New-Object System.Drawing.Rectangle ($x+16),($y+42),($w-32),48
  $g.FillEllipse([System.Drawing.Brushes]::White,$oval1)
  $g.DrawEllipse($pen,$oval1)
  $g.DrawString($u1,$fontUse,$brushText,[System.Drawing.RectangleF]$oval1,$sf)
  $centers.Value += ,([System.Tuple]::Create($oval1.X + [int]($oval1.Width/2), $oval1.Y + [int]($oval1.Height/2)))

  if ($u2 -ne '') {
    $oval2 = New-Object System.Drawing.Rectangle ($x+16),($y+98),($w-32),48
    $g.FillEllipse([System.Drawing.Brushes]::White,$oval2)
    $g.DrawEllipse($pen,$oval2)
    $g.DrawString($u2,$fontUse,$brushText,[System.Drawing.RectangleF]$oval2,$sf)
    $centers.Value += ,([System.Tuple]::Create($oval2.X + [int]($oval2.Width/2), $oval2.Y + [int]($oval2.Height/2)))
  }

  $sf.Dispose()
  $brush.Dispose()
}

$centers=@()
DrawContext 80 300 220 170 'AUTHENTICATION CONTEXT' (FillC 255 245 210) 'Đăng nhập' '' ([ref]$centers)
DrawContext 318 286 250 184 'MENU CATALOG CONTEXT' (FillC 220 240 220) 'Xem danh sách món' 'Tìm kiếm món' ([ref]$centers)
DrawContext 586 286 280 184 'ORDER MANAGEMENT CONTEXT' (FillC 220 230 250) 'Tạo / cập nhật đơn' 'Theo dõi trạng thái đơn' ([ref]$centers)
DrawContext 884 286 250 184 'KITCHEN CONTEXT' (FillC 235 225 245) 'Nhận đơn cho bếp' 'Đánh dấu món hoàn tất' ([ref]$centers)
DrawContext 1152 286 250 184 'PAYMENT CONTEXT' (FillC 220 245 250) 'Thanh toán' 'Xuất hóa đơn' ([ref]$centers)
DrawContext 350 500 260 165 'TABLE CONTEXT' (FillC 245 225 225) 'Đặt / đổi bàn' '' ([ref]$centers)
DrawContext 640 500 270 165 'CUSTOMER CONTEXT' (FillC 250 235 220) 'Lưu lịch sử + điểm' '' ([ref]$centers)
DrawContext 940 500 300 165 'NOTIFICATION CONTEXT' (FillC 240 240 240) 'Gửi thông báo trạng thái' '' ([ref]$centers)

$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80,80,80),1.5)
foreach ($c in $centers) { $g.DrawLine($linePen,850,210,$c.Item1,$c.Item2) }

$g.DrawRectangle($pen,1425,320,245,250)
$g.DrawString('Legend', $fontContext, $brushText, 1510, 328)
$g.DrawString('Authentication -> Auth Service', $fontSmall, $brushText, 1435, 360)
$g.DrawString('Menu Catalog -> Menu Service', $fontSmall, $brushText, 1435, 385)
$g.DrawString('Order Management -> Order Service', $fontSmall, $brushText, 1435, 410)
$g.DrawString('Kitchen -> Kitchen Service', $fontSmall, $brushText, 1435, 435)
$g.DrawString('Payment -> Payment Service', $fontSmall, $brushText, 1435, 460)
$g.DrawString('Table -> Table Service', $fontSmall, $brushText, 1435, 485)
$g.DrawString('Customer -> CRM Service', $fontSmall, $brushText, 1435, 510)
$g.DrawString('Notification -> Notify Service', $fontSmall, $brushText, 1435, 535)
$g.DrawString('Tổng: 8 context | 8 service', $fontContext, $brushText, 1435, 555)

$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)
$linePen.Dispose(); $boundaryPen.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontContext.Dispose(); $fontUse.Dispose(); $fontSmall.Dispose()
$g.Dispose(); $bmp.Dispose()
Write-Output $out
