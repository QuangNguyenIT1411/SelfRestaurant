$ErrorActionPreference='Stop'
$doc='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdf='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
$w=New-Object -ComObject Word.Application
$w.Visible=$false

function Replace-All($d,[string]$find,[string]$rep){
  $rng=$d.Content
  $f=$rng.Find
  $f.ClearFormatting(); $f.Replacement.ClearFormatting()
  $f.Text=$find
  $f.Replacement.Text=$rep
  $f.Forward=$true
  $f.Wrap=1
  $f.Format=$false
  $f.MatchCase=$false
  $f.MatchWholeWord=$false
  $f.MatchWildcards=$false
  $f.Execute([ref]$find,[ref]$false,[ref]$false,[ref]$false,[ref]$false,[ref]$false,[ref]$true,[ref]1,[ref]$false,[ref]$rep,[ref]2) | Out-Null
}

try {
  $d=$w.Documents.Open($doc,$false,$false)

  Replace-All $d '4.4 Order Service- Chức năng:' '4.4 Order Service^p- Chức năng:'
  Replace-All $d '4.5 Kitchen Service- Chức năng:' '4.5 Kitchen Service^p- Chức năng:'
  Replace-All $d '4.6 Payment Service- Chức năng:' '4.6 Payment Service^p- Chức năng:'
  Replace-All $d '4.8 Notification Service- Chức năng:' '4.8 Notification Service^p- Chức năng:'

  # format section 4 headings and body
  $start=0; $end=0
  for($i=1;$i -le $d.Paragraphs.Count;$i++){
    $t=$d.Paragraphs.Item($i).Range.Text.Trim()
    if($t -eq '4. Yêu cầu 1c - Liệt kê và mô tả thành phần (component)'){ $start=$i }
    if($t -eq '5. Yêu cầu 1d - Mô tả chức năng theo luồng nghiệp vụ'){ $end=$i; break }
  }

  if($start -gt 0 -and $end -gt $start){
    for($i=$start;$i -lt $end;$i++){
      $r=$d.Paragraphs.Item($i).Range
      $t=$r.Text.Trim()
      $r.Font.Name='Times New Roman'
      $r.Font.Size=13
      $r.Font.Italic=0
      if($t -match '^4\.[0-9]+\s'){ $r.Font.Bold=1; $r.ParagraphFormat.Alignment=0 }
      elseif($t -eq '4. Yêu cầu 1c - Liệt kê và mô tả thành phần (component)'){ $r.Font.Bold=1; $r.Font.Size=14; $r.ParagraphFormat.Alignment=0 }
      else { $r.Font.Bold=0; $r.ParagraphFormat.Alignment=3 }
      $r.ParagraphFormat.SpaceAfter=6
      $r.ParagraphFormat.LineSpacingRule=0
    }
  }

  $d.Save()
  $d.ExportAsFixedFormat($pdf,17)
  $d.Close()
  Write-Output 'fixed line breaks and formatting for 1c'
}
finally {
  try{$w.Quit()}catch{}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
