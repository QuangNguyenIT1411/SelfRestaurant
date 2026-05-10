$ErrorActionPreference = "Stop"

$root = "http://localhost:5100"
$page = Invoke-WebRequest -Uri "$root/Menu/Index" -UseBasicParsing -TimeoutSec 20
$asset = [regex]::Match($page.Content, 'assets/(index-[^"]+\.js)').Groups[1].Value
$js = Invoke-WebRequest -Uri "$root/assets/$asset" -UseBasicParsing -TimeoutSec 20

[pscustomobject]@{
  routeStatus = $page.StatusCode
  asset = $asset
  hasRefetchIntervalInBackground = $js.Content.Contains("refetchIntervalInBackground")
  hasRefetchOnWindowFocus = $js.Content.Contains("refetchOnWindowFocus")
  hasLiveOrderRefreshInterval = $js.Content.Contains("LIVE_ORDER_REFRESH_INTERVAL_MS")
  hasReadyNotificationsQuery = $js.Content.Contains("readyNotifications")
} | ConvertTo-Json -Depth 4
