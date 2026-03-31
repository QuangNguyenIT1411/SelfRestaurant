$ErrorActionPreference = 'Stop'
$dotnet = 'C:\Program Files\dotnet\dotnet.exe'
$proj = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\src\Gateway\SelfRestaurant.Gateway.Mvc\SelfRestaurant.Gateway.Mvc.csproj'
& $dotnet build $proj -c Release -v minimal
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
