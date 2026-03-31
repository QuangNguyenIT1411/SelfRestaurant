$src='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.submit_temp.docx'
$dst='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\A\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
if(Test-Path $src){
  Copy-Item -LiteralPath $src -Destination $dst -Force
  Remove-Item -LiteralPath $src -Force
  Write-Output 'activated'
}else{
  Write-Output 'src-missing'
}
