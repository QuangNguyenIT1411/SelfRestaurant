$ErrorActionPreference = 'Stop'

$base = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$docFinal = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdfFinal = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'
$docTemp = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1_rewrite.docx'
$diagramPath = Join-Path $base '.runlogs\diagram_eventbus_vn.png'
$backup = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1.before_rewrite_by_user_content.docx'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force

if (Test-Path $docFinal) {
  Copy-Item -LiteralPath $docFinal -Destination $backup -Force
}

# -----------------------------
# 1) Draw architecture diagram (Vietnamese, larger, event-bus centered)
# -----------------------------
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 1800, 980
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

$g.DrawString('SƠ ĐỒ KIẾN TRÚC MICROservices - SELF RESTAURANT WEB', $fontTitle, $brushBlack, 300, 18)
$g.DrawString('Đề tài: Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web', $fontSmall, $brushBlack, 520, 64)

# Client
$g.DrawRectangle($pen,70,130,270,110)
$g.DrawString('CLIENT LAYER', $fontHead, $brushBlack, 130, 142)
$g.DrawString('Tablet khách / Web Admin / POS', $fontText, $brushBlack, 84, 180)

# API Gateway
$gwBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(219,238,255))
$g.FillRectangle($gwBrush, 430, 120, 360, 130)
$g.DrawRectangle($pen,430,120,360,130)
$g.DrawString('API GATEWAY (Ocelot/Kong)', $fontHead, $brushBlack, 495, 150)
$g.DrawString('Routing - Auth - Load Balancing', $fontText, $brushBlack, 492, 185)

# Identity
$idBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,248,225))
$g.FillRectangle($idBrush, 860, 120, 270, 130)
$g.DrawRectangle($pen,860,120,270,130)
$g.DrawString('IDENTITY SERVICE', $fontHead, $brushBlack, 915, 150)
$g.DrawString('JWT / Claims / Refresh Token', $fontText, $brushBlack, 892, 185)

# Core services area boundary
$boundaryPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,145,175),2)
$g.DrawRectangle($boundaryPen,100,290,1600,560)
$g.DrawString('MICROSERVICES DOMAIN LAYER', $fontHead, $brushBlack, 730, 302)

# Event Bus
$busBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,236,210))
$g.FillRectangle($busBrush, 380, 520, 840, 85)
$g.DrawRectangle($pen,380,520,840,85)
$g.DrawString('EVENT BUS (RabbitMQ + MassTransit)', $fontHead, $brushBlack, 590, 548)

function Box([int]$x,[int]$y,[int]$w,[int]$h,[string]$title,[string]$sub,[System.Drawing.Color]$color) {
  $b = New-Object System.Drawing.SolidBrush($color)
  $g.FillRectangle($b,$x,$y,$w,$h)
  $g.DrawRectangle($pen,$x,$y,$w,$h)
  $g.DrawString($title,$fontHead,$brushBlack,$x+16,$y+20)
  $g.DrawString($sub,$fontText,$brushBlack,$x+16,$y+58)
  $b.Dispose()
}

Box 150 360 260 130 'ORDER SERVICE' 'MaMon, SoLuong, GhiChu' ([System.Drawing.Color]::FromArgb(225,236,255))
Box 460 360 260 130 'KITCHEN SERVICE' 'FIFO, Processing -> Ready' ([System.Drawing.Color]::FromArgb(240,230,250))
Box 770 360 260 130 'PAYMENT SERVICE' 'TongTien, MaGiaoDich' ([System.Drawing.Color]::FromArgb(225,245,245))
Box 1080 360 260 130 'NOTIFICATION SERVICE' 'SignalR/WebSocket realtime' ([System.Drawing.Color]::FromArgb(242,242,242))
Box 1390 360 260 130 'TABLE SERVICE' 'Cap nhat trang thai ban' ([System.Drawing.Color]::FromArgb(250,235,228))

# Data stores
$dbBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232,250,232))
$g.FillRectangle($dbBrush, 430, 650, 300, 95)
$g.DrawRectangle($pen,430,650,300,95)
$g.DrawString('SQL Server (Database-per-Service)', $fontText, $brushBlack, 452, 686)
$g.FillRectangle($dbBrush, 790, 650, 180, 95)
$g.DrawRectangle($pen,790,650,180,95)
$g.DrawString('Redis Cache', $fontText, $brushBlack, 828, 686)
$dbBrush.Dispose()

# Arrows/lines
$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80,80,80),2)
$g.DrawLine($linePen,340,185,430,185)   # Client -> Gateway
$g.DrawLine($linePen,790,185,860,185)   # Gateway -> Identity
$g.DrawLine($linePen,610,250,610,360)   # Gateway down to services

# service to event bus
$g.DrawLine($linePen,280,490,480,520)
$g.DrawLine($linePen,590,490,620,520)
$g.DrawLine($linePen,900,490,800,520)
$g.DrawLine($linePen,1210,490,1020,520)
$g.DrawLine($linePen,1520,490,1180,520)

# bus to data
$g.DrawLine($linePen,580,605,580,650)
$g.DrawLine($linePen,880,605,880,650)

$g.DrawString('Luồng chính: OrderCreated -> Kitchen xử lý -> OrderPrepared -> Notification -> PaymentSuccess', $fontSmall, $brushBlack, 330, 780)
$g.DrawString('Nhóm 1 | Mục b: Biểu đồ kiến trúc trực quan', $fontSmall, $brushBlack, 730, 820)

$bmp.Save($diagramPath,[System.Drawing.Imaging.ImageFormat]::Png)
$linePen.Dispose(); $boundaryPen.Dispose(); $busBrush.Dispose(); $gwBrush.Dispose(); $idBrush.Dispose(); $gridPen.Dispose(); $pen.Dispose()
$fontTitle.Dispose(); $fontHead.Dispose(); $fontText.Dispose(); $fontSmall.Dispose()
$g.Dispose(); $bmp.Dispose()

# -----------------------------
# 2) Build Word content from user-provided rewrite
# -----------------------------
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

function Add-Para {
  param([string]$Text,[int]$Align=3,[int]$Size=13,[bool]$Bold=$false,[int]$SpaceAfter=6)
  $sel.Font.Name = 'Times New Roman'
  $sel.Font.Size = $Size
  $sel.Font.Bold = [int]$Bold
  $sel.ParagraphFormat.Alignment = $Align
  $sel.ParagraphFormat.SpaceAfter = $SpaceAfter
  $sel.TypeText($Text)
  $sel.TypeParagraph()
}

# Header
Add-Para 'BÀI TẬP TRÊN LỚP SỐ 2' 1 16 $true 0
Add-Para 'ĐỀ TÀI: Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web' 1 14 $true 10
Add-Para 'Nhóm thực hiện: Nhóm 1' 1 13 $false 16

# PHAN 1
Add-Para 'PHẦN 1: ĐÁNH GIÁ & KIỂM TRA BÀI LÀM HIỆN TẠI' 0 14 $true 8
Add-Para 'Nhận xét chung: Bài làm hiện tại đã đúng hướng về cấu trúc theo mẫu Task 2, tuy nhiên phần mô tả component còn ngắn, chưa thể hiện đủ độ phức tạp của kiến trúc Microservices và chưa khai thác sâu dữ liệu Input/Output từ mẫu thu thập yêu cầu nhóm 1.'
Add-Para 'Các điểm cần bổ sung để đạt điểm cao:' 3 13 $true 4
Add-Para '- Lập luận chặt chẽ hơn lý do chọn Microservices thay cho Monolith (real-time, chịu tải giờ cao điểm, tính độc lập service).'
Add-Para '- Chi tiết hóa component với Input/Output cụ thể (MaMon, SoLuong, GhiChu, TongTien, MaGiaoDich...) và logic xử lý nội bộ.'
Add-Para '- Bổ sung thành phần hạ tầng cốt lõi: API Gateway, Event Bus (RabbitMQ), Identity Service.'

# PHAN 2
Add-Para 'PHẦN 2: NỘI DUNG MỞ RỘNG (A-B-C-D-E)' 0 14 $true 8

Add-Para '1. Yêu cầu 1a - Lựa chọn mẫu kiến trúc & kiểu kiến trúc' 0 14 $true 6
Add-Para 'Nhóm lựa chọn mẫu kiến trúc Microservices (Vi dịch vụ) kết hợp Event-Driven Architecture (Kiến trúc hướng sự kiện).'
Add-Para 'Lý do lựa chọn:' 3 13 $true 4
Add-Para '- Phân tách nghiệp vụ rõ ràng: Kitchen xử lý theo hàng đợi real-time, Payment yêu cầu tính chính xác và bảo mật; lỗi một service không làm sập toàn hệ thống.'
Add-Para '- Khả năng mở rộng: giờ cao điểm có thể scale riêng Order Service và Kitchen Service, không phải nâng toàn bộ ứng dụng.'
Add-Para '- Tính real-time: trạng thái món được cập nhật tức thời qua Message Broker + Notification Service (SignalR), không cần tải lại trang.'

Add-Para '2. Yêu cầu 1b - Biểu đồ mô tả trực quan kiến trúc (vẽ hình)' 0 14 $true 6
Add-Para 'Biểu đồ dưới đây mô tả luồng tổng thể: Client -> API Gateway -> các Microservice, với Event Bus ở trung tâm để truyền thông điệp bất đồng bộ giữa Order, Kitchen, Notification và Payment.'
$pic = $sel.InlineShapes.AddPicture($diagramPath)
$pic.LockAspectRatio = -1
$pic.Width = 500
$sel.Range.ParagraphFormat.Alignment = 1
$sel.TypeParagraph()
$sel.TypeParagraph()

Add-Para '3. Yêu cầu 1c - Mô tả chi tiết các thành phần (component)' 0 14 $true 6
Add-Para '3.1 API Gateway (Ocelot/Kong)' 3 13 $true 2
Add-Para '- Chức năng: Cửa ngõ duy nhất nhận request từ Tablet/Web Admin/POS; định tuyến, xác thực và cân bằng tải.'
Add-Para '- Input: HTTP Request từ Client.'
Add-Para '- Output: Request đã định tuyến đến service nội bộ phù hợp.'

Add-Para '3.2 Identity Service' 3 13 $true 2
Add-Para '- Chức năng: Quản lý đăng nhập, cấp Access Token/Refresh Token, quản lý claims cho nhân viên và thiết bị.'
Add-Para '- Input: Username, Password.'
Add-Para '- Output: JWT Token, Refresh Token, User Claims.'

Add-Para '3.3 Order Service' 3 13 $true 2
Add-Para '- Chức năng: Tiếp nhận gọi món, lưu đơn, tính tạm tính.'
Add-Para '- Dữ liệu xử lý: MaMon, SoLuong, GhiChu (ít cay, không hành...).'
Add-Para '- Quy trình: Nhận Order -> Lưu DB -> phát sự kiện OrderCreated vào Event Bus.'
Add-Para '- Output: OrderId, Status = Pending.'

Add-Para '3.4 Kitchen Service' 3 13 $true 2
Add-Para '- Chức năng: Nhận đơn từ hàng đợi, hiển thị FIFO, cập nhật trạng thái Processing -> Ready.'
Add-Para '- Input: Sự kiện OrderCreated từ RabbitMQ.'
Add-Para '- Output: Sự kiện OrderPrepared.'

Add-Para '3.5 Payment Service' 3 13 $true 2
Add-Para '- Chức năng: Tính hóa đơn cuối cùng (thuế, phí, khuyến mãi), xử lý tiền mặt/thẻ, in hóa đơn.'
Add-Para '- Input: OrderId, phương thức thanh toán.'
Add-Para '- Dữ liệu xử lý: TongTien, NgayGioThanhToan, MaGiaoDich.'
Add-Para '- Output: PaymentSuccess, cập nhật bàn về trạng thái Empty.'

Add-Para '3.6 Notification Service' 3 13 $true 2
Add-Para '- Chức năng: Lắng nghe sự kiện từ Kitchen và Payment để đẩy thông báo realtime tới tablet khách hàng.'
Add-Para '- Input: OrderPrepared, PaymentSuccess.'
Add-Para '- Output: Popup trạng thái: "Món của bạn đã sẵn sàng" / "Thanh toán thành công".'

Add-Para '4. Yêu cầu 1d - Mô tả chức năng hệ thống theo luồng xử lý' 0 14 $true 6
Add-Para 'Luồng nghiệp vụ chính được thực hiện như sau:'
Add-Para '- Bước 1: Client gửi yêu cầu qua API Gateway; Gateway xác thực và định tuyến tới Order Service.'
Add-Para '- Bước 2: Order Service ghi đơn và phát OrderCreated lên Event Bus.'
Add-Para '- Bước 3: Kitchen Service subscribe sự kiện để xử lý chế biến và phát OrderPrepared khi hoàn tất.'
Add-Para '- Bước 4: Notification Service nhận sự kiện và cập nhật realtime cho khách hàng.'
Add-Para '- Bước 5: Payment Service chốt giao dịch, phát PaymentSuccess và cập nhật trạng thái bàn.'
Add-Para 'Nhờ cơ chế bất đồng bộ qua Event Bus, các service hoạt động độc lập, tăng độ ổn định khi tải cao.'

Add-Para '5. Yêu cầu 1e - Danh sách công nghệ & thư viện' 0 14 $true 6
Add-Para 'Ngăn xếp công nghệ đề xuất trên nền tảng .NET:'

$tbl = $doc.Tables.Add($sel.Range, 9, 3)
$tbl.Borders.Enable = 1
$tbl.Range.Font.Name = 'Times New Roman'
$tbl.Range.Font.Size = 12
$tbl.Cell(1,1).Range.Text = 'Lớp (Layer)'
$tbl.Cell(1,2).Range.Text = 'Công nghệ / Thư viện'
$tbl.Cell(1,3).Range.Text = 'Vai trò'
for ($c=1; $c -le 3; $c++) {
  $tbl.Cell(1,$c).Range.Font.Bold = 1
  $tbl.Cell(1,$c).Range.ParagraphFormat.Alignment = 1
}

$rows = @(
 @('Backend Core','.NET 8 (ASP.NET Core Web API)','Xây dựng các microservice hiệu năng cao.'),
 @('Database','SQL Server 2019','Lưu dữ liệu cấu trúc, áp dụng Database-per-service.'),
 @('Cache','Redis','Lưu session, menu cache, giảm tải truy vấn DB.'),
 @('Message Broker','RabbitMQ + MassTransit','Truyền thông điệp bất đồng bộ giữa service.'),
 @('Communication','gRPC & RESTful API','gRPC nội bộ tốc độ cao, REST cho client ngoài.'),
 @('Real-time','SignalR','Đẩy cập nhật thời gian thực tới client.'),
 @('Gateway','Ocelot','Định tuyến và gom request qua API Gateway.'),
 @('Container','Docker & Docker Compose','Đóng gói triển khai đồng nhất môi trường.')
)
for ($i=0; $i -lt $rows.Count; $i++) {
  $r = $i + 2
  for ($c=0; $c -lt 3; $c++) {
    $tbl.Cell($r,$c+1).Range.Text = $rows[$i][$c]
  }
}
$sel.SetRange($tbl.Range.End, $tbl.Range.End)
$sel.TypeParagraph()
$sel.TypeParagraph()

Add-Para '6. Kết luận' 0 14 $true 6
Add-Para 'Nội dung đã được mở rộng đầy đủ theo yêu cầu đề bài và bám sát dữ liệu yêu cầu nhóm 1: có lập luận kiến trúc rõ ràng, có chi tiết Input/Output cho từng service, có bổ sung API Gateway - Identity - Event Bus, và có biểu đồ trực quan thể hiện đúng luồng bất đồng bộ của hệ thống.'
Add-Para 'Với kiến trúc này, hệ thống quản lý nhà hàng trên nền tảng Web có thể vận hành ổn định ở giờ cao điểm, mở rộng linh hoạt theo từng service và đảm bảo trải nghiệm realtime cho người dùng.'

# normalize all stories to Times New Roman
foreach ($story in $doc.StoryRanges) {
  $story.Font.Name = 'Times New Roman'
}

$wdFormatDocumentDefault = 16
$doc.SaveAs2($docTemp, $wdFormatDocumentDefault)
$doc.ExportAsFixedFormat($pdfFinal, 17)
$doc.Close()
$word.Quit()

# replace final doc
Copy-Item -LiteralPath $docTemp -Destination $docFinal -Force
Remove-Item -LiteralPath $docTemp -Force

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[GC]::Collect(); [GC]::WaitForPendingFinalizers()

Write-Output "updated: $docFinal"
Write-Output "updated: $pdfFinal"
Write-Output "diagram: $diagramPath"
Write-Output "backup: $backup"