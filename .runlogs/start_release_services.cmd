@echo off
set ROOT=C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main
set DOTNET=C:\Program Files\dotnet\dotnet.exe

set ASPNETCORE_ENVIRONMENT=Production

set ASPNETCORE_URLS=http://localhost:5101
start "" "%DOTNET%" "%ROOT%\src\Services\SelfRestaurant.Catalog.Api\bin\Release\net8.0\SelfRestaurant.Catalog.Api.dll"

set ASPNETCORE_URLS=http://localhost:5102
start "" "%DOTNET%" "%ROOT%\src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.dll"

set ASPNETCORE_URLS=http://localhost:5103
start "" "%DOTNET%" "%ROOT%\src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.dll"

set ASPNETCORE_URLS=http://localhost:5104
start "" "%DOTNET%" "%ROOT%\src\Services\SelfRestaurant.Identity.Api\bin\Release\net8.0\SelfRestaurant.Identity.Api.dll"

set ASPNETCORE_URLS=http://localhost:5105
start "" "%DOTNET%" "%ROOT%\src\Services\SelfRestaurant.Billing.Api\bin\Release\net8.0\SelfRestaurant.Billing.Api.dll"

set ASPNETCORE_URLS=http://localhost:5100
start "" "%DOTNET%" "%ROOT%\src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\SelfRestaurant.Gateway.Mvc.dll"
