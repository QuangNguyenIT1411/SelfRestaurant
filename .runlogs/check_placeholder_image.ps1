$resp = Invoke-WebRequest -Uri 'http://localhost:5100/images/placeholder-dish.svg' -UseBasicParsing -TimeoutSec 20
Write-Output ('Status=' + $resp.StatusCode)
Write-Output ('Content-Type=' + $resp.Headers['Content-Type'])
