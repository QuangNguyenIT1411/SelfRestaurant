$ErrorActionPreference = "Stop"

$root = "http://localhost:5100"
$page = Invoke-WebRequest -Uri "$root/app/admin/Admin/Ingredients/Index" -UseBasicParsing -TimeoutSec 20
$asset = [regex]::Match($page.Content, 'assets/(index-[^"]+\.js)').Groups[1].Value
$css = [regex]::Match($page.Content, 'assets/(index-[^"]+\.css)').Groups[1].Value
$js = Invoke-WebRequest -Uri "$root/app/admin/assets/$asset" -UseBasicParsing -TimeoutSec 20
$style = Invoke-WebRequest -Uri "$root/app/admin/assets/$css" -UseBasicParsing -TimeoutSec 20

[pscustomobject]@{
  routeStatus = $page.StatusCode
  asset = $asset
  css = $css
  hasPrevLabel = $js.Content.Contains("Trang trước")
  hasNextLabel = $js.Content.Contains("Trang sau")
  hasAdminPaginationPageClass = $style.Content.Contains(".admin-pagination-page")
  hasAdminPaginationNavClass = $style.Content.Contains(".admin-pagination-nav")
} | ConvertTo-Json -Depth 4
