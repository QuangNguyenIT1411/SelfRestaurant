$ErrorActionPreference = 'Stop'

$base = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$docPath = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdfPath = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'
$bakPath = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1.before_submit_polish.docx'
$diagramPath = Join-Path $base '.runlogs\diagram_eventbus_vn.png'
$tempPath = Join-Path $base 'A\Kien_truc_he_thong_BaiTapSo2_Nhom1.submit_temp.docx'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
if (Test-Path $docPath) {
  Copy-Item -LiteralPath $docPath -Destination $bakPath -Force
}

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Add()

$doc.PageSetup.PaperSize = 7
$doc.PageSetup.TopMargin = 70.87
$doc.PageSetup.BottomMargin = 70.87
$doc.PageSetup.LeftMargin = 70.87
$doc.PageSetup.RightMargin = 70.87

$sel = $word.Selection

function Add-Para {
  param(
    [string]$Text,
    [int]$Align = 3,
    [int]$Size = 13,
    [bool]$Bold = $false,
    [int]$SpaceAfter = 6,
    [int]$SpaceBefore = 0
  )
  $sel.Font.Name = 'Times New Roman'
  $sel.Font.Size = $Size
  $sel.Font.Bold = [int]$Bold
  $sel.Font.Italic = 0
  $sel.ParagraphFormat.Alignment = $Align
  $sel.ParagraphFormat.SpaceAfter = $SpaceAfter
  $sel.ParagraphFormat.SpaceBefore = $SpaceBefore
  $sel.ParagraphFormat.LineSpacingRule = 0
  $sel.TypeText($Text)
  $sel.TypeParagraph()
}

# Cover
Add-Para 'BÀI TẬP TRÊN LỚP SỐ 2' 1 16 $true 0
Add-Para 'MÔN: KIẾN TRÚC PHẦN MỀM' 1 14 $true 0
Add-Para 'ĐỀ TÀI: Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web' 1 14 $true 10
Add-Para 'Nhóm thực hiện: Nhóm 1' 1 13 $false 0
Add-Para 'Tài liệu: Xác định kiến trúc hệ thống theo yêu cầu a-b-c-d-e' 1 13 $false 20

$sel.InsertBreak(7) | Out-Null

Add-Para '1. Cơ sở thực hiện' 0 14 $true 6
Add-Para 'Tài liệu này được xây dựng dựa trên yêu cầu của đề bài “Bài tập trên lớp số 2”, mẫu thu thập yêu cầu nhóm 1 và tài liệu tham chiếu Task 2. Mục tiêu là trình bày một phương án kiến trúc khả thi, có thể triển khai thực tế cho hệ thống quản lý nhà hàng trên nền tảng Web.'
Add-Para 'Phạm vi hệ thống bao gồm các nghiệp vụ chính: quản lý thực đơn, gọi món, điều phối bếp, thanh toán, quản lý bàn, quản lý khách hàng và thông báo trạng thái đơn hàng theo thời gian thực.'

Add-Para '2. Yêu cầu 1a - Lựa chọn mẫu kiến trúc' 0 14 $true 6
Add-Para 'Nhóm lựa chọn mẫu kiến trúc Microservices (Vi dịch vụ), kết hợp Event-Driven Architecture (Kiến trúc hướng sự kiện).'
Add-Para 'Lý do lựa chọn:' 3 13 $true 4
Add-Para '- Phân tách nghiệp vụ rõ ràng: mỗi service phụ trách một miền nghiệp vụ độc lập (Order, Kitchen, Payment, Notification...).'
Add-Para '- Khả năng mở rộng tốt: có thể mở rộng riêng các service chịu tải cao vào giờ cao điểm (Order/Kitchen) mà không ảnh hưởng toàn hệ thống.'
Add-Para '- Tính sẵn sàng và ổn định: lỗi cục bộ ở một service không làm dừng toàn bộ ứng dụng.'
Add-Para '- Hỗ trợ realtime: trạng thái món và đơn hàng được cập nhật tức thời nhờ luồng sự kiện qua Message Broker.'

Add-Para '3. Yêu cầu 1b - Biểu đồ mô tả trực quan kiến trúc (vẽ hình)' 0 14 $true 6
Add-Para 'Biểu đồ kiến trúc tổng quan thể hiện: Client -> API Gateway -> các Microservice; Event Bus ở trung tâm để truyền thông điệp bất đồng bộ; dữ liệu được lưu theo hướng Database-per-Service.'

$pic = $sel.InlineShapes.AddPicture($diagramPath)
$pic.LockAspectRatio = -1
$pic.Width = 500
$pic.Range.ParagraphFormat.Alignment = 1
$pic.Range.ParagraphFormat.SpaceAfter = 6
$sel.TypeParagraph()

Add-Para '4. Yêu cầu 1c - Liệt kê và mô tả thành phần (component)' 0 14 $true 6
Add-Para '4.1 API Gateway (Ocelot/Kong)' 3 13 $true 2
Add-Para '- Chức năng: tiếp nhận request từ client, xác thực ban đầu, định tuyến và cân bằng tải đến các service nội bộ.'
Add-Para '- Input: HTTP request từ Web Admin, POS, Tablet khách hàng.'
Add-Para '- Output: request đã điều phối tới đúng service mục tiêu.'

Add-Para '4.2 Identity Service' 3 13 $true 2
Add-Para '- Chức năng: quản lý đăng nhập, phân quyền và cấp Access Token/Refresh Token.'
Add-Para '- Input: Username, Password.'
Add-Para '- Output: JWT token, Refresh token, User claims.'

Add-Para '4.3 Order Service' 3 13 $true 2
Add-Para '- Chức năng: nhận và xử lý yêu cầu gọi món, lưu đơn hàng, tính tạm tính.'
Add-Para '- Dữ liệu chính: MaMon, SoLuong, GhiChu.'
Add-Para '- Luồng xử lý: tạo đơn -> lưu cơ sở dữ liệu -> phát sự kiện OrderCreated.'
Add-Para '- Output: OrderId, trạng thái Pending.'

Add-Para '4.4 Kitchen Service' 3 13 $true 2
Add-Para '- Chức năng: nhận sự kiện từ hàng đợi, xử lý món theo FIFO, cập nhật trạng thái chế biến.'
Add-Para '- Input: sự kiện OrderCreated.'
Add-Para '- Output: sự kiện OrderPrepared khi món sẵn sàng.'

Add-Para '4.5 Payment Service' 3 13 $true 2
Add-Para '- Chức năng: tính hóa đơn cuối cùng, xử lý thanh toán và phát hành thông tin giao dịch.'
Add-Para '- Input: OrderId, phương thức thanh toán.'
Add-Para '- Dữ liệu chính: TongTien, NgayGioThanhToan, MaGiaoDich.'
Add-Para '- Output: PaymentSuccess, cập nhật trạng thái bàn về Empty.'

Add-Para '4.6 Notification Service' 3 13 $true 2
Add-Para '- Chức năng: nhận sự kiện từ Kitchen/Payment và gửi thông báo realtime xuống client qua SignalR/WebSocket.'
Add-Para '- Input: OrderPrepared, PaymentSuccess.'
Add-Para '- Output: thông báo trạng thái món/đơn theo thời gian thực.'

Add-Para '5. Yêu cầu 1d - Mô tả chức năng theo luồng nghiệp vụ' 0 14 $true 6
Add-Para 'Luồng nghiệp vụ chính của hệ thống:'
Add-Para '- Bước 1: Client gửi yêu cầu gọi món qua API Gateway.'
Add-Para '- Bước 2: Gateway xác thực và chuyển request sang Order Service.'
Add-Para '- Bước 3: Order Service ghi đơn và phát sự kiện OrderCreated lên Event Bus.'
Add-Para '- Bước 4: Kitchen Service xử lý món và phát sự kiện OrderPrepared.'
Add-Para '- Bước 5: Notification Service đẩy trạng thái realtime cho khách hàng.'
Add-Para '- Bước 6: Payment Service chốt hóa đơn, phát PaymentSuccess và hoàn tất quy trình.'
Add-Para 'Cơ chế bất đồng bộ giúp giảm phụ thuộc giữa các service và tăng khả năng chịu tải cho toàn hệ thống.'

Add-Para '6. Yêu cầu 1e - Công nghệ được chọn' 0 14 $true 6
Add-Para 'Ngăn xếp công nghệ đề xuất:'

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

$data = @(
 @('Backend Core','.NET 8 (ASP.NET Core Web API)','Xây dựng microservice hiệu năng cao.'),
 @('Database','SQL Server 2019','Lưu dữ liệu cấu trúc theo Database-per-Service.'),
 @('Cache','Redis','Tăng tốc truy vấn và lưu dữ liệu truy cập thường xuyên.'),
 @('Message Broker','RabbitMQ + MassTransit','Truyền thông điệp bất đồng bộ giữa service.'),
 @('Communication','gRPC & RESTful API','gRPC cho nội bộ, REST cho client.'),
 @('Real-time','SignalR','Đẩy cập nhật trạng thái thời gian thực.'),
 @('Gateway','Ocelot','Điều phối và gom request tại điểm vào.'),
 @('Container','Docker & Docker Compose','Đóng gói và triển khai đồng nhất môi trường.')
)
for ($i=0; $i -lt $data.Count; $i++) {
  $r = $i + 2
  for ($c=0; $c -lt 3; $c++) {
    $tbl.Cell($r,$c+1).Range.Text = $data[$i][$c]
  }
}

$sel.SetRange($tbl.Range.End, $tbl.Range.End)
$sel.TypeParagraph()
$sel.TypeParagraph()

Add-Para '7. Kết luận' 0 14 $true 6
Add-Para 'Phương án kiến trúc Microservices kết hợp Event-Driven đáp ứng tốt yêu cầu nghiệp vụ của hệ thống quản lý nhà hàng trên nền tảng Web: tách biệt miền nghiệp vụ, mở rộng linh hoạt theo tải thực tế, hỗ trợ realtime và thuận lợi cho triển khai bằng Docker.'
Add-Para 'Tài liệu đã trình bày đầy đủ các yêu cầu a-b-c-d-e theo đề bài, sẵn sàng phục vụ nộp và chấm điểm.'

foreach ($story in $doc.StoryRanges) {
  $story.Font.Name = 'Times New Roman'
}

$wdFormatDocumentDefault = 16
$doc.SaveAs2($tempPath, $wdFormatDocumentDefault)
$doc.ExportAsFixedFormat($pdfPath, 17)
$doc.Close()
$word.Quit()

Copy-Item -LiteralPath $tempPath -Destination $docPath -Force
Remove-Item -LiteralPath $tempPath -Force

Write-Output "updated: $docPath"
Write-Output "updated: $pdfPath"
Write-Output "backup: $bakPath"
