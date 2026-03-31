Add-Type -AssemblyName System.Drawing
$bmpPath='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\Task2_2324802010329_NguyenVinhQuang.bmp'
$pngPath='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\Task2_2324802010329_NguyenVinhQuang.png'
$img=[System.Drawing.Image]::FromFile($bmpPath)
$img.Save($pngPath,[System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Write-Output $pngPath
