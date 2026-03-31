$p='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
try {
  $fs=[System.IO.File]::Open($p,'Open','ReadWrite','None')
  $fs.Close()
  Write-Output 'not-locked'
}
catch {
  Write-Output 'locked'
}
