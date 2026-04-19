try {
  $r = Invoke-WebRequest -Uri 'http://localhost:5110/app/cashier' -UseBasicParsing -TimeoutSec 10
  Write-Host $r.StatusCode
}
catch {
  Write-Host $_.Exception.Message
}
