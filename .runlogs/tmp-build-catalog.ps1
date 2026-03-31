$ErrorActionPreference = 'Continue'
$dotnetExe = 'C:\Program Files\dotnet\dotnet.exe'
Write-Host "DOTNET=$dotnetExe"
& $dotnetExe build 'src\Services\SelfRestaurant.Catalog.Api\SelfRestaurant.Catalog.Api.csproj' -c Release
Write-Host "LASTEXITCODE=$LASTEXITCODE"
