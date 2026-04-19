$ErrorActionPreference = 'Stop'
& 'C:\Program Files\dotnet\dotnet.exe' build 'src\Services\SelfRestaurant.Orders.Api\SelfRestaurant.Orders.Api.csproj' -c Release
exit $LASTEXITCODE
