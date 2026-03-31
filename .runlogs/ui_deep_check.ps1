$ErrorActionPreference='Stop'
$root='http://localhost:5100'
$badPatterns=@('AUTO_CAT','undefined','Image unavailable')
$results=@()
function Add($name,$pass,$detail){$script:results += [pscustomobject]@{Page=$name;Pass=$pass;Detail=$detail}}
function Tok([string]$h){$m=[regex]::Match($h,'name="__RequestVerificationToken"[^>]*value="([^"]+)"',[Text.RegularExpressions.RegexOptions]::IgnoreCase); if($m.Success){return $m.Groups[1].Value}; throw 'No antiforgery token'}
function Scan($name,$html){$hits=@(); foreach($p in $badPatterns){ if($html -match [regex]::Escape($p)){ $hits += $p } }; Add $name ($hits.Count -eq 0) ($(if($hits.Count){'bad=' + ($hits -join ',')}else{'clean'})) }
function ScanPage($name,$scriptBlock){
    try {
        $resp = & $scriptBlock
        Scan $name $resp.Content
    }
    catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status) {
            Add $name $false "http=$status"
        } else {
            Add $name $false $_.Exception.Message
        }
    }
}
ScanPage 'Home' { Invoke-WebRequest "$root/" -UseBasicParsing }
ScanPage 'Customer Login' { Invoke-WebRequest "$root/Customer/Login" -UseBasicParsing }
$cust=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginPage=Invoke-WebRequest "$root/Customer/Login" -WebSession $cust -UseBasicParsing
$tok=Tok $loginPage.Content
Invoke-WebRequest "$root/Customer/Login" -Method Post -WebSession $cust -Body @{ username='quang'; password='123456'; __RequestVerificationToken=$tok } -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
ScanPage 'Customer Menu' { Invoke-WebRequest "$root/Menu?tableId=1&BranchId=1&tableNumber=1" -WebSession $cust -UseBasicParsing }
$staff=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$staffLogin=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
$stok=Tok $staffLogin.Content
Invoke-WebRequest "$root/Staff/Account/Login" -Method Post -WebSession $staff -Body @{ username='chef_hung'; password='123456'; __RequestVerificationToken=$stok } -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
ScanPage 'Chef Index' { Invoke-WebRequest "$root/Staff/Chef/Index" -WebSession $staff -UseBasicParsing }
ScanPage 'Chef History' { Invoke-WebRequest "$root/Staff/Chef/History" -WebSession $staff -UseBasicParsing }
$cash=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$cashLogin=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $cash -UseBasicParsing
$ctok=Tok $cashLogin.Content
Invoke-WebRequest "$root/Staff/Account/Login" -Method Post -WebSession $cash -Body @{ username='cashier_lan'; password='123456'; __RequestVerificationToken=$ctok } -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
ScanPage 'Cashier Index' { Invoke-WebRequest "$root/Staff/Cashier" -WebSession $cash -UseBasicParsing }
ScanPage 'Cashier History' { Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $cash -UseBasicParsing }
ScanPage 'Cashier Reports' { Invoke-WebRequest "$root/Staff/Cashier/Report" -WebSession $cash -UseBasicParsing }
$admin=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminLogin=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $admin -UseBasicParsing
$atok=Tok $adminLogin.Content
Invoke-WebRequest "$root/Staff/Account/Login" -Method Post -WebSession $admin -Body @{ username='admin'; password='123456'; __RequestVerificationToken=$atok } -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
ScanPage 'Admin Categories' { Invoke-WebRequest "$root/Admin/Categories" -WebSession $admin -UseBasicParsing }
ScanPage 'Admin Dishes' { Invoke-WebRequest "$root/Admin/Dishes" -WebSession $admin -UseBasicParsing }
ScanPage 'Admin Employees' { Invoke-WebRequest "$root/Admin/Employees" -WebSession $admin -UseBasicParsing }
ScanPage 'Admin Customers' { Invoke-WebRequest "$root/Admin/Customers" -WebSession $admin -UseBasicParsing }
$results | Format-Table -AutoSize | Out-String | Write-Output
$pass=($results | Where-Object Pass).Count
Write-Output "SUMMARY: $pass/$($results.Count) clean"
