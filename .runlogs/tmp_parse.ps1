$r=Invoke-WebRequest 'http://localhost:5100/Home/GetBranchTables?branchId=1' -UseBasicParsing
$obj=$r.Content | ConvertFrom-Json
Write-Output ("type=" + $obj.GetType().FullName)
Write-Output ("success=" + $obj.success)
Write-Output ("firstTable=" + $obj.tables[0].tableId)
