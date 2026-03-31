$ErrorActionPreference = 'Stop'
$uri = 'http://localhost:5103/api/identity/admin/employees/18/history?days=90&take=200'
try {
  $r = Invoke-WebRequest $uri -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
  Write-Output "STATUS=$($r.StatusCode)"
  if ($r.Content) {
    $len = [Math]::Min(500, $r.Content.Length)
    Write-Output $r.Content.Substring(0, $len)
  }
}
catch {
  Write-Output "ERR=$($_.Exception.Message)"
}
