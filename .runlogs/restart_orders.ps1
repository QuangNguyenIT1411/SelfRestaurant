$root='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$exe=Join-Path $root 'src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.exe'
$wd=Split-Path $exe -Parent
$out=Join-Path $root '.runlogs\orders.out.log'
$err=Join-Path $root '.runlogs\orders.err.log'
$env:ASPNETCORE_URLS='http://localhost:5102'
$env:ASPNETCORE_ENVIRONMENT='Development'
$env:Services__Catalog='http://localhost:5101'
$env:Services__Orders='http://localhost:5102'
$env:Services__Customers='http://localhost:5103'
$env:Services__Identity='http://localhost:5104'
$env:Services__Billing='http://localhost:5105'
Start-Process -FilePath $exe -WorkingDirectory $wd -RedirectStandardOutput $out -RedirectStandardError $err | Out-Null
Start-Sleep -Seconds 3
Invoke-WebRequest -Uri 'http://localhost:5102/readyz' -UseBasicParsing | Select-Object StatusCode,Content | Format-List
