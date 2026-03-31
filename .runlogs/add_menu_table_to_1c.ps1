$ErrorActionPreference='Stop'
$doc='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdf='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'
$bak='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.before_add_menu_table.docx'

Copy-Item -LiteralPath $doc -Destination $bak -Force
Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force

$w=New-Object -ComObject Word.Application
$w.Visible=$false

function Find-ParaIndexExact($d, [string]$target) {
  for ($i=1; $i -le $d.Paragraphs.Count; $i++) {
    $t = $d.Paragraphs.Item($i).Range.Text.Trim()
    if ($t -eq $target) { return $i }
  }
  return 0
}

function Has-ParaContains($d, [string]$needle) {
  for ($i=1; $i -le $d.Paragraphs.Count; $i++) {
    $t = $d.Paragraphs.Item($i).Range.Text.Trim()
    if ($t -like "*$needle*") { return $true }
  }
  return $false
}

function Replace-HeadingText($d, [string]$old, [string]$new) {
  for ($i=1; $i -le $d.Paragraphs.Count; $i++) {
    $p = $d.Paragraphs.Item($i).Range
    $t = $p.Text.Trim()
    if ($t -eq $old) {
      $p.Text = $new
      return
    }
  }
}

try {
  $d=$w.Documents.Open($doc,$false,$false)

  # Insert Menu Service before current Order Service heading (if missing)
  if (-not (Has-ParaContains $d 'Menu Service')) {
    $idxOrder = Find-ParaIndexExact $d '4.3 Order Service'
    if ($idxOrder -eq 0) { $idxOrder = Find-ParaIndexExact $d '4.4 Order Service' }
    if ($idxOrder -gt 0) {
      $r = $d.Paragraphs.Item($idxOrder).Range
      $block = "4.3 Menu Service`r" +
               "- Chức năng: quản lý thực đơn, danh mục món, giá bán và trạng thái món (còn/hết).`r" +
               "- Input: thông tin món ăn (Mã món, Tên món, Giá, Danh mục, Trạng thái).`r" +
               "- Output: danh sách menu cập nhật cho Order Service và giao diện client.`r"
      $r.InsertBefore($block)
    }
  }

  # Insert Table Service before Notification Service heading (if missing)
  if (-not (Has-ParaContains $d 'Table Service')) {
    $idxNoti = Find-ParaIndexExact $d '4.6 Notification Service'
    if ($idxNoti -eq 0) { $idxNoti = Find-ParaIndexExact $d '4.8 Notification Service' }
    if ($idxNoti -gt 0) {
      $r2 = $d.Paragraphs.Item($idxNoti).Range
      $block2 = "4.7 Table Service`r" +
                "- Chức năng: quản lý trạng thái bàn (Empty/Occupied/Reserved), hỗ trợ đổi bàn và đóng bàn sau thanh toán.`r" +
                "- Input: TableId, trạng thái bàn, yêu cầu cập nhật từ Order/Payment Service.`r" +
                "- Output: trạng thái bàn hiện hành phục vụ điều phối khách và vận hành nhà hàng.`r"
      $r2.InsertBefore($block2)
    }
  }

  # Renumber headings for consistency
  Replace-HeadingText $d '4.3 Order Service' '4.4 Order Service'
  Replace-HeadingText $d '4.4 Kitchen Service' '4.5 Kitchen Service'
  Replace-HeadingText $d '4.5 Payment Service' '4.6 Payment Service'
  Replace-HeadingText $d '4.6 Notification Service' '4.8 Notification Service'

  # normalize font in component section
  $start = Find-ParaIndexExact $d '4. Yêu cầu 1c - Liệt kê và mô tả thành phần (component)'
  $end = Find-ParaIndexExact $d '5. Yêu cầu 1d - Mô tả chức năng theo luồng nghiệp vụ'
  if ($start -gt 0 -and $end -gt $start) {
    for ($i=$start; $i -lt $end; $i++) {
      $rg = $d.Paragraphs.Item($i).Range
      $txt = $rg.Text.Trim()
      $rg.Font.Name = 'Times New Roman'
      if ($txt -match '^4\.[0-9]+') {
        $rg.Font.Size = 13
        $rg.Font.Bold = 1
      } else {
        $rg.Font.Size = 13
        $rg.Font.Bold = 0
      }
      $rg.ParagraphFormat.Alignment = 3
      $rg.ParagraphFormat.SpaceAfter = 6
    }
  }

  $d.Save()
  $d.ExportAsFixedFormat($pdf,17)
  $d.Close()
  Write-Output 'updated 1c with Menu/Table and exported pdf'
  Write-Output "backup: $bak"
}
finally {
  try { $w.Quit() } catch {}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
