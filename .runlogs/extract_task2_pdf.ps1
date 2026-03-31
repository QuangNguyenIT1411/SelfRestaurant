$ErrorActionPreference='Stop'
$pdf='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\Task2_2324802010329_NguyenVinhQuang.pdf'
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\Task2_2324802010329_NguyenVinhQuang.txt'

$w=New-Object -ComObject Word.Application
$w.Visible=$false
try {
  $d=$w.Documents.Open($pdf,$false,$true)
  $wdFormatUnicodeText=7
  $d.SaveAs([ref]$out,[ref]$wdFormatUnicodeText)
  $d.Close()
  Write-Output "saved: $out"
}
finally {
  try{$w.Quit()}catch{}
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($w) | Out-Null
}
