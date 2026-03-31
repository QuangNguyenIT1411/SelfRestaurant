$ErrorActionPreference = 'Stop'
$root = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$dotnet = 'C:\Program Files\dotnet\dotnet.exe'
$proj = Join-Path $root 'src\Gateway\SelfRestaurant.Gateway.Mvc\SelfRestaurant.Gateway.Mvc.csproj'
$names = @(
  'SelfRestaurant.Catalog.Api',
  'SelfRestaurant.Orders.Api',
  'SelfRestaurant.Customers.Api',
  'SelfRestaurant.Billing.Api',
  'SelfRestaurant.Gateway.Mvc'
)
foreach($n in $names){ Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force }

& $dotnet build $proj -c Release -v minimal
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }

& "$root\.runlogs\start_510.ps1"
