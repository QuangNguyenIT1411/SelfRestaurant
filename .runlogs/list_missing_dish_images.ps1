$ErrorActionPreference = 'Stop'
$baseCatalog = 'http://localhost:5101'
$webRoot = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\src\Gateway\SelfRestaurant.Gateway.Mvc\wwwroot'

function Slug([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return '' }
  $normalized = $name.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  $prevDash = $false
  foreach ($ch in $normalized.ToCharArray()) {
    $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($cat -eq [Globalization.UnicodeCategory]::NonSpacingMark) { continue }
    $mapped = switch ($ch) {
      'đ' { 'd' }
      'Đ' { 'd' }
      default { $ch }
    }
    if ([char]::IsLetterOrDigit($mapped)) {
      [void]$sb.Append([char]::ToLowerInvariant($mapped))
      $prevDash = $false
    } elseif (-not $prevDash) {
      [void]$sb.Append('-')
      $prevDash = $true
    }
  }
  return $sb.ToString().Trim('-')
}

$branches = Invoke-RestMethod "$baseCatalog/api/branches"
$missing = @()
foreach ($b in $branches) {
  $menu = Invoke-RestMethod "$baseCatalog/api/branches/$($b.branchId)/menu"
  foreach ($cat in $menu.categories) {
    foreach ($d in $cat.dishes) {
      if (-not $d.available) { continue }
      $slug = Slug $d.name
      if ([string]::IsNullOrWhiteSpace($slug)) { continue }

      $candidates = @(
        "/images/$slug.jpg",
        "/images/$slug.jpeg",
        "/images/$slug.png"
      )

      $found = $false
      foreach ($c in $candidates) {
        $fp = Join-Path $webRoot ($c.TrimStart('/').Replace('/','\\'))
        if (Test-Path $fp) { $found = $true; break }
      }

      if (-not $found) {
        $missing += [pscustomobject]@{
          BranchId = $b.branchId
          DishId = $d.dishId
          DishName = $d.name
          Slug = $slug
          Category = $cat.categoryName
          RawImage = $d.image
        }
      }
    }
  }
}

$missing = $missing | Sort-Object DishName -Unique
"MISSING_COUNT=$($missing.Count)"
$missing | Format-Table -AutoSize
