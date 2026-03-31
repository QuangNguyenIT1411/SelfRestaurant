$ErrorActionPreference = 'Stop'
$root = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$proj = Join-Path $root 'src\Services\SelfRestaurant.Customers.Api\SelfRestaurant.Customers.Api.csproj'
$binDll = Join-Path $root 'src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.dll'
$binExe = Join-Path $root 'src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.exe'

Get-Process -Name 'SelfRestaurant.Customers.Api' -ErrorAction SilentlyContinue | Stop-Process -Force

& 'C:\Program Files\dotnet\dotnet.exe' build $proj -c Release -v minimal

Write-Output "BIN_DLL_TIME=$((Get-Item $binDll).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Output "BIN_EXE_TIME=$((Get-Item $binExe).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
