using System.Globalization;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Api.Infrastructure;
using SelfRestaurant.Gateway.Api.Models;
using SelfRestaurant.Gateway.Api.Services;

namespace SelfRestaurant.Gateway.Api.Controllers;

[ApiController]
[Route("api/gateway/admin")]
public sealed class AdminGatewayController : ControllerBase
{
    private static readonly string[] AdminRoles = ["ADMIN", "MANAGER"];

    private readonly IdentityClient _identityClient;
    private readonly OrdersClient _ordersClient;
    private readonly CatalogClient _catalogClient;
    private readonly CustomersClient _customersClient;
    private readonly ILogger<AdminGatewayController> _logger;
    private readonly IWebHostEnvironment _environment;

    public AdminGatewayController(
        IdentityClient identityClient,
        OrdersClient ordersClient,
        CatalogClient catalogClient,
        CustomersClient customersClient,
        ILogger<AdminGatewayController> logger,
        IWebHostEnvironment environment)
    {
        _identityClient = identityClient;
        _ordersClient = ordersClient;
        _catalogClient = catalogClient;
        _customersClient = customersClient;
        _logger = logger;
        _environment = environment;
    }

    [HttpGet("session")]
    public ActionResult<StaffSessionDto> GetSession() => Ok(BuildSessionDto());

    [HttpPost("auth/login")]
    public async Task<ActionResult<object>> Login([FromBody] StaffLoginApiRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return Error("invalid_request", "Vui lòng nhập đầy đủ thông tin.", 400);
        }

        try
        {
            var staff = await _identityClient.StaffLoginAsync(new StaffLoginRequest(request.Username.Trim(), request.Password), cancellationToken);
            if (staff is null)
            {
                return Error("invalid_credentials", "Tên đăng nhập hoặc mật khẩu không đúng.", 401);
            }

            if (!AdminRoles.Contains(staff.RoleCode, StringComparer.OrdinalIgnoreCase))
            {
                return Error("forbidden", "Bạn không có quyền truy cập khu vực quản trị.", 403);
            }

            ApplyStaffSession(staff);
            return Ok(new { success = true, session = BuildSessionDto(), nextPath = "/Admin/Dashboard/Index" });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Admin login failed.");
            return Error("login_failed", ex.Message, 400);
        }
    }

    [HttpPost("auth/logout")]
    public ActionResult<object> Logout()
    {
        var userName = HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? "Người dùng";
        ClearStaffSession();
        return Ok(new
        {
            success = true,
            nextPath = $"/Staff/Account/Login?message={Uri.EscapeDataString($"Tạm biệt {userName}! Bạn đã đăng xuất thành công.")}&type=success"
        });
    }

    [HttpGet("dashboard")]
    public async Task<ActionResult<AdminDashboardDto>> GetDashboard(CancellationToken cancellationToken)
    {
        var admin = RequireAdmin();
        if (admin is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);

        var identityStatsTask = _identityClient.GetAdminStatsAsync(cancellationToken);
        var orderStatsTask = _ordersClient.GetAdminStatsAsync(null, cancellationToken);
        var employeesTask = _identityClient.GetAdminEmployeesAsync(null, null, null, 1, 5, cancellationToken);
        var branchesTask = _catalogClient.GetBranchesAsync(cancellationToken);
        var rolesTask = _identityClient.GetEmployeeRolesAsync(cancellationToken);
        var categoriesTask = _catalogClient.GetCategoriesAsync(false, cancellationToken);
        var statusesTask = _catalogClient.GetTableStatusesAsync(cancellationToken);

        await Task.WhenAll(identityStatsTask, orderStatsTask, employeesTask, branchesTask, rolesTask, categoriesTask, statusesTask);

        return Ok(new AdminDashboardDto(
            admin,
            new AdminDashboardStatsDto(
                identityStatsTask.Result?.TotalEmployees ?? 0,
                identityStatsTask.Result?.ActiveEmployees ?? 0,
                identityStatsTask.Result?.BranchCount ?? 0,
                orderStatsTask.Result?.TodayOrders ?? 0,
                orderStatsTask.Result?.PendingOrders ?? 0,
                orderStatsTask.Result?.TodayRevenue ?? 0),
            employeesTask.Result?.Items ?? Array.Empty<AdminEmployeeDto>(),
            branchesTask.Result ?? Array.Empty<BranchDto>(),
            rolesTask.Result,
            categoriesTask.Result ?? Array.Empty<CategoryDto>(),
            statusesTask.Result,
            BuildSettingsDto(admin)));
    }

    [HttpGet("categories")]
    public async Task<ActionResult<AdminCategoriesScreenDto>> GetCategories(CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var categories = await _catalogClient.GetCategoriesAsync(false, cancellationToken) ?? Array.Empty<CategoryDto>();
        var units = await BuildUnitSummaryAsync(cancellationToken);
        return Ok(new AdminCategoriesScreenDto(categories.OrderBy(x => x.DisplayOrder).ThenBy(x => x.CategoryId).ToArray(), units));
    }

    [HttpPost("categories")]
    public async Task<ActionResult<object>> CreateCategory([FromBody] CreateCategoryRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.CreateCategoryAsync(request, cancellationToken);
        return Ok(new { success = true, message = "Da tao danh muc moi." });
    }

    [HttpPut("categories/{categoryId:int}")]
    public async Task<ActionResult<object>> UpdateCategory(int categoryId, [FromBody] UpdateCategoryRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.UpdateCategoryAsync(categoryId, request, cancellationToken);
        return Ok(new { success = true, message = "Da cap nhat danh muc." });
    }

    [HttpDelete("categories/{categoryId:int}")]
    public async Task<ActionResult<object>> DeleteCategory(int categoryId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.DeleteCategoryAsync(categoryId, cancellationToken);
        return Ok(new { success = true, message = "Da xoa danh muc." });
    }

    [HttpGet("dishes")]
    public async Task<ActionResult<AdminDishesScreenDto>> GetDishes([FromQuery] string? search, [FromQuery] int? categoryId, [FromQuery] int page = 1, [FromQuery] int pageSize = 10, [FromQuery] bool includeInactive = false, CancellationToken cancellationToken = default)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var dishes = await _catalogClient.GetAdminDishesAsync(search, categoryId, page, pageSize, includeInactive, cancellationToken)
            ?? new AdminDishPagedResponse(Math.Max(1, page), Math.Clamp(pageSize, 1, 100), 0, 0, Array.Empty<AdminDishDto>());
        var categories = await _catalogClient.GetCategoriesAsync(false, cancellationToken) ?? Array.Empty<CategoryDto>();
        return Ok(new AdminDishesScreenDto(dishes, categories));
    }

    [HttpPost("dishes")]
    public async Task<ActionResult<object>> CreateDish([FromBody] AdminUpsertDishRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.CreateAdminDishAsync(request, cancellationToken);
        return Ok(new { success = true, message = "Da them mon moi." });
    }

    [HttpPut("dishes/{dishId:int}")]
    public async Task<ActionResult<object>> UpdateDish(int dishId, [FromBody] AdminUpsertDishRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.UpdateAdminDishAsync(dishId, request, cancellationToken);
        return Ok(new { success = true, message = "Da cap nhat mon an." });
    }

    [HttpPost("dishes/upload")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<object>> CreateDishWithImage([FromForm] AdminUpsertDishFormRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var imagePath = request.ImageFile is null ? request.Image : await SaveDishImageAsync(request.Name, request.ImageFile, null, cancellationToken);
        await _catalogClient.CreateAdminDishAsync(BuildDishRequest(request, imagePath), cancellationToken);
        return Ok(new { success = true, message = "Da them mon moi va luu anh." });
    }

    [HttpPut("dishes/{dishId:int}/upload")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<object>> UpdateDishWithImage(int dishId, [FromForm] AdminUpsertDishFormRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan quan tri.", 401);
        var current = await _catalogClient.GetAdminDishByIdAsync(dishId, cancellationToken);
        if (current is null) return Error("dish_not_found", "Không tìm thấy món ăn.", 404);
        var imagePath = request.ImageFile is null ? (request.Image ?? current.Image) : await SaveDishImageAsync(request.Name, request.ImageFile, current.Image, cancellationToken);
        await _catalogClient.UpdateAdminDishAsync(dishId, BuildDishRequest(request, imagePath), cancellationToken);
        return Ok(new { success = true, message = "Da cap nhat mon an va dong bo anh." });
    }

    [HttpPost("dishes/{dishId:int}/deactivate")]
    public async Task<ActionResult<object>> DeactivateDish(int dishId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.DeactivateAdminDishAsync(dishId, cancellationToken);
        return Ok(new { success = true, message = "Da vo hieu hoa mon an." });
    }

    [HttpPost("dishes/{dishId:int}/availability")]
    public async Task<ActionResult<object>> SetDishAvailability(int dishId, [FromBody] AdminToggleAvailabilityApiRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var current = await _catalogClient.GetAdminDishByIdAsync(dishId, cancellationToken);
        if (current is null) return Error("dish_not_found", "Không tìm thấy món ăn.", 404);
        await _catalogClient.UpdateAdminDishAsync(dishId, new AdminUpsertDishRequest(current.Name, current.Price, current.CategoryId, current.Description, current.Unit, current.Image, current.IsVegetarian, current.IsDailySpecial, request.Available, current.IsActive), cancellationToken);
        return Ok(new { success = true, message = request.Available ? "Da mo ban mon an." : "Da tam ngung ban mon an.", available = request.Available });
    }

    [HttpGet("dishes/{dishId:int}/ingredients")]
    public async Task<ActionResult<IReadOnlyList<AdminDishIngredientLineDto>>> GetDishIngredients(int dishId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        return Ok(await _catalogClient.GetDishIngredientsAsync(dishId, cancellationToken));
    }

    [HttpPut("dishes/{dishId:int}/ingredients")]
    public async Task<ActionResult<object>> UpdateDishIngredients(int dishId, [FromBody] AdminUpdateDishIngredientsRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan quan tri.", 401);
        await _catalogClient.UpdateDishIngredientsAsync(dishId, request.Items, cancellationToken);
        return Ok(new { success = true, message = "Da cap nhat nguyen lieu mon an." });
    }

    [HttpGet("ingredients")]
    public async Task<ActionResult<AdminIngredientsScreenDto>> GetIngredients([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var ingredients = await _catalogClient.GetAdminIngredientsAsync(search, page, pageSize, cancellationToken)
            ?? new AdminIngredientPagedResponse(Math.Max(1, page), Math.Clamp(pageSize, 1, 100), 0, 0, Array.Empty<AdminIngredientDto>());
        return Ok(new AdminIngredientsScreenDto(ingredients));
    }

    [HttpPost("ingredients")]
    public async Task<ActionResult<object>> CreateIngredient([FromBody] AdminUpsertIngredientRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.CreateAdminIngredientAsync(request, cancellationToken);
        return Ok(new { success = true, message = "Da them nguyen lieu moi." });
    }

    [HttpPut("ingredients/{ingredientId:int}")]
    public async Task<ActionResult<object>> UpdateIngredient(int ingredientId, [FromBody] AdminUpsertIngredientRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.UpdateAdminIngredientAsync(ingredientId, request, cancellationToken);
        return Ok(new { success = true, message = "Da cap nhat nguyen lieu." });
    }

    [HttpPost("ingredients/{ingredientId:int}/deactivate")]
    public async Task<ActionResult<object>> DeactivateIngredient(int ingredientId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _catalogClient.DeactivateAdminIngredientAsync(ingredientId, cancellationToken);
        return Ok(new { success = true, message = "Da vo hieu hoa nguyen lieu." });
    }

    [HttpGet("tables")]
    public async Task<ActionResult<AdminTablesScreenDto>> GetTables([FromQuery] int? branchId, [FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken cancellationToken = default)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var tablesTask = _catalogClient.GetAdminTablesAsync(branchId, search, page, pageSize, cancellationToken);
        var branchesTask = _catalogClient.GetBranchesAsync(cancellationToken);
        var statusesTask = _catalogClient.GetTableStatusesAsync(cancellationToken);
        await Task.WhenAll(tablesTask, branchesTask, statusesTask);
        var tables = tablesTask.Result ?? new AdminTablePagedResponse(Math.Max(1, page), Math.Clamp(pageSize, 1, 100), 0, 0, Array.Empty<AdminTableDto>());
        return Ok(new AdminTablesScreenDto(tables, branchesTask.Result ?? Array.Empty<BranchDto>(), statusesTask.Result));
    }

    [HttpPost("tables")]
    public async Task<ActionResult<object>> CreateTable([FromBody] AdminUpsertTableRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan quan tri.", 401);
        await _catalogClient.CreateAdminTableAsync(request, cancellationToken);
        return Ok(new { success = true, message = "Da them ban moi." });
    }

    [HttpPut("tables/{tableId:int}")]
    public async Task<ActionResult<object>> UpdateTable(int tableId, [FromBody] AdminUpsertTableRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan quan tri.", 401);
        await _catalogClient.UpdateAdminTableAsync(tableId, request, cancellationToken);
        return Ok(new { success = true, message = "Da cap nhat ban." });
    }

    [HttpPost("tables/{tableId:int}/deactivate")]
    public async Task<ActionResult<object>> DeactivateTable(int tableId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan quan tri.", 401);
        await _catalogClient.DeactivateAdminTableAsync(tableId, cancellationToken);
        return Ok(new { success = true, message = "Da vo hieu hoa ban." });
    }

    [HttpGet("employees")]
    public async Task<ActionResult<AdminEmployeesScreenDto>> GetEmployees([FromQuery] string? search, [FromQuery] int? branchId, [FromQuery] int? roleId, [FromQuery] int page = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var employeesTask = _identityClient.GetAdminEmployeesAsync(search, branchId, roleId, page, pageSize, cancellationToken);
        var branchesTask = _catalogClient.GetBranchesAsync(cancellationToken);
        var rolesTask = _identityClient.GetEmployeeRolesAsync(cancellationToken);
        await Task.WhenAll(employeesTask, branchesTask, rolesTask);
        var employees = employeesTask.Result ?? new AdminEmployeePagedResponse(Math.Max(1, page), Math.Clamp(pageSize, 1, 100), 0, 0, Array.Empty<AdminEmployeeDto>());
        return Ok(new AdminEmployeesScreenDto(employees, branchesTask.Result ?? Array.Empty<BranchDto>(), rolesTask.Result));
    }

    [HttpGet("employees/{employeeId:int}")]
    public async Task<ActionResult<AdminEmployeeDto>> GetEmployeeById(int employeeId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var employee = await _identityClient.GetAdminEmployeeByIdAsync(employeeId, cancellationToken);
        return employee is null ? Error("employee_not_found", "Không tìm thấy nhân viên.", 404) : Ok(employee);
    }

    [HttpPost("employees")]
    public async Task<ActionResult<object>> CreateEmployee([FromBody] AdminUpsertEmployeeRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _identityClient.CreateAdminEmployeeAsync(request, cancellationToken);
        return Ok(new { success = true, message = "Đã thêm nhân viên mới." });
    }

    [HttpPut("employees/{employeeId:int}")]
    public async Task<ActionResult<object>> UpdateEmployee(int employeeId, [FromBody] AdminUpsertEmployeeRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _identityClient.UpdateAdminEmployeeAsync(employeeId, request, cancellationToken);
        return Ok(new { success = true, message = "Đã cập nhật nhân viên." });
    }

    [HttpPost("employees/{employeeId:int}/deactivate")]
    public async Task<ActionResult<object>> DeactivateEmployee(int employeeId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _identityClient.DeactivateAdminEmployeeAsync(employeeId, cancellationToken);
        return Ok(new { success = true, message = "Đã khóa nhân viên." });
    }

    [HttpGet("employees/{employeeId:int}/history")]
    public async Task<ActionResult<AdminEmployeeHistoryResponse>> GetEmployeeHistory(int employeeId, [FromQuery] int days = 90, CancellationToken cancellationToken = default)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan quan tri.", 401);
        var history = await _identityClient.GetAdminEmployeeHistoryAsync(employeeId, days, 200, cancellationToken);
        return history is null ? Error("history_not_found", "Không tải được lịch sử nhân viên.", 404) : Ok(history);
    }

    [HttpGet("customers")]
    public async Task<ActionResult<AdminCustomersScreenDto>> GetCustomers([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var customers = await _customersClient.GetAdminCustomersAsync(search, page, pageSize, cancellationToken)
            ?? new AdminCustomerPagedResponse(Math.Max(1, page), Math.Clamp(pageSize, 1, 100), 0, 0, Array.Empty<AdminCustomerDto>());
        return Ok(new AdminCustomersScreenDto(customers));
    }

    [HttpGet("customers/{customerId:int}")]
    public async Task<ActionResult<AdminCustomerDto>> GetCustomerById(int customerId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var customer = await _customersClient.GetAdminCustomerByIdAsync(customerId, cancellationToken);
        return customer is null ? Error("customer_not_found", "Không tìm thấy khách hàng.", 404) : Ok(customer);
    }

    [HttpPost("customers")]
    public async Task<ActionResult<object>> CreateCustomer([FromBody] AdminUpsertCustomerRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _customersClient.CreateAdminCustomerAsync(request, cancellationToken);
        return Ok(new { success = true, message = "Đã thêm khách hàng mới." });
    }

    [HttpPut("customers/{customerId:int}")]
    public async Task<ActionResult<object>> UpdateCustomer(int customerId, [FromBody] AdminUpsertCustomerRequest request, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _customersClient.UpdateAdminCustomerAsync(customerId, request, cancellationToken);
        return Ok(new { success = true, message = "Đã cập nhật khách hàng." });
    }

    [HttpPost("customers/{customerId:int}/deactivate")]
    public async Task<ActionResult<object>> DeactivateCustomer(int customerId, CancellationToken cancellationToken)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        await _customersClient.DeactivateAdminCustomerAsync(customerId, cancellationToken);
        return Ok(new { success = true, message = "Đã khóa khách hàng." });
    }

    [HttpGet("reports")]
    public async Task<ActionResult<AdminReportsScreenDto>> GetReports([FromQuery] int revenueDays = 30, [FromQuery] int topDishDays = 30, [FromQuery] int topDishTake = 10, CancellationToken cancellationToken = default)
    {
        if (RequireAdmin() is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        var revenueTask = _ordersClient.GetAdminRevenueReportAsync(revenueDays, cancellationToken);
        var topDishesTask = _ordersClient.GetAdminTopDishesReportAsync(topDishDays, topDishTake, cancellationToken);
        await Task.WhenAll(revenueTask, topDishesTask);
        return Ok(new AdminReportsScreenDto(
            Math.Clamp(revenueDays, 1, 365),
            Math.Clamp(topDishDays, 1, 365),
            Math.Clamp(topDishTake, 1, 50),
            revenueTask.Result ?? new AdminRevenueReportDto(0, Array.Empty<AdminRevenueReportRowDto>()),
            topDishesTask.Result ?? new AdminTopDishReportDto(Array.Empty<AdminTopDishReportItemDto>())));
    }

    [HttpGet("settings")]
    public ActionResult<AdminSettingsDto> GetSettings()
    {
        var admin = RequireAdmin();
        return admin is null ? Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401) : Ok(BuildSettingsDto(admin));
    }

    [HttpPut("settings")]
    public async Task<ActionResult<AdminSettingsDto>> UpdateSettings([FromBody] AdminSettingsUpdateApiRequest request, CancellationToken cancellationToken)
    {
        var admin = RequireAdmin();
        if (admin is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        if (string.IsNullOrWhiteSpace(request.Name) || string.IsNullOrWhiteSpace(request.Phone))
        {
            return Error("invalid_request", "Vui lòng nhập đầy đủ họ tên và số điện thoại.", 400);
        }

        var profile = await _identityClient.UpdateStaffProfileAsync(admin.EmployeeId, new StaffUpdateProfileRequest(request.Name.Trim(), request.Phone.Trim(), string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim()), cancellationToken);
        if (profile is not null)
        {
            HttpContext.Session.SetString(SessionKeys.EmployeeName, profile.Name);
            HttpContext.Session.SetString(SessionKeys.EmployeePhone, profile.Phone ?? string.Empty);
            HttpContext.Session.SetString(SessionKeys.EmployeeEmail, profile.Email ?? string.Empty);
            HttpContext.Session.SetString(SessionKeys.EmployeeUsername, profile.Username);
        }

        return Ok(BuildSettingsDto(RequireAdmin() ?? admin));
    }

    [HttpPost("settings/change-password")]
    public async Task<ActionResult<object>> ChangePassword([FromBody] AdminChangePasswordApiRequest request, CancellationToken cancellationToken)
    {
        var admin = RequireAdmin();
        if (admin is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản quản trị.", 401);
        if (string.IsNullOrWhiteSpace(request.CurrentPassword) || string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return Error("invalid_request", "Vui lòng nhập đầy đủ thông tin đổi mật khẩu.", 400);
        }
        if (!string.Equals(request.NewPassword, request.ConfirmPassword, StringComparison.Ordinal))
        {
            return Error("password_mismatch", "Mật khẩu xác nhận không khớp.", 400);
        }

        await _identityClient.StaffChangePasswordAsync(new StaffChangePasswordRequest(admin.EmployeeId, request.CurrentPassword, request.NewPassword), cancellationToken);
        return Ok(new { success = true, message = "Doi mat khau thanh cong." });
    }

    private AdminUpsertDishRequest BuildDishRequest(AdminUpsertDishFormRequest request, string? imagePath) => new(
        request.Name.Trim(),
        request.Price,
        request.CategoryId,
        string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim(),
        string.IsNullOrWhiteSpace(request.Unit) ? null : request.Unit.Trim(),
        string.IsNullOrWhiteSpace(imagePath) ? null : imagePath,
        request.IsVegetarian,
        request.IsDailySpecial,
        request.Available,
        request.IsActive);

    private async Task<string> SaveDishImageAsync(string dishName, IFormFile imageFile, string? existingImagePath, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(dishName))
        {
            throw new InvalidOperationException("Ten mon an khong hop le de tao ten file anh.");
        }

        var extension = Path.GetExtension(imageFile.FileName)?.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(extension))
        {
            extension = ".png";
        }

        var imageRoots = ResolveDishImagesRoots();
        foreach (var imageRoot in imageRoots)
        {
            Directory.CreateDirectory(imageRoot);
        }

        var slug = SlugifyDishName(dishName);
        var fileName = $"{slug}{extension}";
        var targetPaths = imageRoots
            .Select(root => new { Root = root, AbsolutePath = Path.Combine(root, fileName) })
            .ToArray();

        foreach (var target in targetPaths)
        {
            DeleteManagedDishImage(existingImagePath, target.Root, target.AbsolutePath);
            DeleteSiblingSlugFiles(target.Root, slug, target.AbsolutePath);
        }

        await using var uploadStream = imageFile.OpenReadStream();
        using var buffer = new MemoryStream();
        await uploadStream.CopyToAsync(buffer, cancellationToken);
        var content = buffer.ToArray();

        foreach (var target in targetPaths)
        {
            await System.IO.File.WriteAllBytesAsync(target.AbsolutePath, content, cancellationToken);
        }

        return $"/images/dishes/{fileName}";
    }

    private IReadOnlyList<string> ResolveDishImagesRoots()
    {
        var contentRoot = Path.GetFullPath(_environment.ContentRootPath);
        var inBuildOutput = contentRoot.Contains("/bin/", StringComparison.OrdinalIgnoreCase)
            || contentRoot.Contains("\\bin\\", StringComparison.OrdinalIgnoreCase);

        var direct = Path.Combine(contentRoot, "wwwroot", "images", "dishes");
        var source = Path.GetFullPath(Path.Combine(contentRoot, "..", "..", "..", "wwwroot", "images", "dishes"));
        var candidates = inBuildOutput ? new[] { direct, source } : new[] { direct, source };
        var roots = new List<string>();

        foreach (var candidate in candidates)
        {
            var wwwroot = Directory.GetParent(candidate)?.Parent?.FullName;
            if (!string.IsNullOrWhiteSpace(wwwroot) && Directory.Exists(wwwroot))
            {
                roots.Add(candidate);
            }
        }

        if (roots.Count == 0)
        {
            roots.Add(candidates[0]);
        }

        return roots
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static void DeleteManagedDishImage(string? existingImagePath, string imagesRoot, string nextAbsolutePath)
    {
        var existingAbsolute = ResolveManagedDishImagePath(existingImagePath, imagesRoot);
        if (existingAbsolute is null) return;
        if (string.Equals(existingAbsolute, nextAbsolutePath, StringComparison.OrdinalIgnoreCase)) return;
        if (System.IO.File.Exists(existingAbsolute))
        {
            System.IO.File.Delete(existingAbsolute);
        }
    }

    private static void DeleteSiblingSlugFiles(string imagesRoot, string slug, string nextAbsolutePath)
    {
        foreach (var file in Directory.GetFiles(imagesRoot, slug + ".*", SearchOption.TopDirectoryOnly))
        {
            if (string.Equals(file, nextAbsolutePath, StringComparison.OrdinalIgnoreCase)) continue;
            System.IO.File.Delete(file);
        }
    }

    private static string? ResolveManagedDishImagePath(string? imagePath, string imagesRoot)
    {
        if (string.IsNullOrWhiteSpace(imagePath)) return null;
        var normalized = imagePath.Replace('\\', '/').Trim();
        if (!normalized.StartsWith("/images/dishes/", StringComparison.OrdinalIgnoreCase)) return null;
        var fileName = Path.GetFileName(normalized);
        if (string.IsNullOrWhiteSpace(fileName)) return null;
        return Path.Combine(imagesRoot, fileName);
    }

    private static string SlugifyDishName(string dishName)
    {
        var normalized = dishName.Trim().Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(normalized.Length);
        var previousDash = false;

        foreach (var ch in normalized)
        {
            var unicodeCategory = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (unicodeCategory == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            var mapped = ch switch
            {
                'đ' or 'Ð' => 'd',
                'Đ' => 'd',
                _ => char.ToLowerInvariant(ch)
            };

            if ((mapped >= 'a' && mapped <= 'z') || (mapped >= '0' && mapped <= '9'))
            {
                builder.Append(mapped);
                previousDash = false;
                continue;
            }

            if (previousDash || builder.Length == 0)
            {
                continue;
            }

            builder.Append('-');
            previousDash = true;
        }

        var result = builder.ToString().Trim('-');
        return string.IsNullOrWhiteSpace(result) ? "dish-image" : result;
    }

    private async Task<IReadOnlyList<AdminCategorySummaryDto>> BuildUnitSummaryAsync(CancellationToken cancellationToken)
    {
        var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var page = 1;
        while (true)
        {
            var dishes = await _catalogClient.GetAdminDishesAsync(null, null, page, 100, false, cancellationToken);
            if (dishes is null || dishes.Items.Count == 0) break;

            foreach (var dish in dishes.Items)
            {
                var unit = (dish.Unit ?? string.Empty).Trim();
                if (string.IsNullOrWhiteSpace(unit)) continue;
                counts[unit] = counts.TryGetValue(unit, out var current) ? current + 1 : 1;
            }

            if (page >= dishes.TotalPages) break;
            page++;
        }

        return counts.OrderBy(x => x.Key).Select(x => new AdminCategorySummaryDto(x.Key, x.Value)).ToArray();
    }

    private void ApplyStaffSession(StaffLoginResponse login)
    {
        HttpContext.Session.SetInt32(SessionKeys.EmployeeId, login.EmployeeId);
        HttpContext.Session.SetString(SessionKeys.EmployeeUsername, login.Username);
        HttpContext.Session.SetString(SessionKeys.EmployeeName, login.Name);
        HttpContext.Session.SetString(SessionKeys.EmployeePhone, login.Phone ?? string.Empty);
        HttpContext.Session.SetString(SessionKeys.EmployeeEmail, login.Email ?? string.Empty);
        HttpContext.Session.SetInt32(SessionKeys.EmployeeRoleId, login.RoleId);
        HttpContext.Session.SetString(SessionKeys.EmployeeRoleCode, login.RoleCode);
        HttpContext.Session.SetString(SessionKeys.EmployeeRoleName, login.RoleName);
        HttpContext.Session.SetInt32(SessionKeys.EmployeeBranchId, login.BranchId);
        HttpContext.Session.SetString(SessionKeys.EmployeeBranchName, login.BranchName);
    }

    private StaffSessionDto BuildSessionDto() => new(RequireStaff() is not null, RequireStaff(), "/Staff/Account/Login");
    private StaffSessionUserDto? RequireAdmin() => RequireStaff(AdminRoles);

    private StaffSessionUserDto? RequireStaff(params string[] allowedRoles)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        var roleCode = HttpContext.Session.GetString(SessionKeys.EmployeeRoleCode);
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);

        if (employeeId is null || employeeId <= 0 || string.IsNullOrWhiteSpace(roleCode) || branchId is null || branchId <= 0)
        {
            return null;
        }

        if (allowedRoles.Length > 0 && !allowedRoles.Contains(roleCode, StringComparer.OrdinalIgnoreCase))
        {
            return null;
        }

        return new StaffSessionUserDto(
            employeeId.Value,
            HttpContext.Session.GetString(SessionKeys.EmployeeUsername) ?? string.Empty,
            HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? string.Empty,
            HttpContext.Session.GetString(SessionKeys.EmployeePhone),
            HttpContext.Session.GetString(SessionKeys.EmployeeEmail),
            HttpContext.Session.GetInt32(SessionKeys.EmployeeRoleId) ?? 0,
            roleCode,
            HttpContext.Session.GetString(SessionKeys.EmployeeRoleName) ?? string.Empty,
            branchId.Value,
            HttpContext.Session.GetString(SessionKeys.EmployeeBranchName) ?? string.Empty);
    }

    private AdminSettingsDto BuildSettingsDto(StaffSessionUserDto admin) => new(
        admin.EmployeeId,
        HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? admin.Name,
        HttpContext.Session.GetString(SessionKeys.EmployeeUsername) ?? admin.Username,
        HttpContext.Session.GetString(SessionKeys.EmployeePhone) ?? admin.Phone,
        HttpContext.Session.GetString(SessionKeys.EmployeeEmail) ?? admin.Email,
        HttpContext.Session.GetString(SessionKeys.EmployeeBranchName) ?? admin.BranchName,
        HttpContext.Session.GetString(SessionKeys.EmployeeRoleName) ?? admin.RoleName);

    private void ClearStaffSession()
    {
        HttpContext.Session.Remove(SessionKeys.EmployeeId);
        HttpContext.Session.Remove(SessionKeys.EmployeeUsername);
        HttpContext.Session.Remove(SessionKeys.EmployeeName);
        HttpContext.Session.Remove(SessionKeys.EmployeePhone);
        HttpContext.Session.Remove(SessionKeys.EmployeeEmail);
        HttpContext.Session.Remove(SessionKeys.EmployeeRoleId);
        HttpContext.Session.Remove(SessionKeys.EmployeeRoleCode);
        HttpContext.Session.Remove(SessionKeys.EmployeeRoleName);
        HttpContext.Session.Remove(SessionKeys.EmployeeBranchId);
        HttpContext.Session.Remove(SessionKeys.EmployeeBranchName);
    }

    private ActionResult Error(string code, string message, int statusCode, object? details = null)
    {
        return StatusCode(statusCode, new ApiErrorResponse(false, code, message, details));
    }
}
