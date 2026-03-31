$ErrorActionPreference = 'Stop'

$target = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'

$word = New-Object -ComObject Word.Application
$word.Visible = $false

$doc = $word.Documents.Add()

$doc.PageSetup.PaperSize = 7
$doc.PageSetup.TopMargin = 70.87
$doc.PageSetup.BottomMargin = 70.87
$doc.PageSetup.LeftMargin = 70.87
$doc.PageSetup.RightMargin = 70.87

$normal = $doc.Styles.Item('Normal')
$normal.Font.Name = 'Times New Roman'
$normal.Font.Size = 13
$normal.ParagraphFormat.SpaceAfter = 6
$normal.ParagraphFormat.LineSpacingRule = 0
$normal.ParagraphFormat.Alignment = 3

function Add-Paragraph {
    param(
        [string]$Text,
        [int]$Align = 3,
        [bool]$Bold = $false,
        [int]$Size = 13,
        [int]$SpaceAfter = 6,
        [int]$SpaceBefore = 0
    )
    $p = $doc.Paragraphs.Add()
    $p.Range.Text = $Text
    $p.Range.Font.Name = 'Times New Roman'
    $p.Range.Font.Size = $Size
    $p.Range.Font.Bold = [int]$Bold
    $p.Range.ParagraphFormat.Alignment = $Align
    $p.Range.ParagraphFormat.SpaceAfter = $SpaceAfter
    $p.Range.ParagraphFormat.SpaceBefore = $SpaceBefore
    $p.Range.ParagraphFormat.LineSpacingRule = 0
    $p.Range.InsertParagraphAfter() | Out-Null
}

function Add-Heading {
    param([string]$Text)
    Add-Paragraph -Text $Text -Align 0 -Bold $true -Size 14 -SpaceAfter 8 -SpaceBefore 6
}

Add-Paragraph -Text 'TRƯỜNG ĐẠI HỌC' -Align 1 -Bold $true -Size 14 -SpaceAfter 0
Add-Paragraph -Text 'MÔN: KIẾN TRÚC PHẦN MỀM' -Align 1 -Bold $true -Size 14 -SpaceAfter 0
Add-Paragraph -Text 'BÀI TẬP TRÊN LỚP SỐ 2' -Align 1 -Bold $true -Size 16 -SpaceAfter 12
Add-Paragraph -Text 'ĐỀ TÀI: HỆ THỐNG NHÀ HÀNG TỰ PHỤC VỤ (SELF RESTAURANT)' -Align 1 -Bold $true -Size 14 -SpaceAfter 12
Add-Paragraph -Text 'Nhóm thực hiện: Nhóm 1' -Align 1 -Size 13 -SpaceAfter 0
Add-Paragraph -Text 'Tài liệu: Xác định kiến trúc hệ thống theo yêu cầu đề bài' -Align 1 -Size 13 -SpaceAfter 24
Add-Paragraph -Text 'Ngày hoàn thành: 01/03/2026' -Align 1 -Size 13 -SpaceAfter 24

$doc.Words.Last.InsertBreak(7) | Out-Null

Add-Heading '1. Cơ sở thực hiện và phạm vi tài liệu'
Add-Paragraph 'Tài liệu này được xây dựng dựa trên bộ yêu cầu đã thu thập ở bài tập số 1 (mẫu thu thập yêu cầu nhóm 1) và yêu cầu bài tập trên lớp số 2. Mục tiêu là xác định kiến trúc phù hợp cho đề tài Self Restaurant, mô tả rõ thành phần, chức năng, công nghệ và biểu đồ trực quan dưới dạng hình khối.'
Add-Paragraph 'Phạm vi kiến trúc bao gồm các nhóm nghiệp vụ chính: quản lý menu và món ăn, quản lý bàn/phòng, đặt món tại bàn, xử lý đơn hàng, thanh toán, quản lý khách hàng, quản trị hệ thống, báo cáo thống kê và tích hợp thông báo.'

Add-Heading '2. Yêu cầu 1a: Tên mẫu kiến trúc được chọn'
Add-Paragraph 'Mẫu kiến trúc chính: Microservices Architecture (Kiến trúc vi dịch vụ), triển khai theo hướng Domain-driven decomposition (tách dịch vụ theo miền nghiệp vụ).'
Add-Paragraph 'Các mẫu kiến trúc hỗ trợ, bổ sung:'
Add-Paragraph '1) API Gateway Pattern: Tập trung điểm vào hệ thống, định tuyến request, xác thực và giới hạn truy cập.'
Add-Paragraph '2) Database per Service Pattern: Mỗi microservice sở hữu dữ liệu riêng để giảm phụ thuộc chéo, tăng khả năng mở rộng.'
Add-Paragraph '3) Event-driven Integration Pattern (ở mức bổ trợ): Phát sự kiện nghiệp vụ để đồng bộ dữ liệu mềm giữa các dịch vụ (ví dụ: trạng thái đơn hàng, trạng thái thanh toán).'
Add-Paragraph '4) Containerized Deployment Pattern: Đóng gói từng dịch vụ bằng Docker để triển khai đồng nhất môi trường.'
Add-Paragraph '5) Clean Architecture trong từng service: Tách lớp API, Application, Domain, Infrastructure để tăng khả năng bảo trì và kiểm thử.'

Add-Heading '3. Yêu cầu 1b: Biểu đồ mô tả trực quan kiến trúc dưới dạng hình khối'
Add-Paragraph 'Biểu đồ 1. Kiến trúc tổng quan mức hệ thống (hình khối):' -Bold $true

$range1 = $doc.Paragraphs.Add().Range
$t1 = $doc.Tables.Add($range1, 1, 7)
$t1.Borders.Enable = 1
$t1.Range.Font.Name = 'Times New Roman'
$t1.Range.Font.Size = 12
$t1.Rows.Alignment = 1
$t1.Cell(1,1).Range.Text = "Người dùng`n(Web/Mobile)"
$t1.Cell(1,2).Range.Text = "→"
$t1.Cell(1,3).Range.Text = "API Gateway`n(Xác thực/Định tuyến)"
$t1.Cell(1,4).Range.Text = "→"
$t1.Cell(1,5).Range.Text = "Cụm Microservices`n(Order/Menu/Table/Payment/CRM)"
$t1.Cell(1,6).Range.Text = "→"
$t1.Cell(1,7).Range.Text = "Database theo Service`n+ Message Broker"
for ($c=1; $c -le 7; $c++) {
  $cell = $t1.Cell(1,$c).Range
  $cell.ParagraphFormat.Alignment = 1
  $cell.Font.Bold = [int](($c % 2) -ne 0)
}
$doc.Paragraphs.Add().Range.InsertParagraphAfter() | Out-Null

Add-Paragraph 'Biểu đồ 2. Kiến trúc lớp trong một microservice (Clean Architecture):' -Bold $true
$range2 = $doc.Paragraphs.Add().Range
$t2 = $doc.Tables.Add($range2, 1, 7)
$t2.Borders.Enable = 1
$t2.Range.Font.Name = 'Times New Roman'
$t2.Range.Font.Size = 12
$t2.Cell(1,1).Range.Text = "API Layer`n(Controller)"
$t2.Cell(1,2).Range.Text = "→"
$t2.Cell(1,3).Range.Text = "Application Layer`n(Use case)"
$t2.Cell(1,4).Range.Text = "→"
$t2.Cell(1,5).Range.Text = "Domain Layer`n(Entity/Rule)"
$t2.Cell(1,6).Range.Text = "←"
$t2.Cell(1,7).Range.Text = "Infrastructure Layer`n(DB, Cache, Message, Repo)"
for ($c=1; $c -le 7; $c++) {
  $cell = $t2.Cell(1,$c).Range
  $cell.ParagraphFormat.Alignment = 1
  $cell.Font.Bold = [int](($c % 2) -ne 0)
}
$doc.Paragraphs.Add().Range.InsertParagraphAfter() | Out-Null
Add-Paragraph 'Ghi chú: Hai biểu đồ hình khối trên thể hiện kiến trúc vĩ mô (toàn hệ thống) và kiến trúc vi mô (bên trong từng service), đảm bảo dễ mở rộng và bảo trì.'

Add-Heading '4. Yêu cầu 1c: Liệt kê đầy đủ thành phần (component) trong kiến trúc'
Add-Paragraph 'Bảng thành phần chính của hệ thống:' -Bold $true

$range3 = $doc.Paragraphs.Add().Range
$t3 = $doc.Tables.Add($range3, 15, 4)
$t3.Borders.Enable = 1
$t3.Range.Font.Name = 'Times New Roman'
$t3.Range.Font.Size = 12
$t3.Cell(1,1).Range.Text = 'STT'
$t3.Cell(1,2).Range.Text = 'Component'
$t3.Cell(1,3).Range.Text = 'Loại'
$t3.Cell(1,4).Range.Text = 'Mô tả ngắn'
for ($j=1; $j -le 4; $j++) { $t3.Cell(1,$j).Range.Font.Bold = 1; $t3.Cell(1,$j).Range.ParagraphFormat.Alignment = 1 }

$data = @(
  @('1','Web Client / Mobile Client','Client','Giao diện cho khách hàng, nhân viên, quản lý'),
  @('2','API Gateway','Edge Service','Xác thực token, định tuyến request, logging đầu vào'),
  @('3','Identity Service','Microservice','Quản lý tài khoản, vai trò, phân quyền, đăng nhập'),
  @('4','Menu Service','Microservice','Quản lý danh mục, món ăn, giá, trạng thái phục vụ'),
  @('5','Table Service','Microservice','Quản lý sơ đồ bàn/phòng, tình trạng bàn, giữ bàn'),
  @('6','Order Service','Microservice','Tạo đơn, cập nhật trạng thái, quản lý chi tiết món'),
  @('7','Kitchen Service','Microservice','Điều phối chế biến, hàng chờ bếp, trạng thái món'),
  @('8','Payment Service','Microservice','Xử lý thanh toán, xác nhận giao dịch, hóa đơn'),
  @('9','Customer Service','Microservice','Hồ sơ khách hàng, lịch sử sử dụng, ưu đãi'),
  @('10','Notification Service','Microservice','Gửi thông báo realtime/email cho trạng thái đơn'),
  @('11','Report Service','Microservice','Tổng hợp doanh thu, tần suất món, KPI vận hành'),
  @('12','Database per Service','Data Layer','Mỗi service có schema/database riêng'),
  @('13','Message Broker','Integration','Trao đổi sự kiện bất đồng bộ giữa các service'),
  @('14','Redis Cache','Infra','Cache dữ liệu nóng: menu, bàn, phiên đăng nhập'),
  @('15','Monitoring & Logging','Infra','Theo dõi log, metric, health check toàn hệ thống')
)

for ($i=0; $i -lt $data.Count; $i++) {
  $row = $i + 2
  for ($j=0; $j -lt 4; $j++) {
    $t3.Cell($row,$j+1).Range.Text = $data[$i][$j]
  }
}
for ($r=2; $r -le 15; $r++) { $t3.Cell($r,1).Range.ParagraphFormat.Alignment = 1 }

$doc.Paragraphs.Add().Range.InsertParagraphAfter() | Out-Null

Add-Heading '5. Yêu cầu 1d: Mô tả chức năng của từng component'
Add-Paragraph '5.1. Nhóm truy cập và điều phối:' -Bold $true
Add-Paragraph '- Web/Mobile Client: Hiển thị menu, gọi món, theo dõi trạng thái đơn, thanh toán, phản hồi dịch vụ.'
Add-Paragraph '- API Gateway: Là điểm vào duy nhất, kiểm tra token, chuyển tiếp request đến đúng service và gom response khi cần.'
Add-Paragraph '- Identity Service: Cấp và xác thực JWT, quản lý người dùng/nhóm quyền (Admin, Thu ngân, Bếp, Phục vụ, Khách hàng).'

Add-Paragraph '5.2. Nhóm nghiệp vụ nhà hàng cốt lõi:' -Bold $true
Add-Paragraph '- Menu Service: Quản trị danh mục món, cấu hình combo/tùy chọn, cập nhật giá, bật/tắt món theo ca.'
Add-Paragraph '- Table Service: Quản lý tình trạng bàn (trống/đang phục vụ/đặt trước), gộp/tách bàn, đổi bàn trong ca.'
Add-Paragraph '- Order Service: Tiếp nhận đơn, kiểm tra dữ liệu hợp lệ, tính tạm tính, chuyển trạng thái từ tạo mới đến hoàn tất/hủy.'
Add-Paragraph '- Kitchen Service: Nhận phiếu chế biến, sắp xếp ưu tiên, đánh dấu món đang làm/hoàn thành/hết món.'
Add-Paragraph '- Payment Service: Tính tổng tiền, thuế/khuyến mãi, ghi nhận giao dịch tiền mặt/chuyển khoản/QR, phát hành hóa đơn.'
Add-Paragraph '- Customer Service: Lưu thông tin khách, điểm tích lũy, lịch sử đơn để phục vụ cá nhân hóa ưu đãi.'

Add-Paragraph '5.3. Nhóm hỗ trợ vận hành và quản trị:' -Bold $true
Add-Paragraph '- Notification Service: Gửi tín hiệu cập nhật trạng thái đơn cho màn hình khách, quầy thu ngân và nhân viên phục vụ.'
Add-Paragraph '- Report Service: Tạo báo cáo theo ngày/tuần/tháng, phân tích doanh thu theo món, theo khung giờ và theo ca làm việc.'
Add-Paragraph '- Database per Service: Tách biệt dữ liệu để giảm khóa chéo, tăng tính độc lập khi triển khai và mở rộng.'
Add-Paragraph '- Message Broker: Kết nối sự kiện giữa service, giảm phụ thuộc đồng bộ, hỗ trợ retry khi lỗi tạm thời.'
Add-Paragraph '- Redis Cache: Giảm độ trễ truy xuất dữ liệu thường dùng, giảm tải cho cơ sở dữ liệu chính.'
Add-Paragraph '- Monitoring & Logging: Thu thập log tập trung, theo dõi hiệu năng, cảnh báo sớm lỗi dịch vụ.'

Add-Heading '6. Yêu cầu 1e: Công nghệ được chọn cho từng thành phần'
Add-Paragraph 'Bảng ánh xạ component và công nghệ đề xuất:' -Bold $true

$range4 = $doc.Paragraphs.Add().Range
$t4 = $doc.Tables.Add($range4, 12, 4)
$t4.Borders.Enable = 1
$t4.Range.Font.Name = 'Times New Roman'
$t4.Range.Font.Size = 12
$t4.Cell(1,1).Range.Text = 'STT'
$t4.Cell(1,2).Range.Text = 'Component'
$t4.Cell(1,3).Range.Text = 'Công nghệ phần mềm'
$t4.Cell(1,4).Range.Text = 'Hạ tầng / phần cứng'
for ($j=1; $j -le 4; $j++) { $t4.Cell(1,$j).Range.Font.Bold = 1; $t4.Cell(1,$j).Range.ParagraphFormat.Alignment = 1 }

$tech = @(
  @('1','Web Client','ASP.NET MVC / Razor / HTML-CSS-JS','PC/POS màn hình cảm ứng tại quầy'),
  @('2','API Gateway','YARP / Ocelot, JWT Bearer','Container Docker, reverse proxy'),
  @('3','Các Microservice','ASP.NET Core Web API (.NET 8), MediatR, FluentValidation','Docker containers, VM hoặc server vật lý'),
  @('4','Identity','ASP.NET Identity, JWT, BCrypt','Server ứng dụng nội bộ'),
  @('5','Database per Service','SQL Server / PostgreSQL','SSD server, backup storage'),
  @('6','Message Broker','RabbitMQ hoặc Kafka','Node broker (1-3 node tùy tải)'),
  @('7','Cache','Redis','Bộ nhớ RAM cao để cache dữ liệu nóng'),
  @('8','Observability','Serilog, OpenTelemetry, Prometheus, Grafana','Server giám sát riêng hoặc dùng chung'),
  @('9','CI/CD','GitHub Actions / Azure DevOps','Runner build + container registry'),
  @('10','Triển khai','Docker Compose (môi trường học tập), Kubernetes (mở rộng)','Máy chủ Linux/Windows hỗ trợ container'),
  @('11','Bảo mật','HTTPS/TLS, RBAC, audit log','Firewall, VLAN nội bộ nhà hàng'),
  @('12','Sao lưu và DR','SQL Backup, snapshot định kỳ','NAS/Cloud backup')
)

for ($i=0; $i -lt $tech.Count; $i++) {
  $row = $i + 2
  for ($j=0; $j -lt 4; $j++) {
    $t4.Cell($row,$j+1).Range.Text = $tech[$i][$j]
  }
  $t4.Cell($row,1).Range.ParagraphFormat.Alignment = 1
}

$doc.Paragraphs.Add().Range.InsertParagraphAfter() | Out-Null

Add-Heading '7. Kết luận'
Add-Paragraph 'Kiến trúc Microservices kết hợp API Gateway, Database per Service và Event-driven Integration đáp ứng tốt yêu cầu nghiệp vụ của đề tài Self Restaurant: dễ mở rộng theo từng miền nghiệp vụ, cô lập lỗi tốt hơn kiến trúc nguyên khối và thuận lợi cho triển khai bằng Docker trong phạm vi bài tập trên lớp.'
Add-Paragraph 'Tài liệu hiện tại đã đáp ứng đầy đủ các mục a, b, c, d, e theo đề bài số 2 và sẵn sàng chuyển đổi sang PDF để nộp.'

foreach ($story in $doc.StoryRanges) {
    $story.Font.Name = 'Times New Roman'
    $story.Font.Size = 13
}

$wdFormatDocumentDefault = 16
$doc.SaveAs([ref]$target, [ref]$wdFormatDocumentDefault)

$pdf = [System.IO.Path]::ChangeExtension($target, 'pdf')
$wdExportFormatPDF = 17
$doc.ExportAsFixedFormat($pdf, $wdExportFormatPDF)

$doc.Close()
$word.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[GC]::Collect()
[GC]::WaitForPendingFinalizers()

Write-Output "Updated: $target"
Write-Output "Updated: $pdf"
