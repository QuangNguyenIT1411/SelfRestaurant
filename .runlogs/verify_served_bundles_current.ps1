$base='http://localhost:5100'
$apps = @(
  @{ name='customer'; page="$base/"; dist='src/Frontend/selfrestaurant-customer-web/dist/assets' },
  @{ name='chef'; page="$base/app/chef"; dist='src/Frontend/selfrestaurant-chef-web/dist/assets' },
  @{ name='cashier'; page="$base/app/cashier"; dist='src/Frontend/selfrestaurant-cashier-web/dist/assets' },
  @{ name='admin'; page="$base/app/admin"; dist='src/Frontend/selfrestaurant-admin-web/dist/assets' }
)
$result = @()
foreach($app in $apps){
  $html = Invoke-WebRequest -Uri $app.page -UseBasicParsing
  $match = [regex]::Match([string]$html.Content, '/assets/[^"'']+\.js')
  $asset = if($match.Success){ $match.Value.TrimStart('/') } else { '' }
  $servedName = [System.IO.Path]::GetFileName($asset)
  $distNames = @(Get-ChildItem $app.dist -Filter '*.js' | Select-Object -ExpandProperty Name)
  $result += [pscustomobject]@{ app=$app.name; pageStatus=[int]$html.StatusCode; servedAsset=$servedName; distContainsServed=($distNames -contains $servedName); distNames=$distNames }
}
$result | ConvertTo-Json -Depth 10
