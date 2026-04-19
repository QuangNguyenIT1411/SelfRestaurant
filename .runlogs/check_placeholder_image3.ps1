Start-Sleep -Seconds 3
$resp = Invoke-WebRequest -Uri 'http://localhost:5100/images/placeholder-dish.svg' -UseBasicParsing -TimeoutSec 20
Write-Output ('Status=' + $resp.StatusCode)
Write-Output ('ContentType=' + $resp.BaseResponse.ContentType)
