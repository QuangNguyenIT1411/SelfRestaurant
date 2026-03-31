$ErrorActionPreference='Stop'
$doc='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$pdf='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.pdf'
$newTitle='Thiết kế và triển khai phần mềm quản lý nhà hàng trên nền tảng Web'

Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
$w=New-Object -ComObject Word.Application
$w.Visible=$false
try {
  $d=$w.Documents.Open($doc,$false,$false)

  $replacePairs = @(
    @('ĐỀ TÀI: KIẾN TRÚC HỆ THỐNG SELF RESTAURANT', 'ĐỀ TÀI: ' + $newTitle),
    @('ĐỀ TÀI: HỆ THỐNG NHÀ HÀNG TỰ PHỤC VỤ (SELF RESTAURANT)', 'ĐỀ TÀI: ' + $newTitle),
    @('Đề tài: Hệ thống nhà hàng tự phục vụ (Self Restaurant)', 'Đề tài: ' + $newTitle),
    @('SELF RESTAURANT', 'PHẦN MỀM QUẢN LÝ NHÀ HÀNG WEB')
  )

  foreach ($pair in $replacePairs) {
    $findText = $pair[0]
    $replaceText = $pair[1]

    $range = $d.Content
    $find = $range.Find
    $find.ClearFormatting()
    $find.Replacement.ClearFormatting()
    $find.Text = $findText
    $find.Replacement.Text = $replaceText
    $find.Forward = $true
    $find.Wrap = 1
    $find.Format = $false
    $find.MatchCase = $false
    $find.MatchWholeWord = $false
    $find.MatchWildcards = $false
    $find.Execute([ref]$findText,[ref]$false,[ref]$false,[ref]$false,[ref]$false,[ref]$false,[ref]$true,[ref]1,[ref]$false,[ref]$replaceText,[ref]2) | Out-Null
  }

  $d.Save()
  $d.ExportAsFixedFormat($pdf,17)
  $d.Close()
  Write-Output 'updated title and exported pdf'
}
finally {
  try{$w.Quit()}catch{}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
