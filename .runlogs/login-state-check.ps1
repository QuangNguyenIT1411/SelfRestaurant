$ErrorActionPreference='Stop'
function Tok([string]$h){$m=[regex]::Match($h,'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"');if($m.Success){$m.Groups[1].Value}else{throw 'no token'}}
$root='http://localhost:5100';$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='flow20260301094122';$p='Test@123'
$l=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing; $t=Tok $l.Content
Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body @{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$tb=Invoke-WebRequest "$root/Home/GetBranchTables?branchId=3" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$av=$tb.tables|Where-Object{$_.isAvailable -eq $true}|Select-Object -First 1
$menu=Invoke-WebRequest "$root/Menu/Index?tableId=$($av.tableId)&branchId=3&tableNumber=$($av.displayTableNumber)" -WebSession $s -UseBasicParsing
$mt=Tok $menu.Content
$dm=[regex]::Match($menu.Content,'"dishId"\s*:\s*(\d+)')
$h=@{'X-Requested-With'='XMLHttpRequest';'Accept'='application/json'}
Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Headers $h -Body @{tableId=[int]$av.tableId;dishId=[int]$dm.Groups[1].Value;quantity=1;note='x';__RequestVerificationToken=$mt} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$homePage=Invoke-WebRequest "$root/" -WebSession $s -UseBasicParsing; $ht=Tok $homePage.Content
Invoke-WebRequest "$root/Customer/Logout" -Method Post -WebSession $s -Body @{__RequestVerificationToken=$ht} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$l2=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing; $t2=Tok $l2.Content
$r2=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body @{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t2} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"login2Final=$($r2.BaseResponse.ResponseUri.AbsoluteUri)"
$d=Invoke-WebRequest "$root/Customer/Dashboard" -WebSession $s -UseBasicParsing
"dashboardFinal=$($d.BaseResponse.ResponseUri.AbsoluteUri)"
