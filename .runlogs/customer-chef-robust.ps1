$ErrorActionPreference='Stop'
function Tok([string]$h){$m=[regex]::Match($h,'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"');if($m.Success){$m.Groups[1].Value}else{throw 'no token'}}
$root='http://localhost:5100';$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='chef'+(Get-Date -Format 'yyyyMMddHHmmss'); $p='Test@123'; $ph='09'+(Get-Random -Minimum 10000000 -Maximum 99999999); $em="$u@example.com"
$r=Invoke-WebRequest "$root/Customer/Register" -WebSession $s -UseBasicParsing; $t=Tok $r.Content
Invoke-WebRequest "$root/Customer/Register" -Method Post -WebSession $s -Body @{Name='Chef Flow';Username=$u;Password=$p;ConfirmPassword=$p;PhoneNumber=$ph;Email=$em;Gender='Nam';DateOfBirth='2000-01-01';Address='HCM';__RequestVerificationToken=$t} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$l=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing; $lt=Tok $l.Content
Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body @{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$lt} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$tb=Invoke-WebRequest "$root/Home/GetBranchTables?branchId=3" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$av=$tb.tables|Where-Object{$_.isAvailable -eq $true}|Select-Object -First 1
$tableId=[int]$av.tableId; $tableNumber=[int]$av.displayTableNumber
$menu=Invoke-WebRequest "$root/Menu/Index?tableId=$tableId&branchId=3&tableNumber=$tableNumber" -WebSession $s -UseBasicParsing
$mt=Tok $menu.Content
$dm=[regex]::Match($menu.Content,'"dishId"\s*:\s*(\d+)'); $dishId=[int]$dm.Groups[1].Value
$h=@{'X-Requested-With'='XMLHttpRequest';'Accept'='application/json'}
Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Headers $h -Body @{tableId=$tableId;dishId=$dishId;quantity=1;note='chef-flow';__RequestVerificationToken=$mt} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
Invoke-WebRequest "$root/Order/Submit" -Method Post -WebSession $s -Headers $h -Body @{tableId=$tableId;__RequestVerificationToken=$mt} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$ao=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$orderId=[int]$ao.orderId
Invoke-WebRequest "http://localhost:5102/api/orders/$orderId/chef/ready" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
$afterReady=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
Invoke-WebRequest "$root/Order/ConfirmReceived" -Method Post -WebSession $s -Headers $h -Body @{tableId=$tableId;orderId=$orderId;__RequestVerificationToken=$mt} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$chefList=Invoke-WebRequest "http://localhost:5102/api/branches/3/chef/orders" -UseBasicParsing | Select-Object -ExpandProperty Content
$exists=$chefList -match ('"orderId":'+$orderId)
"orderId=$orderId"
"statusAfterChefReady=$($afterReady.statusCode)"
"removedFromChefReadyAfterConfirm=$([bool](-not $exists))"
