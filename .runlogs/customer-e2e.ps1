$ErrorActionPreference='Stop'
function Add-Result($name, $ok, $detail) { $script:results += [pscustomobject]@{ Step=$name; Pass=[bool]$ok; Detail=$detail } }
function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){return $m.Groups[1].Value}}
  throw 'Khong tim thay CSRF token.'
}
$root='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$results=@()
$stamp=Get-Date -Format 'yyyyMMddHHmmss'
$u="kh$stamp";$p='Test@123';$p2='Test@456';$ph='09'+(Get-Random -Minimum 10000000 -Maximum 99999999);$em="$u@example.com"
try{
  $r=Invoke-WebRequest "$root/Customer/Register" -WebSession $s -UseBasicParsing; $t=Tok $r.Content; Add-Result 'Mo trang Dang ky' $true "status=$($r.StatusCode)"
  $b=@{Name='Khach Test';Username=$u;Password=$p;ConfirmPassword=$p;PhoneNumber=$ph;Email=$em;Gender='Nam';DateOfBirth='2000-01-01';Address='HCM';__RequestVerificationToken=$t}
  $r2=Invoke-WebRequest "$root/Customer/Register" -Method Post -WebSession $s -Body $b -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; Add-Result 'Dang ky tai khoan' ($r2.StatusCode -in 200,302) "status=$($r2.StatusCode) user=$u"

  $l=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing; $lt=Tok $l.Content; Add-Result 'Mo trang Dang nhap' $true "status=$($l.StatusCode)"
  $lb=@{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$lt}
  $l2=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body $lb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; Add-Result 'Dang nhap khach hang' ($l2.StatusCode -in 200,302) "status=$($l2.StatusCode)"

  $h=Invoke-WebRequest "$root/" -WebSession $s -UseBasicParsing
  $bm=[regex]::Match($h.Content,'data-branch-id="(\d+)"'); if(-not $bm.Success){throw 'Khong tim thay chi nhanh'}; $bid=[int]$bm.Groups[1].Value; Add-Result 'Trang chu + chi nhanh' $true "branchId=$bid"
  $tb=Invoke-WebRequest "$root/Home/GetBranchTables?branchId=$bid" -WebSession $s -UseBasicParsing; $tj=$tb.Content|ConvertFrom-Json; if(-not $tj.success){throw 'GetBranchTables fail'}
  $av=$tj.tables|Where-Object{$_.isAvailable -eq $true}|Select-Object -First 1; if($null -eq $av){throw 'Khong co ban trong'}; $tableId=[int]$av.tableId; $tableNumber=[int]$av.displayTableNumber; Add-Result 'Chon chi nhanh + ban' $true "tableId=$tableId"

  $m=Invoke-WebRequest "$root/Menu/Index?tableId=$tableId&branchId=$bid&tableNumber=$tableNumber" -WebSession $s -UseBasicParsing; $mt=Tok $m.Content
  $dm=[regex]::Match($m.Content,'"dishId"\s*:\s*(\d+)'); if(-not $dm.Success){throw 'Khong tim thay dishId'}; $dishId=[int]$dm.Groups[1].Value; Add-Result 'Vao menu + chon mon' $true "dishId=$dishId"

  $ah=@{'X-Requested-With'='XMLHttpRequest';'Accept'='application/json'}
  $ab=@{tableId=$tableId;dishId=$dishId;quantity=1;note='it ngot';__RequestVerificationToken=$mt}
  $ar=Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Body $ab -Headers $ah -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; $aj=$ar.Content|ConvertFrom-Json; Add-Result 'Them mon vao gio' ($aj.success -eq $true) $ar.Content

  $act=Invoke-WebRequest "$root/Order/ActiveJson?tableId=$tableId" -WebSession $s -UseBasicParsing; $ao=$act.Content|ConvertFrom-Json; $itemId=[int]$ao.items[0].itemId; $orderId=[int]$ao.orderId; Add-Result 'Xem don hien tai' ($orderId -gt 0) "orderId=$orderId itemId=$itemId status=$($ao.statusCode)"

  $ub=@{tableId=$tableId;itemId=$itemId;quantity=2;__RequestVerificationToken=$mt}; $ur=Invoke-WebRequest "$root/Order/UpdateQuantity" -Method Post -WebSession $s -Body $ub -Headers $ah -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; $uj=$ur.Content|ConvertFrom-Json; Add-Result 'Cap nhat so luong' ($uj.success -eq $true) $ur.Content
  $rb=@{tableId=$tableId;itemId=$itemId;__RequestVerificationToken=$mt}; $rr=Invoke-WebRequest "$root/Order/RemoveItem" -Method Post -WebSession $s -Body $rb -Headers $ah -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; $rj=$rr.Content|ConvertFrom-Json; Add-Result 'Xoa mon' ($rj.success -eq $true) $rr.Content

  $ar2=Invoke-WebRequest "$root/Order/AddItem" -Method Post -WebSession $s -Body $ab -Headers $ah -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; $aj2=$ar2.Content|ConvertFrom-Json; if(-not $aj2.success){throw 'Add lai that bai'}
  $sb=@{tableId=$tableId;__RequestVerificationToken=$mt}; $sr=Invoke-WebRequest "$root/Order/Submit" -Method Post -WebSession $s -Body $sb -Headers $ah -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; $sj=$sr.Content|ConvertFrom-Json; Add-Result 'Gui don cho bep' ($sj.success -eq $true) $sr.Content

  $rst=@{tableId=$tableId;branchId=$bid;__RequestVerificationToken=$mt}; $rs=Invoke-WebRequest "$root/Menu/ResetTable" -Method Post -WebSession $s -Body $rst -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; Add-Result 'Reset ban' ($rs.StatusCode -in 200,302) "status=$($rs.StatusCode)"

  $d=Invoke-WebRequest "$root/Customer/Dashboard" -WebSession $s -UseBasicParsing; $dt=Tok $d.Content
  $pb=@{username=$u;name='Khach Test Updated';email=$em;phoneNumber=$ph;gender='Nam';address='HCM Updated';dateOfBirth='2000-01-01';__RequestVerificationToken=$dt}
  $pr=Invoke-WebRequest "$root/Customer/UpdateProfile" -Method Post -WebSession $s -Body $pb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; Add-Result 'Cap nhat ho so' ($pr.StatusCode -in 200,302) "status=$($pr.StatusCode)"

  $f=Invoke-WebRequest "$root/Customer/ForgotPassword" -WebSession $s -UseBasicParsing; $ft=Tok $f.Content
  $fb=@{UsernameOrEmailOrPhone=$u;__RequestVerificationToken=$ft}; $fr=Invoke-WebRequest "$root/Customer/ForgotPassword" -Method Post -WebSession $s -Body $fb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; Add-Result 'Quen mat khau' ($fr.StatusCode -in 200,302) "status=$($fr.StatusCode)"

  $conn=New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True;'); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandText='SELECT TOP 1 prt.Token FROM PasswordResetTokens prt JOIN Customers c ON c.CustomerID = prt.CustomerID WHERE c.Username=@u ORDER BY prt.TokenID DESC'; $pm=$cmd.Parameters.Add('@u',[System.Data.SqlDbType]::VarChar,50); $pm.Value=$u; $token=$cmd.ExecuteScalar(); $conn.Close(); if([string]::IsNullOrWhiteSpace($token)){throw 'Khong lay duoc token reset'}; Add-Result 'Lay token reset' $true 'ok'

  $rp=Invoke-WebRequest "$root/Customer/ResetPassword?token=$token" -WebSession $s -UseBasicParsing; $rpt=Tok $rp.Content
  $rpb=@{Token=$token;NewPassword=$p2;ConfirmPassword=$p2;__RequestVerificationToken=$rpt}; $rpr=Invoke-WebRequest "$root/Customer/ResetPassword" -Method Post -WebSession $s -Body $rpb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; Add-Result 'Reset mat khau' ($rpr.StatusCode -in 200,302) "status=$($rpr.StatusCode)"

  $l3=Invoke-WebRequest "$root/Customer/Login?force=true" -WebSession $s -UseBasicParsing; $l3t=Tok $l3.Content
  $l3b=@{Username=$u;Password=$p2;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$l3t}; $l3r=Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $s -Body $l3b -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing; Add-Result 'Dang nhap mat khau moi' ($l3r.StatusCode -in 200,302) "status=$($l3r.StatusCode)"
}
catch{ Add-Result 'LOI CHUNG' $false $_.Exception.Message }
$results|Format-Table -AutoSize|Out-String|Write-Output
$pc=($results|Where-Object{$_.Pass -eq $true}).Count; $tt=$results.Count; Write-Output "SUMMARY: $pc/$tt PASS"
