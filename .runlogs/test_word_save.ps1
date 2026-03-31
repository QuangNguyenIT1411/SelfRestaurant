$docPath='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$w=New-Object -ComObject Word.Application
$w.Visible=$false
$d=$w.Documents.Open($docPath,$false,$false)
$d.BuiltInDocumentProperties('Comments').Value = 'test '
$d.Save()
$d.Close()
$w.Quit()
Write-Output 'ok'
