$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$adminBase = "$base/api/gateway/admin"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$results = New-Object System.Collections.Generic.List[object]
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$originalSettings = $null
$createdCategoryId = $null
$createdIngredientId = $null
$createdDishId = $null
$createdTableId = $null
$createdCustomerId = $null
$createdEmployeeId = $null

function Add-Result([string]$Feature, [bool]$Pass, [string]$Detail) {
    $results.Add([pscustomobject]@{
        feature = $Feature
        pass = $Pass
        detail = $Detail
    }) | Out-Null
    $state = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Output "[$state] $Feature - $Detail"
}

function Get-ErrorBody {
    param($ErrorRecord)
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.GetResponseStream()) {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        return $reader.ReadToEnd()
    }
    return $ErrorRecord.Exception.Message
}

function Invoke-Json {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
        $Body = $null
    )

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60
        }

        $json = $Body | ConvertTo-Json -Depth 20
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        throw (Get-ErrorBody $_)
    }
}

function Expect-ApiError {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
        $Body = $null
    )

    try {
        $null = Invoke-Json $Method $Uri $WebSession $Body
        throw "Expected API error at $Uri but request succeeded."
    }
    catch {
        $raw = $_.Exception.Message
        try { return $raw | ConvertFrom-Json } catch { throw $raw }
    }
}

try {
    $login = Invoke-Json POST "$adminBase/auth/login" $session @{
        username = 'admin'
        password = '123456'
    }
    Add-Result 'Admin Login' ([bool]$login.success -and $login.nextPath -eq '/Admin/Dashboard/Index') $login.nextPath

    foreach ($route in @(
        '/app/admin/Admin/Account/Login',
        '/app/admin/Admin/Dashboard/Index',
        '/app/admin/Admin/Categories/Index',
        '/app/admin/Admin/Dishes/Index',
        '/app/admin/Admin/Ingredients/Index',
        '/app/admin/Admin/TablesQR/Index',
        '/app/admin/Admin/Employees/Index',
        '/app/admin/Admin/Customers/Index',
        '/app/admin/Admin/Reports/Revenue',
        '/app/admin/Admin/Settings/Index'
    )) {
        $page = Invoke-WebRequest "$base$route" -WebSession $session -UseBasicParsing -TimeoutSec 30
        Add-Result "Route $route" ($page.StatusCode -eq 200) '200'
    }

    $dashboard = Invoke-Json GET "$adminBase/dashboard" $session
    $categories = Invoke-Json GET "$adminBase/categories" $session
    $dishes = Invoke-Json GET "$adminBase/dishes" $session
    $ingredients = Invoke-Json GET "$adminBase/ingredients" $session
    $tables = Invoke-Json GET "$adminBase/tables" $session
    $employees = Invoke-Json GET "$adminBase/employees" $session
    $customers = Invoke-Json GET "$adminBase/customers" $session
    $reports = Invoke-Json GET "$adminBase/reports?revenueDays=30&topDishDays=30&topDishTake=10" $session
    $settings = Invoke-Json GET "$adminBase/settings" $session

    $originalSettings = [pscustomobject]@{
        Name = [string]$settings.name
        Phone = [string]$settings.phone
        Email = [string]$settings.email
    }

    Add-Result 'Dashboard Data' ($null -ne $dashboard.stats) "todayRevenue=$($dashboard.stats.todayRevenue)"
    Add-Result 'Categories Load' (@($categories.categories).Count -ge 0) "count=$(@($categories.categories).Count)"
    Add-Result 'Dishes Load' ($null -ne $dishes.dishes) "count=$($dishes.dishes.totalItems)"
    Add-Result 'Ingredients Load' ($null -ne $ingredients.ingredients) "count=$($ingredients.ingredients.totalItems)"
    Add-Result 'Tables Load' ($null -ne $tables.tables) "count=$($tables.tables.totalItems)"
    Add-Result 'Employees Load' ($null -ne $employees.employees) "count=$($employees.employees.totalItems)"
    Add-Result 'Customers Load' ($null -ne $customers.customers) "count=$($customers.customers.totalItems)"
    Add-Result 'Reports Load' ($null -ne $reports.revenue -and $null -ne $reports.topDishes) "days=$($reports.revenueDays)"
    Add-Result 'Settings Load' ($settings.username -eq 'admin') $settings.username

    $categoryName = "AUTO_CAT_$stamp"
    Invoke-Json POST "$adminBase/categories" $session @{
        name = $categoryName
        description = 'auto category'
        displayOrder = 99
    } | Out-Null
    $categoriesAfterCreate = Invoke-Json GET "$adminBase/categories" $session
    $category = @($categoriesAfterCreate.categories | Where-Object { $_.name -eq $categoryName } | Sort-Object categoryId -Descending) | Select-Object -First 1
    if ($null -eq $category) { throw 'Khong tim thay category vua tao.' }
    $createdCategoryId = [int]$category.categoryId
    Invoke-Json PUT "$adminBase/categories/$createdCategoryId" $session @{
        name = "${categoryName}_EDIT"
        description = 'auto category edited'
        displayOrder = 98
        isActive = $true
    } | Out-Null
    Invoke-Json DELETE "$adminBase/categories/$createdCategoryId" $session | Out-Null
    $createdCategoryId = $null
    Add-Result 'Categories CRUD' $true "categoryId=$($category.categoryId)"

    $ingredientName = "AUTO_ING_$stamp"
    Invoke-Json POST "$adminBase/ingredients" $session @{
        name = $ingredientName
        unit = 'kg'
        currentStock = 19.5
        reorderLevel = 3
        isActive = $true
    } | Out-Null
    $ingredientsAfterCreate = Invoke-Json GET "$adminBase/ingredients?search=$ingredientName" $session
    $ingredient = @($ingredientsAfterCreate.ingredients.items | Where-Object { $_.name -eq $ingredientName } | Sort-Object ingredientId -Descending) | Select-Object -First 1
    if ($null -eq $ingredient) { throw 'Khong tim thay ingredient vua tao.' }
    $createdIngredientId = [int]$ingredient.ingredientId
    Invoke-Json PUT "$adminBase/ingredients/$createdIngredientId" $session @{
        name = "${ingredientName}_EDIT"
        unit = 'kg'
        currentStock = 21
        reorderLevel = 4
        isActive = $true
    } | Out-Null
    Add-Result 'Ingredients Create/Update' $true "ingredientId=$createdIngredientId"

    $categoryForDish = @($categories.categories | Select-Object -First 1)[0]
    if ($null -eq $categoryForDish) { throw 'Khong co category de tao dish.' }
    $dishName = "AUTO_DISH_$stamp"
    Invoke-Json POST "$adminBase/dishes" $session @{
        name = $dishName
        price = 65000
        categoryId = [int]$categoryForDish.categoryId
        description = 'auto dish'
        unit = 'phan'
        image = '/images/placeholder-dish.svg'
        isVegetarian = $false
        isDailySpecial = $false
        available = $true
        isActive = $true
    } | Out-Null
    $dishesAfterCreate = Invoke-Json GET "$adminBase/dishes?search=$dishName" $session
    $dish = @($dishesAfterCreate.dishes.items | Where-Object { $_.name -eq $dishName } | Sort-Object dishId -Descending) | Select-Object -First 1
    if ($null -eq $dish) { throw 'Khong tim thay dish vua tao.' }
    $createdDishId = [int]$dish.dishId
    Invoke-Json PUT "$adminBase/dishes/$createdDishId" $session @{
        name = "${dishName}_EDIT"
        price = 72000
        categoryId = [int]$categoryForDish.categoryId
        description = 'auto dish edited'
        unit = 'to'
        image = '/images/placeholder-dish.svg'
        isVegetarian = $false
        isDailySpecial = $false
        available = $true
        isActive = $true
    } | Out-Null
    Invoke-Json PUT "$adminBase/dishes/$createdDishId/ingredients" $session @{
        items = @(
            @{
                ingredientId = $createdIngredientId
                quantityPerDish = 1.25
            }
        )
    } | Out-Null
    Invoke-Json POST "$adminBase/dishes/$createdDishId/deactivate" $session @{} | Out-Null
    $createdDishId = $null
    Add-Result 'Dishes CRUD + Ingredients' $true "dishId=$($dish.dishId)"

    $tableBranch = @($dashboard.branches | Select-Object -First 1)[0]
    $tableStatus = @($dashboard.tableStatuses | Select-Object -First 1)[0]
    if ($null -eq $tableBranch -or $null -eq $tableStatus) { throw 'Khong co branch/status de tao table.' }
    $tableCode = "QA-TABLE-$stamp"
    Invoke-Json POST "$adminBase/tables" $session @{
        branchId = [int]$tableBranch.branchId
        numberOfSeats = 6
        qrCode = $tableCode
        statusId = [int]$tableStatus.statusId
        isActive = $true
    } | Out-Null
    $tablesAfterCreate = Invoke-Json GET "$adminBase/tables?search=$([uri]::EscapeDataString($tableCode))" $session
    $table = @($tablesAfterCreate.tables.items | Where-Object { $_.qrCode -eq $tableCode } | Sort-Object tableId -Descending) | Select-Object -First 1
    if ($null -eq $table) { throw 'Khong tim thay table vua tao.' }
    $createdTableId = [int]$table.tableId
    Invoke-Json PUT "$adminBase/tables/$createdTableId" $session @{
        branchId = [int]$tableBranch.branchId
        numberOfSeats = 8
        qrCode = "${tableCode}-EDIT"
        statusId = [int]$tableStatus.statusId
        isActive = $true
    } | Out-Null
    Invoke-Json POST "$adminBase/tables/$createdTableId/deactivate" $session @{} | Out-Null
    $createdTableId = $null
    Add-Result 'Tables CRUD' $true "tableId=$($table.tableId)"

    $customerUsername = "admincust_$stamp"
    Invoke-Json POST "$adminBase/customers" $session @{
        name = 'Admin Customer QA'
        username = $customerUsername
        password = 'Pass@123'
        phoneNumber = '09' + $stamp.Substring($stamp.Length - 8)
        email = "$customerUsername@example.com"
        gender = 'Nam'
        dateOfBirth = '2000-01-01'
        address = 'District 1'
        loyaltyPoints = 0
        isActive = $true
    } | Out-Null
    $customersAfterCreate = Invoke-Json GET "$adminBase/customers?search=$([uri]::EscapeDataString($customerUsername))" $session
    $customer = @($customersAfterCreate.customers.items | Where-Object { $_.username -eq $customerUsername } | Sort-Object customerId -Descending) | Select-Object -First 1
    if ($null -eq $customer) { throw 'Khong tim thay customer vua tao.' }
    $createdCustomerId = [int]$customer.customerId
    Invoke-Json PUT "$adminBase/customers/$createdCustomerId" $session @{
        name = 'Admin Customer QA Edit'
        username = $customerUsername
        password = $null
        phoneNumber = $customer.phoneNumber
        email = "$customerUsername.updated@example.com"
        gender = 'Nam'
        dateOfBirth = '2000-01-01'
        address = 'District 3'
        loyaltyPoints = 25
        isActive = $true
    } | Out-Null
    Invoke-Json POST "$adminBase/customers/$createdCustomerId/deactivate" $session @{} | Out-Null
    $createdCustomerId = $null
    Add-Result 'Customers CRUD' $true "customerId=$($customer.customerId)"

    $role = @($dashboard.roles | Where-Object { $_.roleCode -ne 'ADMIN' } | Select-Object -First 1)[0]
    $branch = @($dashboard.branches | Select-Object -First 1)[0]
    if ($null -eq $role -or $null -eq $branch) { throw 'Khong co role/branch de tao employee.' }
    $employeeUsername = "emp_$stamp"
    Invoke-Json POST "$adminBase/employees" $session @{
        name = 'Employee QA'
        username = $employeeUsername
        password = 'Pass@123'
        phone = '08' + $stamp.Substring($stamp.Length - 8)
        email = "$employeeUsername@example.com"
        salary = 5000000
        shift = 'Ca sáng'
        isActive = $true
        branchId = [int]$branch.branchId
        roleId = [int]$role.roleId
    } | Out-Null
    $employeesAfterCreate = Invoke-Json GET "$adminBase/employees?search=$([uri]::EscapeDataString($employeeUsername))" $session
    $employee = @($employeesAfterCreate.employees.items | Where-Object { $_.username -eq $employeeUsername } | Sort-Object employeeId -Descending) | Select-Object -First 1
    if ($null -eq $employee) { throw 'Khong tim thay employee vua tao.' }
    $createdEmployeeId = [int]$employee.employeeId
    Invoke-Json PUT "$adminBase/employees/$createdEmployeeId" $session @{
        name = 'Employee QA Edit'
        username = $employeeUsername
        password = $null
        phone = $employee.phone
        email = "$employeeUsername.updated@example.com"
        salary = 5500000
        shift = 'Ca chiều'
        isActive = $true
        branchId = [int]$branch.branchId
        roleId = [int]$role.roleId
    } | Out-Null
    $employeeHistory = Invoke-Json GET "$adminBase/employees/$createdEmployeeId/history?days=30" $session
    Invoke-Json POST "$adminBase/employees/$createdEmployeeId/deactivate" $session @{} | Out-Null
    $createdEmployeeId = $null
    Add-Result 'Employees CRUD + History' ($employeeHistory.employee.employeeId -eq $employee.employeeId) "employeeId=$($employee.employeeId)"

    $settingsUpdate = Invoke-Json PUT "$adminBase/settings" $session @{
        name = $originalSettings.Name
        phone = '0905333444'
        email = 'admin+qa@selfrestaurant.com'
    }
    Add-Result 'Update Settings' ($settingsUpdate.phone -eq '0905333444') $settingsUpdate.phone

    $settingsMismatch = Expect-ApiError POST "$adminBase/settings/change-password" $session @{
        currentPassword = '123456'
        newPassword = 'Temp@Admin123'
        confirmPassword = 'sai'
    }
    Add-Result 'Change Password Validation' ($settingsMismatch.code -eq 'password_mismatch') $settingsMismatch.code
}
catch {
    Add-Result 'ERROR' $false $_.Exception.Message
}
finally {
    try {
        if ($null -ne $originalSettings) {
            Invoke-Json PUT "$adminBase/settings" $session @{
                name = $originalSettings.Name
                phone = $originalSettings.Phone
                email = $originalSettings.Email
            } | Out-Null
        }
    } catch {}

    try {
        if ($null -ne $createdEmployeeId) {
            Invoke-Json POST "$adminBase/employees/$createdEmployeeId/deactivate" $session @{} | Out-Null
        }
    } catch {}

    try {
        if ($null -ne $createdCustomerId) {
            Invoke-Json POST "$adminBase/customers/$createdCustomerId/deactivate" $session @{} | Out-Null
        }
    } catch {}

    try {
        if ($null -ne $createdTableId) {
            Invoke-Json POST "$adminBase/tables/$createdTableId/deactivate" $session @{} | Out-Null
        }
    } catch {}

    try {
        if ($null -ne $createdDishId) {
            Invoke-Json POST "$adminBase/dishes/$createdDishId/deactivate" $session @{} | Out-Null
        }
    } catch {}

    try {
        if ($null -ne $createdIngredientId) {
            Invoke-Json POST "$adminBase/ingredients/$createdIngredientId/deactivate" $session @{} | Out-Null
        }
    } catch {}

    try {
        if ($null -ne $createdCategoryId) {
            Invoke-Json DELETE "$adminBase/categories/$createdCategoryId" $session | Out-Null
        }
    } catch {}

    try { Invoke-Json POST "$adminBase/auth/logout" $session @{} | Out-Null } catch {}
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass = ($results | Where-Object { $_.pass }).Count
$total = $results.Count
Write-Output "SUMMARY_TOTAL=$total"
Write-Output "SUMMARY_PASSED=$pass"
Write-Output "SUMMARY_FAILED=$($total - $pass)"
if ($pass -ne $total) { exit 1 }
