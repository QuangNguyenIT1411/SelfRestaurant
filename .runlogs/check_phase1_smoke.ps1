$urls = @(
  'http://localhost:5100/',
  'http://localhost:5101/healthz',
  'http://localhost:5102/healthz',
  'http://localhost:5103/healthz',
  'http://localhost:5104/healthz',
  'http://localhost:5105/healthz',
  'http://localhost:5110/healthz',
  'http://localhost:5110/app/customer',
  'http://localhost:5110/api/gateway/customer/session',
  'http://localhost:5110/api/gateway/customer/branches'
)
foreach ($url in $urls) {
  try {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
    Write-Output "OK $url => $($response.StatusCode)"
    $snippet = $response.Content
    if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0, 180) }
    Write-Output $snippet
  }
  catch {
    Write-Output "FAIL $url => $($_.Exception.Message)"
  }
  Write-Output '---'
}
