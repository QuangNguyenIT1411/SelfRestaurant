$ErrorActionPreference = 'Stop'
$root = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$logDir = Join-Path $root '.runlogs\live620'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$services = @(
    @{ Name='catalog'; Exe='src\Services\SelfRestaurant.Catalog.Api\bin\Release\net8.0\SelfRestaurant.Catalog.Api.exe'; Args=@('--urls','http://localhost:6201') },
    @{ Name='orders'; Exe='src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.exe'; Args=@('--urls','http://localhost:6202') },
    @{ Name='customers'; Exe='src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.exe'; Args=@('--urls','http://localhost:6203') },
    @{ Name='billing'; Exe='src\Services\SelfRestaurant.Billing.Api\bin\Release\net8.0\SelfRestaurant.Billing.Api.exe'; Args=@('--urls','http://localhost:6205') },
    @{ Name='gateway'; Exe='src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\SelfRestaurant.Gateway.Mvc.exe'; Args=@('--urls','http://localhost:6200','--Services:Catalog=http://localhost:6201','--Services:Orders=http://localhost:6202','--Services:Customers=http://localhost:6203','--Services:Identity=http://localhost:6203','--Services:Billing=http://localhost:6205') }
)

foreach ($svc in $services) {
    $full = Join-Path $root $svc.Exe
    if (!(Test-Path $full)) {
        throw "Missing binary: $full"
    }

    $name = [System.IO.Path]::GetFileNameWithoutExtension($full)
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force

    $wd = Split-Path $full -Parent
    $out = Join-Path $logDir ("{0}.out.log" -f $svc.Name)
    $err = Join-Path $logDir ("{0}.err.log" -f $svc.Name)
    Start-Process -FilePath $full -ArgumentList $svc.Args -WorkingDirectory $wd -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden | Out-Null
}

Start-Sleep -Seconds 5
foreach ($u in @('http://localhost:6201/healthz','http://localhost:6202/healthz','http://localhost:6203/healthz','http://localhost:6205/healthz','http://localhost:6200/')) {
    try {
        $res = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 5
        Write-Output "$u => $($res.StatusCode)"
    }
    catch {
        Write-Output "$u => FAIL $($_.Exception.Message)"
    }
}
