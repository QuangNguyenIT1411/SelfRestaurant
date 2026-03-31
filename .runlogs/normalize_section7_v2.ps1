$ErrorActionPreference='Stop'
$doc='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1_v2.docx'
$pdf='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1_v2.pdf'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
$w=New-Object -ComObject Word.Application
$w.Visible=$false

try {
  $d=$w.Documents.Open($doc,$false,$false)
  $idx7=0
  for($i=1;$i -le $d.Paragraphs.Count;$i++){
    if($d.Paragraphs.Item($i).Range.Text.Trim() -eq '7. Kết luận'){ $idx7=$i; break }
  }
  if($idx7 -gt 0){
    $h=$d.Paragraphs.Item($idx7).Range
    $h.Font.Name='Times New Roman'; $h.Font.Size=14; $h.Font.Bold=1; $h.Font.Italic=0
    $h.ParagraphFormat.Alignment=0; $h.ParagraphFormat.SpaceAfter=6; $h.ParagraphFormat.LineSpacingRule=0

    for($j=$idx7+1; $j -le $d.Paragraphs.Count; $j++){
      $r=$d.Paragraphs.Item($j).Range
      $t=$r.Text.Trim()
      if($t.Length -gt 0){
        $r.Font.Name='Times New Roman'; $r.Font.Size=13; $r.Font.Bold=0; $r.Font.Italic=0; $r.Font.Underline=0
        $r.ParagraphFormat.Alignment=3; $r.ParagraphFormat.SpaceAfter=6; $r.ParagraphFormat.LineSpacingRule=0
      }
    }
  }

  $d.Save()
  $d.ExportAsFixedFormat($pdf,17)
  $d.Close()
  Write-Output 'section 7 normalized fully'
}
finally {
  try{$w.Quit()}catch{}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
