$ErrorActionPreference='Stop'
$doc='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdf='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'
$backup='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.before_section6_font_fix.docx'

Copy-Item -LiteralPath $doc -Destination $backup -Force

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
$w=New-Object -ComObject Word.Application
$w.Visible=$false

try {
  $d=$w.Documents.Open($doc,$false,$false)

  $targetStart = 0
  for ($i=1; $i -le $d.Paragraphs.Count; $i++) {
    $txt = $d.Paragraphs.Item($i).Range.Text.Trim()
    if ($txt -eq '6. Kết luận') {
      $targetStart = $i
      break
    }
  }

  if ($targetStart -gt 0) {
    # Heading
    $p = $d.Paragraphs.Item($targetStart).Range
    $p.Font.Name = 'Times New Roman'
    $p.Font.Size = 14
    $p.Font.Bold = 1
    $p.ParagraphFormat.Alignment = 0   # left
    $p.ParagraphFormat.LineSpacingRule = 0
    $p.ParagraphFormat.SpaceAfter = 6

    # Conclusion body paragraphs right after heading
    for ($j=$targetStart+1; $j -le [Math]::Min($targetStart+4, $d.Paragraphs.Count); $j++) {
      $r = $d.Paragraphs.Item($j).Range
      $txt2 = $r.Text.Trim()
      if ($txt2.Length -gt 0) {
        $r.Font.Name = 'Times New Roman'
        $r.Font.Size = 13
        $r.Font.Bold = 0
        $r.ParagraphFormat.Alignment = 3 # justify
        $r.ParagraphFormat.LineSpacingRule = 0
        $r.ParagraphFormat.SpaceAfter = 6
      }
    }
  }

  $d.Save()
  $d.ExportAsFixedFormat($pdf,17)
  $d.Close()
  Write-Output 'section 6 font updated'
  Write-Output "backup: $backup"
}
finally {
  try{$w.Quit()}catch{}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
