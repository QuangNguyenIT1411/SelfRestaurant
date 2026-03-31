$ErrorActionPreference='Stop'
function Tok([string]$h){$ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"'); foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){return $m.Groups[1].Value}}; throw 'no token'}
$root='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='flow20260301094122';$p='Test@123'
$l=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing
$t=Tok $l.Content
$body=@{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t}
$r=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"firstLoginFinal=$($r.BaseResponse.ResponseUri.AbsoluteUri)"
# set table
$tb=Invoke-WebRequest "$root/Home/GetBranchTables?branchId=3" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$av=$tb.tables|Where-Object{$_.isAvailable -eq $true}|Select-Object -First 1
$menu=Invoke-WebRequest "$root/Menu/Index?tableId=$($av.tableId)&branchId=3&tableNumber=$($av.displayTableNumber)" -WebSession $s -UseBasicParsing
$mt=Tok $menu.Content
$dm=[regex]::Match($menu.Content,'"dishId"\s*:\s*(\d+)')
$h=@{'X-Requested-With'='XMLHttpRequest';'Accept'='application/json'}
$ab=@{tableId=[int]$av.tableId;dishId=[int]$dm.Groups[1].Value;quantity=1;note='x';__RequestVerificationToken=$mt}
Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Body $ab -Headers $h -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$hp=Invoke-WebRequest "$root/" -WebSession $s -UseBasicParsing
$ht=Tok $hp.Content
Invoke-WebRequest "$root/Customer/Logout" -Method Post -WebSession $s -Body @{__RequestVerificationToken=$ht} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null

$l2=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing
$t2=Tok $l2.Content
$body2=@{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t2}
try {
  $r2=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body $body2 -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -MaximumRedirection 0
  "secondLoginStatus=$($r2.StatusCode) location=$($r2.Headers.Location)"
} catch {
  $resp=$_.Exception.Response
  if($resp){"secondLoginStatus=$([int]$resp.StatusCode) location=$($resp.Headers['Location'])"} else { throw }
}
