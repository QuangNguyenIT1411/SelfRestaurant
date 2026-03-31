$src='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx.tmp'
$dst='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
Copy-Item -LiteralPath $src -Destination $dst -Force
Write-Output 'replaced'
