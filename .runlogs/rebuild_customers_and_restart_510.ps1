$ErrorActionPreference = 'Stop'
$root = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$names = @(
  'SelfRestaurant.Catalog.Api',
  'SelfRestaurant.Orders.Api',
  'SelfRestaurant.Customers.Api',
  'SelfRestaurant.Billing.Api',
  'SelfRestaurant.Gateway.Mvc'
)

foreach ($n in $names) {
  Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force
}

& 'C:\Program Files\dotnet\dotnet.exe' build (Join-Path $root 'src\Services\SelfRestaurant.Customers.Api\SelfRestaurant.Customers.Api.csproj') -c Release

& (Join-Path $root '.runlogs\start_510.ps1')
