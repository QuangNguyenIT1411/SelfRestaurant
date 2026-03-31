$ErrorActionPreference='Stop'
$doc='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1_v2.docx'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
$w=New-Object -ComObject Word.Application
$w.Visible=$false

function Find-ParaIndexContains($d,[string]$needle){
  for($i=1;$i -le $d.Paragraphs.Count;$i++){
    $t=$d.Paragraphs.Item($i).Range.Text.Trim()
    if($t -like "*$needle*"){ return $i }
  }
  return 0
}

function AddAfter($d,[int]$idx,[string]$text){
  $r=$d.Paragraphs.Item($idx).Range
  $r.Collapse(0) | Out-Null
  $r.InsertParagraphAfter() | Out-Null
  $new=$d.Paragraphs.Item($idx+1).Range
  $new.Text=$text
}

try {
  $d=$w.Documents.Open($doc,$false,$false)

  # Update 1b description if old text exists
  $idx1b = Find-ParaIndexContains $d 'Biểu đồ kiến trúc tổng quan thể hiện:'
  if($idx1b -gt 0){
    $d.Paragraphs.Item($idx1b).Range.Text = 'Biểu đồ kiến trúc tổng quan thể hiện đầy đủ ba khía cạnh: (1) giao tiếp đồng bộ (sync) giữa các service bằng REST/gRPC, (2) giao tiếp bất đồng bộ (async) qua Event Bus RabbitMQ + MassTransit, và (3) mô hình Database-per-Service với cơ sở dữ liệu tách riêng cho từng service.'
  }

  # Insert reliability block in 1d if missing
  $idxSD = Find-ParaIndexContains $d 'Service Discovery:'
  if($idxSD -eq 0){
    $anchor = Find-ParaIndexContains $d 'Cơ chế bất đồng bộ giúp giảm phụ thuộc giữa các service và tăng khả năng chịu tải cho toàn hệ thống.'
    if($anchor -gt 0){
      AddAfter $d $anchor 'Các cơ chế vận hành và độ tin cậy được áp dụng:'
      AddAfter $d ($anchor+1) '- Service Discovery: các service đăng ký vào Service Registry (Consul/Eureka) để định vị động endpoint, giảm phụ thuộc cấu hình tĩnh.'
      AddAfter $d ($anchor+2) '- Fault Tolerance: áp dụng Timeout, Circuit Breaker, Retry giới hạn và Fallback để tránh lỗi dây chuyền khi một service gặp sự cố.'
      AddAfter $d ($anchor+3) '- Data Consistency: sử dụng Eventual Consistency giữa các service qua event; mỗi service quản lý dữ liệu cục bộ và đồng bộ trạng thái theo sự kiện.'
      AddAfter $d ($anchor+4) '- Retry / Dead Letter Queue (DLQ): message lỗi được retry theo backoff; nếu vượt ngưỡng sẽ chuyển vào DLQ để theo dõi và xử lý bù.'
    }
  }

  # Format section 7 conclusion
  $idx7 = Find-ParaIndexContains $d '7. Kết luận'
  if($idx7 -gt 0){
    $h=$d.Paragraphs.Item($idx7).Range
    $h.Font.Name='Times New Roman'; $h.Font.Size=14; $h.Font.Bold=1; $h.Font.Italic=0
    $h.ParagraphFormat.Alignment=0; $h.ParagraphFormat.SpaceAfter=6; $h.ParagraphFormat.LineSpacingRule=0

    for($j=$idx7+1; $j -le [Math]::Min($idx7+4,$d.Paragraphs.Count); $j++){
      $r=$d.Paragraphs.Item($j).Range
      $t=$r.Text.Trim()
      if($t.Length -gt 0){
        $r.Font.Name='Times New Roman'; $r.Font.Size=13; $r.Font.Bold=0; $r.Font.Italic=0; $r.Font.Underline=0
        $r.ParagraphFormat.Alignment=3; $r.ParagraphFormat.SpaceAfter=6; $r.ParagraphFormat.LineSpacingRule=0
      }
    }
  }

  $d.Save()
  $d.Close()
  Write-Output 'text and section 7 formatting updated'
}
finally {
  try{$w.Quit()}catch{}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
