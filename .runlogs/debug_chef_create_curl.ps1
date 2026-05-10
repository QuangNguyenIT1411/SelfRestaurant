$base='http://localhost:5100'
$chef = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/staff/auth/login" -WebSession $chef -ContentType 'application/json' -Body (@{username='chef_hung';password='123456'}|ConvertTo-Json) | Out-Null
$pairs=@()
foreach($c in $chef.Cookies.GetCookies($base)){
  $pairs += "$($c.Name)=$($c.Value)"
}
$cookie = $pairs -join '; '
$ts=Get-Date -Format 'yyyyMMddHHmmss'
$raw = & curl.exe -sS -o - -w "`nHTTPSTATUS:%{http_code}`n" -X POST "$base/api/gateway/staff/chef/dishes" -H "Cookie: $cookie" -F "name=DEL_RT_$ts" -F "price=54321" -F "categoryId=1" -F "description=Dish delete runtime test" -F "unit=phan" -F "isVegetarian=false" -F "isDailySpecial=false" -F "available=true" -F "isActive=true"
Write-Host "RAW_START"
Write-Host $raw
Write-Host "RAW_END"
