$ErrorActionPreference='Stop'
function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){return $m.Groups[1].Value}}
  throw 'No anti-forgery token'
}
$root='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp=Get-Date -Format 'yyyyMMddHHmmss'
$u="flow$stamp"
$p='Test@123'
$ph='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)
$em="$u@example.com"

# register
$r=Invoke-WebRequest "$root/Customer/Register" -WebSession $s -UseBasicParsing
$t=Tok $r.Content
$rb=@{Name='Flow Test';Username=$u;Password=$p;ConfirmPassword=$p;PhoneNumber=$ph;Email=$em;Gender='Nam';DateOfBirth='2000-01-01';Address='HCM';__RequestVerificationToken=$t}
$rr=Invoke-WebRequest "$root/Customer/Register" -Method Post -WebSession $s -Body $rb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"registerStatus=$($rr.StatusCode) user=$u"

# force login with same user
$l=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing
$lt=Tok $l.Content
$lb=@{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$lt}
$lr=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body $lb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"loginStatus=$($lr.StatusCode)"

# choose available table in branch 3
$tb=Invoke-WebRequest "$root/Home/GetBranchTables?branchId=3" -WebSession $s -UseBasicParsing
$tj=$tb.Content|ConvertFrom-Json
$av=$tj.tables|Where-Object{$_.isAvailable -eq $true}|Select-Object -First 1
if($null -eq $av){throw 'No available table on branch 3'}
$tableId=[int]$av.tableId
$tableNumber=[int]$av.displayTableNumber
"selectedTable=$tableId number=$tableNumber"

# open menu and add one item (cart pending)
$menu=Invoke-WebRequest "$root/Menu/Index?tableId=$tableId&branchId=3&tableNumber=$tableNumber" -WebSession $s -UseBasicParsing
$mt=Tok $menu.Content
$dm=[regex]::Match($menu.Content,'"dishId"\s*:\s*(\d+)')
if(-not $dm.Success){throw 'No dish id found on menu page'}
$dishId=[int]$dm.Groups[1].Value
$h=@{'X-Requested-With'='XMLHttpRequest';'Accept'='application/json'}
$ab=@{tableId=$tableId;dishId=$dishId;quantity=1;note='persist-cart';__RequestVerificationToken=$mt}
$add=Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Body $ab -Headers $h -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
$addJ=$add.Content|ConvertFrom-Json
"addItemSuccess=$($addJ.success)"

$before=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
"beforeLogout orderId=$($before.orderId) status=$($before.statusCode) items=$($before.totalItems)"

# logout customer
$homePage=Invoke-WebRequest "$root/" -WebSession $s -UseBasicParsing
$ht=Tok $homePage.Content
$lo=Invoke-WebRequest "$root/Customer/Logout" -Method Post -WebSession $s -Body @{__RequestVerificationToken=$ht} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"logoutStatus=$($lo.StatusCode)"

# login again
$l2=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing
$t2=Tok $l2.Content
$lr2=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body @{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t2} -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"loginAgainFinalUri=$($lr2.BaseResponse.ResponseUri.AbsoluteUri)"

# verify cart/order still on same table
$after=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
"afterLogin orderId=$($after.orderId) status=$($after.statusCode) items=$($after.totalItems)"
"sameOrder=$([bool]($before.orderId -eq $after.orderId))"
