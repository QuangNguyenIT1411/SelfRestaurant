$resp = Invoke-WebRequest -Uri 'http://localhost:5100/app/customer' -UseBasicParsing -TimeoutSec 20
Write-Output ('Cache-Control=' + $resp.Headers['Cache-Control'])
Write-Output ('Pragma=' + $resp.Headers['Pragma'])
Write-Output ('Expires=' + $resp.Headers['Expires'])
