$ErrorActionPreference='Stop'
$root = (Get-Location).Path
$services = @(
  @{ Name = 'catalog'; Exe = 'src\Services\SelfRestaurant.Catalog.Api\bin\Release\net8.0\SelfRestaurant.Catalog.Api.exe'; Url = 'http://localhost:5101' },
  @{ Name = 'orders'; Exe = 'src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.exe'; Url = 'http://localhost:5102' },
  @{ Name = 'customers'; Exe = 'src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.exe'; Url = 'http://localhost:5103' },
  @{ Name = 'identity'; Exe = 'src\Services\SelfRestaurant.Identity.Api\bin\Release\net8.0\SelfRestaurant.Identity.Api.exe'; Url = 'http://localhost:5104' },
  @{ Name = 'billing'; Exe = 'src\Services\SelfRestaurant.Billing.Api\bin\Release\net8.0\SelfRestaurant.Billing.Api.exe'; Url = 'http://localhost:5105' },
  @{ Name = 'gateway'; Exe = 'src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\SelfRestaurant.Gateway.Mvc.exe'; Url = 'http://localhost:5100' }
)
Get-Process -Name 'SelfRestaurant.Catalog.Api','SelfRestaurant.Orders.Api','SelfRestaurant.Customers.Api','SelfRestaurant.Identity.Api','SelfRestaurant.Billing.Api','SelfRestaurant.Gateway.Mvc' -ErrorAction SilentlyContinue | Stop-Process -Force
foreach($svc in $services){
  $exe = Join-Path $root $svc.Exe
  $wd = Split-Path $exe -Parent
  $out = Join-Path $root ".runlogs\\manual-$($svc.Name).out.log"
  $err = Join-Path $root ".runlogs\\manual-$($svc.Name).err.log"
  $env:ASPNETCORE_URLS = $svc.Url
  $env:ASPNETCORE_ENVIRONMENT = 'Production'
  Start-Process -FilePath $exe -WorkingDirectory $wd -RedirectStandardOutput $out -RedirectStandardError $err | Out-Null
}
$env:ASPNETCORE_URLS = $null
$env:ASPNETCORE_ENVIRONMENT = $null
Start-Sleep -Seconds 5
'launched'
