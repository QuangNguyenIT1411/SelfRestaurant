$ErrorActionPreference = 'Stop'
& 'C:\Program Files\dotnet\dotnet.exe' build 'src\Services\SelfRestaurant.Customers.Api\SelfRestaurant.Customers.Api.csproj' -c Release
exit $LASTEXITCODE
