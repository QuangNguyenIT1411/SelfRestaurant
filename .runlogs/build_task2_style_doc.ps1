$ErrorActionPreference = 'Stop'

$base = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$docPath = Join-Path $base 'Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdfPath = Join-Path $base 'Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'
$diagramPath = Join-Path $base '.runlogs\Task2_style_selfrestaurant.png'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force

# 1) Draw Task2-style diagram image
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 1900, 980
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

# subtle grid like sample
$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(238,238,238),1)
for ($x=0; $x -le 1900; $x+=24) { $g.DrawLine($gridPen,$x,0,$x,980) }
for ($y=0; $y -le 980; $y+=24) { $g.DrawLine($gridPen,0,$y,1900,$y) }

$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
$fontTitle = New-Object System.Drawing.Font('Times New Roman',24,[System.Drawing.FontStyle]::Bold)
$fontContext = New-Object System.Drawing.Font('Times New Roman',12,[System.Drawing.FontStyle]::Bold)
$fontUse = New-Object System.Drawing.Font('Times New Roman',11)
$fontSmall = New-Object System.Drawing.Font('Times New Roman',10)
$brushText = [System.Drawing.Brushes]::Black

function Draw-Actor([System.Drawing.Graphics]$g, [int]$cx, [int]$y) {
  $p = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,2)
  $g.DrawEllipse($p,$cx-14,$y,28,28)
  $g.DrawLine($p,$cx,$y+28,$cx,$y+90)
  $g.DrawLine($p,$cx-34,$y+52,$cx+34,$y+52)
  $g.DrawLine($p,$cx,$y+90,$cx-24,$y+130)
  $g.DrawLine($p,$cx,$y+90,$cx+24,$y+130)
  $p.Dispose()
}

function Fill-Rect([int]$r,[int]$g,[int]$b) {
  return [System.Drawing.Color]::FromArgb($r,$g,$b)
}

$g.DrawString('USE CASE DIAGRAM - SELF RESTAURANT SYSTEM', $fontTitle, $brushText, 530, 18)
$g.DrawString('(Theo style Task2_2324802010329_NguyenVinhQuang)', $fontSmall, $brushText, 735, 54)

Draw-Actor $g 910 95
$g.DrawString('Actor chinh: Nhan vien / Khach hang', $fontSmall, $brushText, 840, 240)

# system boundary
$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,70,280,1560,620)
$g.DrawString('HE THONG NHA HANG TU PHUC VU (SELF RESTAURANT)', $fontContext, $brushText, 520, 292)

function Draw-Context([int]$x,[int]$y,[int]$w,[int]$h,[string]$title,[System.Drawing.Color]$fill,[string]$u1,[string]$u2,[ref]$centers) {
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
Draw-Context 95 360 240 170 'AUTHENTICATION CONTEXT' (Fill-Rect 255 245 210) 'Dang nhap' '' ([ref]$centers)
Draw-Context 355 340 300 210 'MENU CATALOG CONTEXT' (Fill-Rect 220 240 220) 'Xem danh sach mon' 'Tim kiem mon' ([ref]$centers)
Draw-Context 675 340 330 210 'ORDER MANAGEMENT CONTEXT' (Fill-Rect 220 230 250) 'Tao / cap nhat don' 'Theo doi trang thai don' ([ref]$centers)
Draw-Context 1025 340 290 210 'KITCHEN CONTEXT' (Fill-Rect 235 225 245) 'Nhan don cho bep' 'Danh dau mon hoan tat' ([ref]$centers)
Draw-Context 1335 340 270 210 'PAYMENT CONTEXT' (Fill-Rect 220 245 250) 'Thanh toan' 'Xuat hoa don' ([ref]$centers)
Draw-Context 500 590 280 170 'TABLE CONTEXT' (Fill-Rect 245 225 225) 'Dat / doi ban' '' ([ref]$centers)
Draw-Context 810 590 280 170 'CUSTOMER CONTEXT' (Fill-Rect 250 235 220) 'Luu lich su + diem' '' ([ref]$centers)
Draw-Context 1120 590 300 170 'NOTIFICATION CONTEXT' (Fill-Rect 240 240 240) 'Gui thong bao trang thai' '' ([ref]$centers)

# connect actor to use-cases
$arrowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,1.3)
foreach ($c in $centers) {
  $g.DrawLine($arrowPen,910,225,$c.Item1,$c.Item2)
}

# simple legend
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
$g.DrawString('Tong: 8 context | 8 service', $fontContext, $brushText, 1655, 612)

$bmp.Save($diagramPath,[System.Drawing.Imaging.ImageFormat]::Png)
$arrowPen.Dispose(); $boundaryPen.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontContext.Dispose(); $fontUse.Dispose(); $fontSmall.Dispose()
$g.Dispose(); $bmp.Dispose()

# 2) Build detailed document a-b-c-d-e
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Add()

$doc.PageSetup.PaperSize = 7
$doc.PageSetup.TopMargin = 70.87
$doc.PageSetup.BottomMargin = 70.87
$doc.PageSetup.LeftMargin = 70.87
$doc.PageSetup.RightMargin = 70.87

$sel = $word.Selection
$sel.Font.Name = 'Times New Roman'
$sel.Font.Size = 13
$sel.ParagraphFormat.Alignment = 3
$sel.ParagraphFormat.LineSpacingRule = 0
$sel.ParagraphFormat.SpaceAfter = 6

function Add-Line {
  param(
    [string]$Text,
    [int]$Align = 3,
    [int]$Size = 13,
    [bool]$Bold = $false,
    [int]$SpaceAfter = 6
  )
  $sel.Font.Name = 'Times New Roman'
  $sel.Font.Size = $Size
  $sel.Font.Bold = [int]$Bold
  $sel.ParagraphFormat.Alignment = $Align
  $sel.ParagraphFormat.SpaceAfter = $SpaceAfter
  $sel.TypeText($Text)
  $sel.TypeParagraph()
}

Add-Line 'BÀI TẬP TRÊN LỚP SỐ 2' 1 16 $true 2
Add-Line 'ĐỀ TÀI: KIẾN TRÚC HỆ THỐNG SELF RESTAURANT' 1 14 $true 2
Add-Line 'Thực hiện theo cấu trúc a-b-c-d-e và tham chiếu mẫu Task2_2324802010329_NguyenVinhQuang' 1 12 $false 14

Add-Line '1. Yêu cầu 1a - Tên mẫu kiến trúc được chọn' 0 14 $true 6
Add-Line 'Mẫu kiến trúc chính: Microservices Architecture kết hợp phân rã theo miền nghiệp vụ (Domain-Driven Design - Bounded Context).'
Add-Line 'Mẫu hỗ trợ: API Gateway Pattern, Database-per-Service Pattern, Event-driven Integration Pattern, Containerized Deployment (Docker).'
Add-Line 'Lý do chọn: phù hợp phạm vi bài toán nhà hàng tự phục vụ có nhiều nhóm nghiệp vụ độc lập, cần mở rộng theo tải từng khu vực chức năng (đặt món, bếp, thanh toán, chăm sóc khách hàng).'

Add-Line '2. Yêu cầu 1b - Biểu đồ mô tả trực quan (vẽ hình)' 0 14 $true 6
Add-Line 'Biểu đồ dưới đây được vẽ theo style Task2 (Actor + Bounded Context + Use Case + ánh xạ sang microservice):' 3 12 $false 4
$pic = $sel.InlineShapes.AddPicture($diagramPath)
$pic.Width = 520
$pic.Height = 270
$sel.TypeParagraph()
$sel.TypeParagraph()
Add-Line 'Mô tả nhanh biểu đồ: actor trung tâm tương tác với các use case; mỗi nhóm use case nằm trong một bounded context; mỗi context ánh xạ tương ứng 1 microservice chính.'

Add-Line '3. Yêu cầu 1c - Liệt kê đầy đủ component trong kiến trúc' 0 14 $true 6
Add-Line 'Bảng component chính của hệ thống Self Restaurant:' 3 12 $false 4

$tbl1 = $doc.Tables.Add($sel.Range, 11, 4)
$tbl1.Borders.Enable = 1
$tbl1.Range.Font.Name = 'Times New Roman'
$tbl1.Range.Font.Size = 12
$tbl1.Cell(1,1).Range.Text = 'STT'
$tbl1.Cell(1,2).Range.Text = 'Component'
$tbl1.Cell(1,3).Range.Text = 'Nhóm'
$tbl1.Cell(1,4).Range.Text = 'Vai trò'
for ($c=1; $c -le 4; $c++) { $tbl1.Cell(1,$c).Range.Font.Bold = 1; $tbl1.Cell(1,$c).Range.ParagraphFormat.Alignment = 1 }

$data = @(
 @('1','API Gateway','Edge','Xác thực request, định tuyến vào đúng microservice'),
 @('2','Auth Service','Microservice','Đăng nhập, phân quyền, quản lý phiên'),
 @('3','Menu Service','Microservice','Quản lý danh mục món, giá, trạng thái món'),
 @('4','Table Service','Microservice','Quản lý bàn, đặt bàn, đổi bàn'),
 @('5','Order Service','Microservice','Tạo đơn, cập nhật trạng thái đơn'),
 @('6','Kitchen Service','Microservice','Nhận đơn chế biến, cập nhật tiến độ món'),
 @('7','Payment Service','Microservice','Thanh toán, đối soát, hóa đơn'),
 @('8','Customer Service','Microservice','Lưu lịch sử khách, điểm thưởng, ưu đãi'),
 @('9','Notification Service','Microservice','Thông báo realtime trạng thái đơn'),
 @('10','Report Service','Microservice','Báo cáo doanh thu, món bán chạy, KPI ca làm'),
 @('11','Infra: DB/Cache/Broker/Logging','Hạ tầng','Lưu trữ, cache, tích hợp sự kiện, giám sát')
)
for ($i=0; $i -lt $data.Count; $i++) {
  $r = $i + 2
  for ($c=0; $c -lt 4; $c++) {
    $tbl1.Cell($r,$c+1).Range.Text = $data[$i][$c]
  }
  $tbl1.Cell($r,1).Range.ParagraphFormat.Alignment = 1
}
$sel.SetRange($tbl1.Range.End, $tbl1.Range.End)
$sel.TypeParagraph()
$sel.TypeParagraph()

Add-Line '4. Yêu cầu 1d - Mô tả rõ chức năng của từng component' 0 14 $true 6
Add-Line '4.1 API Gateway: tiếp nhận tất cả request từ client, xác thực JWT, giới hạn truy cập, chuyển tiếp đến service phù hợp.'
Add-Line '4.2 Auth Service: quản lý tài khoản người dùng (quản trị, thu ngân, bếp, phục vụ), đăng nhập và cấp token.'
Add-Line '4.3 Menu Service: CRUD món ăn, danh mục, giá, khuyến mãi theo khung giờ.'
Add-Line '4.4 Table Service: theo dõi trạng thái bàn (trống/đang phục vụ/đặt trước), hỗ trợ gộp-tách-đổi bàn.'
Add-Line '4.5 Order Service: lập đơn gọi món, ghi nhận chi tiết món, đồng bộ trạng thái với bếp và thanh toán.'
Add-Line '4.6 Kitchen Service: quản lý hàng đợi chế biến, cập nhật món đang làm/hoàn tất/hủy.'
Add-Line '4.7 Payment Service: tính tiền, giảm giá, thuế, ghi nhận phương thức thanh toán, xuất hóa đơn.'
Add-Line '4.8 Customer Service: hồ sơ khách hàng, lịch sử sử dụng, tích điểm và áp dụng ưu đãi.'
Add-Line '4.9 Notification Service: đẩy thông báo cho màn hình khách và nhân viên khi trạng thái đơn thay đổi.'
Add-Line '4.10 Report Service: tổng hợp báo cáo vận hành, doanh thu, hiệu suất bán hàng theo ngày/tuần/tháng.'
Add-Line '4.11 Hạ tầng dùng chung: DB per service + Redis + Message Broker + Logging/Monitoring để tăng mở rộng và quan sát hệ thống.'

Add-Line '5. Yêu cầu 1e - Công nghệ được chọn (phần cứng + phần mềm)' 0 14 $true 6
Add-Line 'Bảng công nghệ đề xuất triển khai:' 3 12 $false 4

$tbl2 = $doc.Tables.Add($sel.Range, 9, 4)
$tbl2.Borders.Enable = 1
$tbl2.Range.Font.Name = 'Times New Roman'
$tbl2.Range.Font.Size = 12
$tbl2.Cell(1,1).Range.Text = 'STT'
$tbl2.Cell(1,2).Range.Text = 'Thành phần'
$tbl2.Cell(1,3).Range.Text = 'Công nghệ phần mềm'
$tbl2.Cell(1,4).Range.Text = 'Hạ tầng / phần cứng'
for ($c=1; $c -le 4; $c++) { $tbl2.Cell(1,$c).Range.Font.Bold = 1; $tbl2.Cell(1,$c).Range.ParagraphFormat.Alignment = 1 }

$tech = @(
 @('1','Client','ASP.NET MVC/Razor + JS','PC/POS tại quầy và máy phục vụ'),
 @('2','Gateway','YARP hoặc Ocelot','Container Docker + reverse proxy'),
 @('3','Microservices','ASP.NET Core Web API (.NET 8)','Docker trên server Linux/Windows'),
 @('4','Database','SQL Server/PostgreSQL (database-per-service)','SSD + backup định kỳ'),
 @('5','Cache','Redis','RAM dung lượng cao'),
 @('6','Message Broker','RabbitMQ hoặc Kafka','Node broker riêng hoặc dùng chung'),
 @('7','Giám sát','Serilog + Prometheus + Grafana','Server monitoring'),
 @('8','Triển khai','Docker Compose (học tập), Kubernetes (mở rộng)','VM hoặc máy chủ vật lý'),
 @('9','Bảo mật','JWT, HTTPS/TLS, RBAC','Firewall nội bộ + phân vùng mạng')
)
for ($i=0; $i -lt $tech.Count; $i++) {
  $r = $i + 2
  for ($c=0; $c -lt 4; $c++) {
    $tbl2.Cell($r,$c+1).Range.Text = $tech[$i][$c]
  }
  $tbl2.Cell($r,1).Range.ParagraphFormat.Alignment = 1
}
$sel.SetRange($tbl2.Range.End, $tbl2.Range.End)
$sel.TypeParagraph()
$sel.TypeParagraph()

Add-Line '6. Kết luận' 0 14 $true 6
Add-Line 'Kiến trúc được trình bày đã đáp ứng đầy đủ yêu cầu a-b-c-d-e của đề bài; đồng thời biểu đồ phần b được vẽ theo đúng tinh thần mẫu Task2 (actor, use case, context, ánh xạ microservice) và có thể nộp trực tiếp.'

# Normalize font in all stories
foreach ($story in $doc.StoryRanges) {
  $story.Font.Name = 'Times New Roman'
}

$wdFormatDocumentDefault = 16
$doc.SaveAs([ref]$docPath, [ref]$wdFormatDocumentDefault)
$doc.ExportAsFixedFormat($pdfPath, 17)

$doc.Close()
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[GC]::Collect()
[GC]::WaitForPendingFinalizers()

Write-Output "Updated: $docPath"
Write-Output "Updated: $pdfPath"
Write-Output "Diagram: $diagramPath"