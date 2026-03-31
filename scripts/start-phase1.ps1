param(
    [switch]$Rebuild,
    [switch]$EnableRabbitMq
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$dotnetExe = Join-Path $env:ProgramFiles "dotnet\dotnet.exe"
if (!(Test-Path $dotnetExe)) {
    $dotnetExe = "dotnet"
}

function Invoke-DotnetChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $proc = Start-Process -FilePath $dotnetExe -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "$dotnetExe $($Arguments -join ' ') failed with exit code $($proc.ExitCode)"
    }
}

Write-Host "Stopping old running processes..."
$names = @(
    "SelfRestaurant.Catalog.Api",
    "SelfRestaurant.Orders.Api",
    "SelfRestaurant.Customers.Api",
    "SelfRestaurant.Identity.Api",
    "SelfRestaurant.Billing.Api",
    "SelfRestaurant.Gateway.Mvc"
)
foreach ($n in $names) {
    Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force
}

Write-Host "Preparing LocalDB schema..."
powershell.exe -ExecutionPolicy Bypass -File "$root\sql\setup-localdb.ps1"

if ($Rebuild) {
    Write-Host "Building service binaries..."
    Invoke-DotnetChecked -Arguments @("build", "src\Services\SelfRestaurant.Catalog.Api\SelfRestaurant.Catalog.Api.csproj", "-c", "Release")
    Invoke-DotnetChecked -Arguments @("build", "src\Services\SelfRestaurant.Orders.Api\SelfRestaurant.Orders.Api.csproj", "-c", "Release")
    Invoke-DotnetChecked -Arguments @("build", "src\Services\SelfRestaurant.Customers.Api\SelfRestaurant.Customers.Api.csproj", "-c", "Release")
    Invoke-DotnetChecked -Arguments @("build", "src\Services\SelfRestaurant.Identity.Api\SelfRestaurant.Identity.Api.csproj", "-c", "Release")
    Invoke-DotnetChecked -Arguments @("build", "src\Services\SelfRestaurant.Billing.Api\SelfRestaurant.Billing.Api.csproj", "-c", "Release")
    Invoke-DotnetChecked -Arguments @("build", "src\Gateway\SelfRestaurant.Gateway.Mvc\SelfRestaurant.Gateway.Mvc.csproj", "-c", "Release")
}

# Ensure gateway static assets are available when launching the built exe.
$gatewayWwwrootSource = Join-Path $root "src\Gateway\SelfRestaurant.Gateway.Mvc\wwwroot"
$gatewayWwwrootTarget = Join-Path $root "src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\wwwroot"
if (Test-Path $gatewayWwwrootSource) {
    New-Item -ItemType Directory -Force -Path $gatewayWwwrootTarget | Out-Null
    Copy-Item -Path (Join-Path $gatewayWwwrootSource "*") -Destination $gatewayWwwrootTarget -Recurse -Force
}

$logDir = Join-Path $root ".runlogs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$services = @(
    @{ Name = "catalog"; Exe = "src\Services\SelfRestaurant.Catalog.Api\bin\Release\net8.0\SelfRestaurant.Catalog.Api.exe"; Url = "http://localhost:5101" },
    @{ Name = "orders"; Exe = "src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.exe"; Url = "http://localhost:5102" },
    @{ Name = "customers"; Exe = "src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.exe"; Url = "http://localhost:5103" },
    @{ Name = "identity"; Exe = "src\Services\SelfRestaurant.Identity.Api\bin\Release\net8.0\SelfRestaurant.Identity.Api.exe"; Url = "http://localhost:5104" },
    @{ Name = "billing"; Exe = "src\Services\SelfRestaurant.Billing.Api\bin\Release\net8.0\SelfRestaurant.Billing.Api.exe"; Url = "http://localhost:5105" },
    @{ Name = "gateway"; Exe = "src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\SelfRestaurant.Gateway.Mvc.exe"; Url = "http://localhost:5100" }
)

Write-Host "Starting services..."
foreach ($svc in $services) {
    $exe = Join-Path $root $svc.Exe
    $wd = Split-Path $exe -Parent
    $out = Join-Path $logDir "$($svc.Name).out.log"
    $err = Join-Path $logDir "$($svc.Name).err.log"

    $env:ASPNETCORE_URLS = $svc.Url
    $env:ASPNETCORE_ENVIRONMENT = "Production"
    if ($EnableRabbitMq -and ($svc.Name -in @("orders", "billing"))) {
        $env:RabbitMq__Enabled = "true"
        $env:RabbitMq__Host = "localhost"
        $env:RabbitMq__Port = "5672"
        $env:RabbitMq__Username = "guest"
        $env:RabbitMq__Password = "guest"
        $env:RabbitMq__VirtualHost = "/"
        $env:RabbitMq__Exchange = "selfrestaurant.events"
        $env:RabbitMq__RoutingKeyPrefix = "selfrestaurant"
    }
    else {
        $env:RabbitMq__Enabled = $null
        $env:RabbitMq__Host = $null
        $env:RabbitMq__Port = $null
        $env:RabbitMq__Username = $null
        $env:RabbitMq__Password = $null
        $env:RabbitMq__VirtualHost = $null
        $env:RabbitMq__Exchange = $null
        $env:RabbitMq__RoutingKeyPrefix = $null
    }
    Start-Process -FilePath $exe -WorkingDirectory $wd -RedirectStandardOutput $out -RedirectStandardError $err | Out-Null
}
$env:ASPNETCORE_URLS = $null
$env:ASPNETCORE_ENVIRONMENT = $null
$env:RabbitMq__Enabled = $null
$env:RabbitMq__Host = $null
$env:RabbitMq__Port = $null
$env:RabbitMq__Username = $null
$env:RabbitMq__Password = $null
$env:RabbitMq__VirtualHost = $null
$env:RabbitMq__Exchange = $null
$env:RabbitMq__RoutingKeyPrefix = $null

Start-Sleep -Seconds 3

Write-Host "Health checks:"
$checks = @(
    "http://localhost:5101/healthz",
    "http://localhost:5102/healthz",
    "http://localhost:5103/healthz",
    "http://localhost:5104/healthz",
    "http://localhost:5105/healthz",
    "http://localhost:5100/"
)
foreach ($url in $checks) {
    try {
        $res = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        Write-Host "OK  $url => $($res.StatusCode)"
    }
    catch {
        Write-Host "FAIL $url => $($_.Exception.Message)"
    }
}

Write-Host "Done. Logs are in .runlogs/"
