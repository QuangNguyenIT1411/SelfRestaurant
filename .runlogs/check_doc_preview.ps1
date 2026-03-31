$path='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$w=New-Object -ComObject Word.Application
$w.Visible=$false
$d=$w.Documents.Open($path,$false,$true)
for($i=1;$i -le 16;$i++){
  $t=$d.Paragraphs.Item($i).Range.Text.Trim()
  if($t.Length -gt 0){ Write-Output $t }
}
$d.Close()
$w.Quit()
