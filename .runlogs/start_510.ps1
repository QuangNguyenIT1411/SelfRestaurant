$ErrorActionPreference = 'Stop'
$root = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$logDir = Join-Path $root '.runlogs\live510'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$services = @(
    @{ Name='catalog'; Exe='src\Services\SelfRestaurant.Catalog.Api\bin\Release\net8.0\SelfRestaurant.Catalog.Api.exe'; Args=@('--urls','http://localhost:5101') },
    @{ Name='orders'; Exe='src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.exe'; Args=@('--urls','http://localhost:5102') },
    @{ Name='customers'; Exe='src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.exe'; Args=@('--urls','http://localhost:5103') },
    @{ Name='billing'; Exe='src\Services\SelfRestaurant.Billing.Api\bin\Release\net8.0\SelfRestaurant.Billing.Api.exe'; Args=@('--urls','http://localhost:5105') },
    @{ Name='gateway'; Exe='src\Gateway\SelfRestaurant.Gateway.Mvc\bin\Release\net8.0\SelfRestaurant.Gateway.Mvc.exe'; Args=@('--urls','http://localhost:5100','--Services:Catalog=http://localhost:5101','--Services:Orders=http://localhost:5102','--Services:Customers=http://localhost:5103','--Services:Identity=http://localhost:5103','--Services:Billing=http://localhost:5105') }
)

foreach ($svc in $services) {
    $full = Join-Path $root $svc.Exe
    if (!(Test-Path $full)) { throw "Missing binary: $full" }

    $name = [System.IO.Path]::GetFileNameWithoutExtension($full)
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force

    $wd = Split-Path $full -Parent
    $out = Join-Path $logDir ("{0}.out.log" -f $svc.Name)
    $err = Join-Path $logDir ("{0}.err.log" -f $svc.Name)
    Start-Process -FilePath $full -ArgumentList $svc.Args -WorkingDirectory $wd -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden | Out-Null
}

Start-Sleep -Seconds 5
foreach ($u in @('http://localhost:5101/healthz','http://localhost:5102/healthz','http://localhost:5103/healthz','http://localhost:5105/healthz','http://localhost:5100/')) {
    try {
        $res = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 5
        Write-Output "$u => $($res.StatusCode)"
    }
    catch {
        Write-Output "$u => FAIL $($_.Exception.Message)"
    }
}
