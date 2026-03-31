$env:ASPNETCORE_ENVIRONMENT='Development'
$env:ASPNETCORE_URLS='https://localhost:7100;http://localhost:5100'
$exe='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\SelfRestaurant.Gateway.Mvc.exe'
$out='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway7100.out.log'
$err='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway7100.err.log'
Remove-Item $out,$err -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $exe -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
Start-Sleep -Seconds 4
Write-Output "PID=$($p.Id)"
try { (Invoke-WebRequest 'https://localhost:7100/' -SkipCertificateCheck -UseBasicParsing -TimeoutSec 8).StatusCode } catch { "HTTPS_ERR: $($_.Exception.Message)" }
try { (Invoke-WebRequest 'http://localhost:5100/' -UseBasicParsing -TimeoutSec 8).StatusCode } catch { "HTTP_ERR: $($_.Exception.Message)" }
