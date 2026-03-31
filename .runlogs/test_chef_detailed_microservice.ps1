$ErrorActionPreference = 'Stop'

function Add-Result($name, $ok, $detail) {
    $script:results += [pscustomobject]@{
        ChucNang = $name
        Pass = [bool]$ok
        ChiTiet = $detail
    }
}

function Tok([string]$h) {
    $ps = @(
        'name="__RequestVerificationToken"[^>]*value="([^"]+)"',
        "name='__RequestVerificationToken'[^>]*value='([^']+)'",
        'value="([^"]+)"[^>]*name="__RequestVerificationToken"'
    )
    foreach ($p in $ps) {
        $m = [regex]::Match($h, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    throw 'Khong tim thay token'
}

function Post-Form($url, $body, $session) {
    Invoke-WebRequest $url -Method Post -WebSession $session -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
}

function Assert-JsonSuccess($result, $name, $detailPrefix = '') {
    $detail = if ([string]::IsNullOrWhiteSpace($detailPrefix)) {
        "success=$($result.success)"
    }
    else {
        "$detailPrefix success=$($result.success)"
    }

    Add-Result $name ([bool]$result.success) $detail
}

function To-JsonObj($response) {
    $content = if ($null -eq $response.Content) { '' } else { [string]$response.Content }
    $content = $content.Trim()
    if ([string]::IsNullOrWhiteSpace($content)) { return [pscustomobject]@{ success = $false; raw = '' } }
    try { return ($content | ConvertFrom-Json) } catch { return [pscustomobject]@{ success = $false; raw = $content } }
}

$results = @()
$root = 'http://localhost:5100'
$catalog = 'http://localhost:5101'
$orders = 'http://localhost:5102'
$branchId = 1
$chefUser = 'chef_hung'
$chefPass = '123456'
$staff = New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
    # 0) Dang nhap Chef
    $loginPage = Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
    $loginToken = Tok $loginPage.Content
    $loginResp = Post-Form "$root/Staff/Account/Login" @{
        username = $chefUser
        password = $chefPass
        __RequestVerificationToken = $loginToken
    } $staff
    Add-Result 'Dang nhap Chef' ($loginResp.StatusCode -in 200, 302) "status=$($loginResp.StatusCode)"

    # 1) Mo dashboard + history
    $chefPage = Invoke-WebRequest "$root/Staff/Chef/Index" -WebSession $staff -UseBasicParsing
    Add-Result 'Mo dashboard Chef' ($chefPage.StatusCode -eq 200) "status=$($chefPage.StatusCode)"
    $historyPage = Invoke-WebRequest "$root/Staff/Chef/History" -WebSession $staff -UseBasicParsing
    Add-Result 'Mo lich su Chef' ($historyPage.StatusCode -eq 200) "status=$($historyPage.StatusCode)"

    # Tao du lieu don hang test
    $menuApi = Invoke-WebRequest "$catalog/api/branches/$branchId/menu" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $cats = Invoke-WebRequest "$catalog/api/categories?includeInactive=true" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $validCategoryIds = @{}
    foreach ($cat in @($cats) | Where-Object { $_.isActive -eq $true }) { $validCategoryIds[[int]$cat.categoryId] = $true }

    $dish = $null
    foreach ($c in $menuApi.categories) {
        foreach ($d in @($c.dishes | Where-Object { $_.available -eq $true })) {
            $dInfo = Invoke-WebRequest "$catalog/api/admin/dishes/$($d.dishId)" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
            $catId = [int]$dInfo.categoryId
            if ($validCategoryIds.ContainsKey($catId)) {
                $dish = $d
                break
            }
        }
        if ($dish) { break }
    }
    if ($null -eq $dish) { throw 'Khong tim thay mon co category hop le trong menu' }
    $dishId = [int]$dish.dishId

    $tables = Invoke-WebRequest "$catalog/api/branches/$branchId/tables" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $table = $tables.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1
    if ($null -eq $table) { $table = $tables.tables | Select-Object -First 1 }
    $tableId = [int]$table.tableId

    Invoke-WebRequest "$orders/api/tables/$tableId/reset" -Method Post -UseBasicParsing | Out-Null
    Invoke-WebRequest "$orders/api/tables/$tableId/order/items" -Method Post -ContentType 'application/json' -Body (@{ dishId = $dishId; quantity = 1; note = 'chef-detailed' } | ConvertTo-Json) -UseBasicParsing | Out-Null
    Invoke-WebRequest "$orders/api/tables/$tableId/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
    $active = Invoke-WebRequest "$orders/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $orderId = [int]$active.orderId
    Add-Result 'Tao don test cho Chef' ($orderId -gt 0) "orderId=$orderId tableId=$tableId dishId=$dishId"

    # 2) PREPARING
    $prep = Post-Form "$root/Staff/Chef/UpdateOrderStatus" @{ orderId = $orderId; statusCode = 'PREPARING' } $staff
    $prepJson = To-JsonObj $prep
    Start-Sleep -Milliseconds 200
    $prepCheck = Invoke-WebRequest "$orders/api/branches/$branchId/chef/orders?status=PREPARING" -UseBasicParsing | Select-Object -ExpandProperty Content
    Add-Result 'Bat dau che bien PREPARING' ([bool]$prepJson.success -and ($prepCheck -match ('\"orderId\":' + $orderId))) "orderId=$orderId"

    # 3) READY
    $ready = Post-Form "$root/Staff/Chef/UpdateOrderStatus" @{ orderId = $orderId; statusCode = 'READY' } $staff
    $readyJson = To-JsonObj $ready
    Start-Sleep -Milliseconds 200
    $readyCheck = Invoke-WebRequest "$orders/api/branches/$branchId/chef/orders?status=READY" -UseBasicParsing | Select-Object -ExpandProperty Content
    Add-Result 'Danh dau san sang READY' ([bool]$readyJson.success -and ($readyCheck -match ('\"orderId\":' + $orderId))) "orderId=$orderId"

    # 4) Customer confirms received, order should disappear from READY board
    $confirmResp = Invoke-WebRequest "$orders/api/orders/$orderId/confirm-received" `
        -Method Post `
        -UseBasicParsing `
        -ContentType 'application/json' `
        -Body '{}'
    $confirmOk = $confirmResp.StatusCode -in 200, 204
    Start-Sleep -Milliseconds 300
    $readyBoardAfterConfirm = Invoke-WebRequest "$orders/api/branches/$branchId/chef/orders?status=READY" -UseBasicParsing | Select-Object -ExpandProperty Content
    Add-Result 'Khach xac nhan da nhan mon' ($confirmOk -and ($readyBoardAfterConfirm -notmatch ('\"orderId\":' + $orderId))) "orderId=$orderId status=$($confirmResp.StatusCode)"

    # 5) Huy don
    $table2 = $tables.tables | Where-Object { [int]$_.tableId -ne $tableId } | Select-Object -First 1
    if ($null -eq $table2) { $table2 = $table }
    $tableId2 = [int]$table2.tableId
    Invoke-WebRequest "$orders/api/tables/$tableId2/reset" -Method Post -UseBasicParsing | Out-Null
    Invoke-WebRequest "$orders/api/tables/$tableId2/order/items" -Method Post -ContentType 'application/json' -Body (@{ dishId = $dishId; quantity = 1; note = 'chef-cancel' } | ConvertTo-Json) -UseBasicParsing | Out-Null
    Invoke-WebRequest "$orders/api/tables/$tableId2/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
    $active2 = Invoke-WebRequest "$orders/api/tables/$tableId2/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $orderId2 = [int]$active2.orderId
    $cancel = Post-Form "$root/Staff/Chef/CancelOrder" @{ orderId = $orderId2; reason = 'Het nguyen lieu' } $staff
    $cancelJson = To-JsonObj $cancel
    Add-Result 'Huy don CancelOrder' ([bool]$cancelJson.success) "orderId=$orderId2"

    # 6) Xem nguyen lieu mon
    $ingPage = Invoke-WebRequest "$root/Staff/Chef/Ingredients/$dishId" -WebSession $staff -UseBasicParsing
    Add-Result 'Xem nguyen lieu mon' ($ingPage.StatusCode -eq 200) "dishId=$dishId"

    # 7) Lay danh sach nguyen lieu mon (ajax)
    $ingListResp = Invoke-WebRequest "$root/Staff/Chef/GetDishIngredients?dishId=$dishId" -WebSession $staff -UseBasicParsing
    $ingListJson = To-JsonObj $ingListResp
    $items = @($ingListJson.items)
    Add-Result 'Lay DS nguyen lieu mon' ([bool]$ingListJson.success -and $items.Count -ge 1) "count=$($items.Count)"

    # 8) Sua quantity nguyen lieu (ajax AddDishIngredient)
    $firstIng = $items | Select-Object -First 1
    if ($null -eq $firstIng) { throw 'Khong co nguyen lieu de cap nhat' }
    $ingId = [int]$firstIng.ingredientId
    $newQtyText = '1.23'
    $updResp = Post-Form "$root/Staff/Chef/AddDishIngredient" @{ dishId = $dishId; ingredientId = $ingId; quantityPerDish = $newQtyText } $staff
    $updJson = To-JsonObj $updResp
    Start-Sleep -Milliseconds 200
    $verifyLines = Invoke-WebRequest "$catalog/api/admin/dishes/$dishId/ingredients" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $verifyLine = $verifyLines | Where-Object { [int]$_.ingredientId -eq $ingId } | Select-Object -First 1
    $qtyMatched = ($null -ne $verifyLine) -and ([math]::Abs([decimal]$verifyLine.quantityPerDish - [decimal]1.23) -lt [decimal]0.01)
    Add-Result 'Sua quantity nguyen lieu mon' ([bool]$updJson.success -and $qtyMatched) "ingredientId=$ingId qty=$($verifyLine.quantityPerDish)"

    # 9) Tat/Bat mon (Hide/Show)
    try {
        $dishBefore = Invoke-WebRequest "$catalog/api/admin/dishes/$dishId" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        $hideResp = Post-Form "$root/Staff/Chef/HideDish" @{ dishId = $dishId } $staff
        $hideJson = To-JsonObj $hideResp
        Start-Sleep -Milliseconds 200
        $dishHidden = Invoke-WebRequest "$catalog/api/admin/dishes/$dishId" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        $showResp = Post-Form "$root/Staff/Chef/ShowDish" @{ dishId = $dishId } $staff
        $showJson = To-JsonObj $showResp
        Start-Sleep -Milliseconds 200
        $dishShown = Invoke-WebRequest "$catalog/api/admin/dishes/$dishId" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        $toggleOk = [bool]$hideJson.success -and [bool]$showJson.success -and (-not [bool]$dishHidden.available) -and ([bool]$dishShown.available)
        Add-Result 'Tat/Bat mon HideDish/ShowDish' $toggleOk "before=$($dishBefore.available) hidden=$($dishHidden.available) shown=$($dishShown.available)"
    }
    catch {
        Add-Result 'Tat/Bat mon HideDish/ShowDish' $false $_.Exception.Message
    }
}
catch {
    Add-Result 'ERROR' $false $_.Exception.Message
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass = ($results | Where-Object { $_.Pass -eq $true }).Count
$total = $results.Count
Write-Output "SUMMARY: $pass/$total PASS"
