$ProgressPreference = 'SilentlyContinue'
try {
  $r = Invoke-WebRequest 'http://localhost:5100/' -UseBasicParsing -TimeoutSec 10
  Write-Host "gateway=$($r.StatusCode)"
} catch {
  Write-Host "gateway=ERR $($_.Exception.Message)"
}
foreach($u in @('http://localhost:5101/healthz','http://localhost:5102/healthz','http://localhost:5103/healthz','http://localhost:5104/healthz','http://localhost:5105/healthz')) {
  try {
    $r = Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 10
    Write-Host "$u=$($r.StatusCode)"
  } catch {
    Write-Host "$u=ERR $($_.Exception.Message)"
  }
}
Get-Process SelfRestaurant.Catalog.Api,SelfRestaurant.Orders.Api,SelfRestaurant.Customers.Api,SelfRestaurant.Identity.Api,SelfRestaurant.Billing.Api,SelfRestaurant.Gateway.Api -ErrorAction SilentlyContinue |
  Select-Object ProcessName,Id | ConvertTo-Json -Compress
