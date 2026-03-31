@echo off
"C:\Program Files\dotnet\dotnet.exe" build src\Services\SelfRestaurant.Catalog.Api\SelfRestaurant.Catalog.Api.csproj -c Release
@echo EXITCODE=%ERRORLEVEL%
