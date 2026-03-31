$ErrorActionPreference='Stop'
function Add-Result($name, $ok, $detail) { $script:results += [pscustomobject]@{ ChucNang=$name; Pass=[bool]$ok; ChiTiet=$detail } }
function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){ return $m.Groups[1].Value }}
  throw 'No token'
}
function Post-Form($url, $body, $session){
  Invoke-WebRequest $url -Method Post -WebSession $session -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
}
function New-OrderForCashier([int]$branchId,[int]$dishId,[int]$tableId,[string]$note){
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/occupy" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/items" -Method Post -ContentType 'application/json' -Body (@{dishId=$dishId;quantity=1;note=$note} | ConvertTo-Json) -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  $active=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  return [int]$active.orderId
}

$results=@()
$root='http://localhost:5100'
$branchId=1
$cashierUser='cashier_lan'
$cashierPass='123456'
$tempPass='Temp@789'
$staff=New-Object Microsoft.PowerShell.Commands.WebRequestSession

# capture current profile to revert
$conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True;")
$conn.Open()
$cmd=$conn.CreateCommand()
$cmd.CommandText="SELECT TOP 1 EmployeeID, Name, Email, Phone FROM Employees WHERE Username=@u"
$p=$cmd.Parameters.Add('@u',[System.Data.SqlDbType]::VarChar,50)
$p.Value=$cashierUser
$r=$cmd.ExecuteReader()
$dt=New-Object System.Data.DataTable
$dt.Load($r)
$conn.Close()
if($dt.Rows.Count -eq 0){ throw 'Cannot find cashier account in DB' }
$empId=[int]$dt.Rows[0].EmployeeID
$origName=[string]$dt.Rows[0].Name
$origEmail=[string]$dt.Rows[0].Email
$origPhone=[string]$dt.Rows[0].Phone

try {
  # 1 login
  $loginPage=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
  $loginToken=Tok $loginPage.Content
  $loginResp=Post-Form "$root/Staff/Account/Login" @{username=$cashierUser;password=$cashierPass;__RequestVerificationToken=$loginToken} $staff
  Add-Result 'Đăng nhập Cashier' ($loginResp.StatusCode -in 200,302) "status=$($loginResp.StatusCode)"

  # 2 access pages
  $indexPage=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  Add-Result 'Mở trang thanh toán' ($indexPage.StatusCode -eq 200) "status=$($indexPage.StatusCode)"

  $historyPage=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
  Add-Result 'Mở trang lịch sử & tài khoản' ($historyPage.StatusCode -eq 200) "status=$($historyPage.StatusCode)"

  $reportPage=Invoke-WebRequest "$root/Staff/Cashier/Report" -WebSession $staff -UseBasicParsing
  Add-Result 'Mở trang báo cáo' ($reportPage.StatusCode -eq 200) "status=$($reportPage.StatusCode)"

  # 3 filter history/report by date
  $today=(Get-Date).ToString('yyyy-MM-dd')
  $historyFilter=Invoke-WebRequest "$root/Staff/Cashier/History?date=$today" -WebSession $staff -UseBasicParsing
  Add-Result 'Lọc lịch sử theo ngày' ($historyFilter.StatusCode -eq 200) "date=$today"

  $reportFilter=Invoke-WebRequest "$root/Staff/Cashier/Report?date=$today" -WebSession $staff -UseBasicParsing
  Add-Result 'Lọc báo cáo theo ngày' ($reportFilter.StatusCode -eq 200) "date=$today"

  # prepare dish/table
  $menuApi=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/menu" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $dish=$null
  foreach($c in $menuApi.categories){ $dish=$c.dishes | Where-Object { $_.available -eq $true } | Select-Object -First 1; if($dish){break} }
  if($null -eq $dish){ throw 'No available dish for cashier tests' }
  $dishId=[int]$dish.dishId

  $tables=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/tables" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $avail=@($tables.tables | Where-Object { $_.isAvailable -eq $true })
  if($avail.Count -eq 0){ $avail=@($tables.tables) }
  if($avail.Count -lt 3){ throw 'Need at least 3 tables to run cashier tests' }

  # 4 checkout error: insufficient cash
  $order1=New-OrderForCashier -branchId $branchId -dishId $dishId -tableId ([int]$avail[0].tableId) -note 'cashier-insufficient'
  $idx1=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  $tk1=Tok $idx1.Content
  $resInsufficient=Post-Form "$root/Staff/Cashier/Checkout" @{orderId=$order1;discount=0;pointsUsed=0;paymentMethod='CASH';paymentAmount=1;__RequestVerificationToken=$tk1} $staff
  $stillQueue=((Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content) -match ('\"orderId\":'+$order1))
  Add-Result 'Checkout lỗi khi tiền mặt không đủ' $stillQueue "orderId=$order1"

  # 5 checkout error: invalid payment method
  $idx2=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  $tk2=Tok $idx2.Content
  $resInvalid=Post-Form "$root/Staff/Cashier/Checkout" @{orderId=$order1;discount=0;pointsUsed=0;paymentMethod='BADMETHOD';paymentAmount=999999;__RequestVerificationToken=$tk2} $staff
  $stillQueue2=((Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content) -match ('\"orderId\":'+$order1))
  Add-Result 'Checkout lỗi khi phương thức thanh toán sai' $stillQueue2 "orderId=$order1"

  # 6 checkout success CASH
  $idx3=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  $tk3=Tok $idx3.Content
  Post-Form "$root/Staff/Cashier/Checkout" @{orderId=$order1;discount=0;pointsUsed=0;paymentMethod='CASH';paymentAmount=999999;__RequestVerificationToken=$tk3} $staff | Out-Null
  Start-Sleep -Milliseconds 300
  $removed1=-not ((Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content) -match ('\"orderId\":'+$order1))
  Add-Result 'Checkout thành công tiền mặt' $removed1 "orderId=$order1"

  # 7 checkout success CARD
  $order2=New-OrderForCashier -branchId $branchId -dishId $dishId -tableId ([int]$avail[1].tableId) -note 'cashier-card'
  $idx4=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  $tk4=Tok $idx4.Content
  Post-Form "$root/Staff/Cashier/Checkout" @{orderId=$order2;discount=0;pointsUsed=0;paymentMethod='CARD';paymentAmount=0;__RequestVerificationToken=$tk4} $staff | Out-Null
  Start-Sleep -Milliseconds 300
  $removed2=-not ((Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content) -match ('\"orderId\":'+$order2))
  Add-Result 'Checkout thành công thẻ (CARD)' $removed2 "orderId=$order2"

  # 8 checkout success TRANSFER
  $order3=New-OrderForCashier -branchId $branchId -dishId $dishId -tableId ([int]$avail[2].tableId) -note 'cashier-transfer'
  $idx5=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  $tk5=Tok $idx5.Content
  Post-Form "$root/Staff/Cashier/Checkout" @{orderId=$order3;discount=0;pointsUsed=0;paymentMethod='TRANSFER';paymentAmount=0;__RequestVerificationToken=$tk5} $staff | Out-Null
  Start-Sleep -Milliseconds 300
  $removed3=-not ((Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content) -match ('\"orderId\":'+$order3))
  Add-Result 'Checkout thành công chuyển khoản' $removed3 "orderId=$order3"

  # 9 history has bill records
  $histAfter=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
  Add-Result 'Lịch sử có hóa đơn sau checkout' ($histAfter.Content -match 'BILL-') 'BILL marker'

  # 10 report render metrics
  $repAfter=Invoke-WebRequest "$root/Staff/Cashier/Report" -WebSession $staff -UseBasicParsing
  Add-Result 'Báo cáo hiển thị dữ liệu' ($repAfter.Content -match 'BILL-' -or $repAfter.Content -match 'table') 'report html'

  # 11 update account (and verify in DB)
  $newName="$origName QA"
  $newEmail=$origEmail
  $newPhone=$origPhone
  $historyPage2=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
  $htok=Tok $historyPage2.Content
  Post-Form "$root/Staff/Cashier/UpdateAccount" @{name=$newName;email=$newEmail;phone=$newPhone;__RequestVerificationToken=$htok} $staff | Out-Null
  Start-Sleep -Milliseconds 300

  $conn2 = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True;")
  $conn2.Open(); $cmd2=$conn2.CreateCommand(); $cmd2.CommandText='SELECT Name,Email,Phone FROM Employees WHERE EmployeeID=@id'; $p2=$cmd2.Parameters.Add('@id',[System.Data.SqlDbType]::Int); $p2.Value=$empId; $r2=$cmd2.ExecuteReader(); $dt2=New-Object System.Data.DataTable; $dt2.Load($r2); $conn2.Close()
  $updatedName=[string]$dt2.Rows[0].Name
  Add-Result 'Cập nhật tài khoản Cashier' ($updatedName -eq $newName) "dbName=$updatedName"

  # 12 change password mismatch
  $historyPage3=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
  $htok2=Tok $historyPage3.Content
  Post-Form "$root/Staff/Cashier/ChangePassword" @{currentPassword=$cashierPass;newPassword='Xyz@123';confirmPassword='DIFF@123';__RequestVerificationToken=$htok2} $staff | Out-Null
  # verify old password still login
  $sCheck=New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $lp=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $sCheck -UseBasicParsing
  $ltk=Tok $lp.Content
  $lr=Post-Form "$root/Staff/Account/Login" @{username=$cashierUser;password=$cashierPass;__RequestVerificationToken=$ltk} $sCheck
  Add-Result 'Đổi mật khẩu sai xác nhận bị chặn' ($lr.StatusCode -in 200,302) 'old password still works'

  # 13 change password success to temp
  $historyPage4=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
  $htok3=Tok $historyPage4.Content
  Post-Form "$root/Staff/Cashier/ChangePassword" @{currentPassword=$cashierPass;newPassword=$tempPass;confirmPassword=$tempPass;__RequestVerificationToken=$htok3} $staff | Out-Null
  $sTemp=New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $lp2=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $sTemp -UseBasicParsing
  $ltk2=Tok $lp2.Content
  $lr2=Post-Form "$root/Staff/Account/Login" @{username=$cashierUser;password=$tempPass;__RequestVerificationToken=$ltk2} $sTemp
  Add-Result 'Đổi mật khẩu thành công (đăng nhập pass mới)' ($lr2.StatusCode -in 200,302) 'temp password login ok'

  # 14 revert password back to original
  $histTemp=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $sTemp -UseBasicParsing
  $ttok=Tok $histTemp.Content
  Post-Form "$root/Staff/Cashier/ChangePassword" @{currentPassword=$tempPass;newPassword=$cashierPass;confirmPassword=$cashierPass;__RequestVerificationToken=$ttok} $sTemp | Out-Null
  $sOld=New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $lp3=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $sOld -UseBasicParsing
  $ltk3=Tok $lp3.Content
  $lr3=Post-Form "$root/Staff/Account/Login" @{username=$cashierUser;password=$cashierPass;__RequestVerificationToken=$ltk3} $sOld
  Add-Result 'Khôi phục mật khẩu cũ' ($lr3.StatusCode -in 200,302) 'original password restored'
}
catch {
  Add-Result 'ERROR' $false $_.Exception.Message
}
finally {
  # revert profile name
  try {
    $conn3 = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True;")
    $conn3.Open()
    $cmd3=$conn3.CreateCommand()
    $cmd3.CommandText='UPDATE Employees SET Name=@n, Email=@e, Phone=@p WHERE EmployeeID=@id'
    $pn=$cmd3.Parameters.Add('@n',[System.Data.SqlDbType]::NVarChar,100); $pn.Value=$origName
    $pe=$cmd3.Parameters.Add('@e',[System.Data.SqlDbType]::VarChar,100); $pe.Value=$origEmail
    $pp=$cmd3.Parameters.Add('@p',[System.Data.SqlDbType]::VarChar,20); $pp.Value=$origPhone
    $pid=$cmd3.Parameters.Add('@id',[System.Data.SqlDbType]::Int); $pid.Value=$empId
    [void]$cmd3.ExecuteNonQuery()
    $conn3.Close()
  } catch {}
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass=($results|Where-Object{$_.Pass -eq $true}).Count
$total=$results.Count
Write-Output "SUMMARY: $pass/$total PASS"
