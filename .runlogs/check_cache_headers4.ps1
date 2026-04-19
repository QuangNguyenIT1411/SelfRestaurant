$resp = Invoke-WebRequest -Uri 'http://localhost:5100/app/customer' -UseBasicParsing -TimeoutSec 20
$base = $resp.BaseResponse
Write-Output ($base.Headers.ToString())
