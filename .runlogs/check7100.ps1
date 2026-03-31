[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
try {
  $resp = Invoke-WebRequest -UseBasicParsing https://localhost:7100 -TimeoutSec 20
  Write-Output $resp.StatusCode
}
catch {
  Write-Output $_.Exception.Message
  exit 1
}
