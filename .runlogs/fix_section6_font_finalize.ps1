$ErrorActionPreference='Stop'
$doc='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdf='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
$w=New-Object -ComObject Word.Application
$w.Visible=$false
try {
  $d=$w.Documents.Open($doc,$false,$false)
  $start = 0
  for ($i=1; $i -le $d.Paragraphs.Count; $i++) {
    if ($d.Paragraphs.Item($i).Range.Text.Trim() -eq '6. Kết luận') { $start = $i; break }
  }

  if ($start -gt 0) {
    $h = $d.Paragraphs.Item($start).Range
    $h.Font.Name = 'Times New Roman'
    $h.Font.Size = 14
    $h.Font.Bold = 1
    $h.Font.Italic = 0
    $h.ParagraphFormat.Alignment = 0
    $h.ParagraphFormat.SpaceAfter = 6

    for ($j=$start+1; $j -le [Math]::Min($start+4, $d.Paragraphs.Count); $j++) {
      $r = $d.Paragraphs.Item($j).Range
      if ($r.Text.Trim().Length -gt 0) {
        $r.Font.Name = 'Times New Roman'
        $r.Font.Size = 13
        $r.Font.Bold = 0
        $r.Font.Italic = 0
        $r.Font.Underline = 0
        $r.ParagraphFormat.Alignment = 3
        $r.ParagraphFormat.SpaceAfter = 6
      }
    }
  }

  $d.Save()
  $d.ExportAsFixedFormat($pdf,17)
  $d.Close()
  Write-Output 'section 6 normalized'
}
finally {
  try{$w.Quit()}catch{}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
