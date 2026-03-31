$root = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'

$services = @(
    @{ Exe = "$root\src\Services\SelfRestaurant.Catalog.Api\bin\Release\net8.0\SelfRestaurant.Catalog.Api.exe"; Url = 'http://localhost:5101' },
    @{ Exe = "$root\src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.exe"; Url = 'http://localhost:5102' },
    @{ Exe = "$root\src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.exe"; Url = 'http://localhost:5103' },
    @{ Exe = "$root\src\Services\SelfRestaurant.Identity.Api\bin\Release\net8.0\SelfRestaurant.Identity.Api.exe"; Url = 'http://localhost:5104' },
    @{ Exe = "$root\src\Services\SelfRestaurant.Billing.Api\bin\Release\net8.0\SelfRestaurant.Billing.Api.exe"; Url = 'http://localhost:5105' },
    @{ Exe = "$root\src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\SelfRestaurant.Gateway.Mvc.exe"; Url = 'http://localhost:5100' }
)

foreach ($svc in $services) {
    $env:ASPNETCORE_URLS = $svc.Url
    $env:ASPNETCORE_ENVIRONMENT = 'Production'
    $name = [System.IO.Path]::GetFileNameWithoutExtension($svc.Exe).Replace('.', '_')
    $stdout = "$root\.runlogs\$name.phase4.out.log"
    $stderr = "$root\.runlogs\$name.phase4.err.log"
    Start-Process -FilePath $svc.Exe -WorkingDirectory (Split-Path $svc.Exe -Parent) -RedirectStandardOutput $stdout -RedirectStandardError $stderr
}

$env:ASPNETCORE_URLS = $null
$env:ASPNETCORE_ENVIRONMENT = $null
