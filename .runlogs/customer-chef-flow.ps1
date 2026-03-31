$ErrorActionPreference='Stop'
function Tok([string]$h){$m=[regex]::Match($h,'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"');if($m.Success){$m.Groups[1].Value}else{throw 'no token'}}
$root='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='kh20260301093041';$p='Test@789'
# login customer
$l=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing
$t=Tok $l.Content
$lb=@{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t}
$lr=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body $lb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"login=$($lr.StatusCode)"
# pick first available table on branch 3
$tb=Invoke-WebRequest "$root/Home/GetBranchTables?branchId=3" -WebSession $s -UseBasicParsing
$tj=$tb.Content|ConvertFrom-Json
$av=$tj.tables|Where-Object{$_.isAvailable -eq $true}|Select-Object -First 1
$tableId=[int]$av.tableId;$tableNumber=[int]$av.displayTableNumber
$menu=Invoke-WebRequest "$root/Menu/Index?tableId=$tableId&branchId=3&tableNumber=$tableNumber" -WebSession $s -UseBasicParsing
$mt=Tok $menu.Content
$dm=[regex]::Match($menu.Content,'"dishId"\s*:\s*(\d+)')
$dishId=[int]$dm.Groups[1].Value
# add + submit
$h=@{'X-Requested-With'='XMLHttpRequest';'Accept'='application/json'}
$ab=@{tableId=$tableId;dishId=$dishId;quantity=1;note='case-test';__RequestVerificationToken=$mt}
$add=Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Body $ab -Headers $h -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
$sb=@{tableId=$tableId;__RequestVerificationToken=$mt}
$sub=Invoke-WebRequest "$root/Order/Submit" -Method Post -WebSession $s -Body $sb -Headers $h -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
$ao=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$orderId=[int]$ao.orderId
"orderId=$orderId table=$tableId"
# chef ready it directly
$ready=Invoke-WebRequest "http://localhost:5102/api/orders/$orderId/chef/ready" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing
"chefReadyStatus=$($ready.StatusCode)"
# customer sees READY (proxy for notification)
$ao2=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
"customerStatusAfterReady=$($ao2.statusCode)"
# confirm pickup
$cb=@{tableId=$tableId;orderId=$orderId;__RequestVerificationToken=$mt}
$conf=Invoke-WebRequest "$root/Order/ConfirmReceived" -Method Post -WebSession $s -Body $cb -Headers $h -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
$confJ=$conf.Content|ConvertFrom-Json
"confirmPickupSuccess=$($confJ.success)"
# chef list should not contain order anymore
$chefList=Invoke-WebRequest "http://localhost:5102/api/branches/3/chef/orders" -UseBasicParsing | Select-Object -ExpandProperty Content
$contains = $chefList -match ('"orderId":'+$orderId)
"chefListContainsOrderAfterConfirm=$contains"
# add new item again to test logout/login restore table context
$menu2=Invoke-WebRequest "$root/Menu/Index?tableId=$tableId&branchId=3&tableNumber=$tableNumber" -WebSession $s -UseBasicParsing
$mt2=Tok $menu2.Content
$ab2=@{tableId=$tableId;dishId=$dishId;quantity=1;note='persist-test';__RequestVerificationToken=$mt2}
$add2=Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Body $ab2 -Headers $h -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
# logout customer (must preserve table context)
$homePage=Invoke-WebRequest "$root/" -WebSession $s -UseBasicParsing
$ht=Tok $homePage.Content
$lo=Invoke-WebRequest "$root/Customer/Logout" -Method Post -WebSession $s -Body @{__RequestVerificationToken=$ht} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"logoutStatus=$($lo.StatusCode)"
# login again -> should redirect menu with same table
$l2=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing
$t2=Tok $l2.Content
$lr2=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body @{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t2} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
$uri=$lr2.BaseResponse.ResponseUri.AbsoluteUri
"loginAgainRedirectUri=$uri"
# check active order still exists on same table
$ao3=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
"activeOrderAfterRelogin=$($ao3.orderId) status=$($ao3.statusCode) items=$($ao3.totalItems)"

