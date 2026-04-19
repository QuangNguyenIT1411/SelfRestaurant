using System.Globalization;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Api.Infrastructure;
using SelfRestaurant.Gateway.Api.Models;
using SelfRestaurant.Gateway.Api.Services;

namespace SelfRestaurant.Gateway.Api.Controllers;

[ApiController]
[Route("api/gateway/staff/cashier")]
public sealed class StaffCashierGatewayController : ControllerBase
{
    private static readonly string[] CashierRoles = ["CASHIER", "MANAGER", "ADMIN"];

    private readonly BillingClient _billingClient;
    private readonly IdentityClient _identityClient;
    private readonly CatalogClient _catalogClient;
    private readonly ILogger<StaffCashierGatewayController> _logger;

    public StaffCashierGatewayController(
        BillingClient billingClient,
        IdentityClient identityClient,
        CatalogClient catalogClient,
        ILogger<StaffCashierGatewayController> logger)
    {
        _billingClient = billingClient;
        _identityClient = identityClient;
        _catalogClient = catalogClient;
        _logger = logger;
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

            if (!CashierRoles.Contains(staff.RoleCode, StringComparer.OrdinalIgnoreCase))
            {
                return Error("forbidden", "Bạn không có quyền truy cập trang Thu Ngân.", 403);
            }

            ApplyStaffSession(staff);
            return Ok(new { success = true, session = BuildSessionDto(), nextPath = "/Staff/Cashier/Index" });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Staff cashier login failed.");
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
    public async Task<ActionResult<CashierDashboardDto>> GetDashboard(CancellationToken cancellationToken)
    {
        var staff = RequireCashier();
        if (staff is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan thu ngan.", 401);
        return Ok(await BuildDashboardAsync(staff.BranchId, staff, includeBills: false, billsDate: null, cancellationToken));
    }

    [HttpGet("history")]
    public async Task<ActionResult<CashierHistoryDto>> GetHistory([FromQuery] int take = 100, CancellationToken cancellationToken = default)
    {
        var staff = RequireCashier();
        if (staff is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan thu ngan.", 401);

        var bills = await _billingClient.GetBillsAsync(staff.EmployeeId, staff.BranchId, null, Math.Clamp(take, 1, 300), cancellationToken);
        return Ok(new CashierHistoryDto(staff, bills.Select(MapBill).ToArray(), BuildAccountDto(staff)));
    }

    [HttpGet("report")]
    public async Task<ActionResult<CashierReportScreenDto>> GetReport([FromQuery] DateOnly? date, CancellationToken cancellationToken)
    {
        var staff = RequireCashier();
        if (staff is null) return Error("unauthorized", "Ban can dang nhap bang tai khoan thu ngan.", 401);

        var targetDate = date ?? DateOnly.FromDateTime(DateTime.Today);
        var report = await _billingClient.GetReportAsync(staff.EmployeeId, staff.BranchId, targetDate, cancellationToken);
        if (report is null)
        {
            return Ok(new CashierReportScreenDto(staff, targetDate, 0, 0, Array.Empty<CashierBillHistoryItemDto>(), BuildAccountDto(staff)));
        }

        return Ok(new CashierReportScreenDto(
            staff,
            report.Date,
            report.BillCount,
            report.TotalRevenue,
            report.Bills.Select(MapBill).ToArray(),
            BuildAccountDto(staff)));
    }

    [HttpPost("orders/{orderId:int}/checkout")]
    public async Task<ActionResult<CashierCheckoutResultDto>> Checkout(int orderId, [FromBody] CashierCheckoutApiRequest request, CancellationToken cancellationToken)
    {
        var staff = RequireCashier();
        if (staff is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản thu ngân.", 401);
        if (orderId <= 0) return Error("invalid_order", "Đơn hàng không hợp lệ.", 400);

        try
        {
            var response = await _billingClient.CheckoutAsync(orderId, new CashierCheckoutRequest(
                EmployeeId: staff.EmployeeId,
                Discount: Math.Max(0, request.Discount),
                PointsUsed: Math.Max(0, request.PointsUsed),
                PaymentMethod: string.IsNullOrWhiteSpace(request.PaymentMethod) ? "CASH" : request.PaymentMethod.Trim().ToUpperInvariant(),
                PaymentAmount: Math.Max(0, request.PaymentAmount)), cancellationToken);

            if (response is null)
            {
                return Error("checkout_failed", "Không nhận được phản hồi thanh toán.", 502);
            }

            return Ok(new CashierCheckoutResultDto(
                response.BillCode,
                response.TotalAmount,
                response.ChangeAmount,
                response.PointsUsed,
                response.PointsEarned,
                response.CustomerPoints,
                response.CustomerName,
                response.PointsBefore,
                "Thanh toán thành công."));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cashier checkout failed for order {OrderId}", orderId);
            return Error("checkout_failed", ex.Message, 400);
        }
    }

    [HttpPut("account")]
    public async Task<ActionResult<CashierAccountDto>> UpdateAccount([FromBody] CashierAccountUpdateApiRequest request, CancellationToken cancellationToken)
    {
        var staff = RequireCashier();
        if (staff is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản thu ngân.", 401);
        if (string.IsNullOrWhiteSpace(request.Name) || string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Phone))
        {
            return Error("invalid_request", "Vui lòng nhập đầy đủ họ tên, email và số điện thoại.", 400);
        }

        try
        {
            var profile = await _identityClient.UpdateStaffProfileAsync(
                staff.EmployeeId,
                new StaffUpdateProfileRequest(request.Name.Trim(), request.Phone.Trim(), request.Email.Trim()),
                cancellationToken);

            if (profile is not null)
            {
                HttpContext.Session.SetString(SessionKeys.EmployeeName, profile.Name);
                HttpContext.Session.SetString(SessionKeys.EmployeePhone, profile.Phone ?? string.Empty);
                HttpContext.Session.SetString(SessionKeys.EmployeeEmail, profile.Email ?? string.Empty);
            }

            var refreshed = RequireCashier() ?? staff;
            return Ok(BuildAccountDto(refreshed));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cashier update account failed.");
            return Error("update_account_failed", ex.Message, 400);
        }
    }

    [HttpPost("change-password")]
    public async Task<ActionResult<object>> ChangePassword([FromBody] CashierChangePasswordApiRequest request, CancellationToken cancellationToken)
    {
        var staff = RequireCashier();
        if (staff is null) return Error("unauthorized", "Bạn cần đăng nhập bằng tài khoản thu ngân.", 401);
        if (string.IsNullOrWhiteSpace(request.CurrentPassword) || string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return Error("invalid_request", "Vui lòng nhập đầy đủ thông tin đổi mật khẩu.", 400);
        }
        if (!string.Equals(request.NewPassword, request.ConfirmPassword, StringComparison.Ordinal))
        {
            return Error("password_mismatch", "Xác nhận mật khẩu mới không khớp.", 400);
        }

        try
        {
            await _identityClient.StaffChangePasswordAsync(new StaffChangePasswordRequest(staff.EmployeeId, request.CurrentPassword, request.NewPassword), cancellationToken);
            return Ok(new { success = true, message = "Đổi mật khẩu thành công." });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cashier change password failed.");
            return Error("change_password_failed", ex.Message, 400);
        }
    }

    private async Task<CashierDashboardDto> BuildDashboardAsync(int branchId, StaffSessionUserDto staff, bool includeBills, DateOnly? billsDate, CancellationToken cancellationToken)
    {
        var orders = await _billingClient.GetCashierOrdersAsync(branchId, cancellationToken);
        var orderCards = orders.Select(o => new CashierOrderCardDto(
            o.OrderId,
            o.OrderCode ?? $"ORD{o.OrderId}",
            o.StatusCode,
            o.StatusName,
            o.CustomerId,
            o.CustomerName ?? string.Empty,
            o.CustomerPoints,
            o.Subtotal,
            o.ItemCount,
            o.Items.Select(i => new CashierOrderItemCardDto(i.DishName, i.Quantity, i.UnitPrice, i.LineTotal, ResolveDishImage(i.Image, i.DishName))).ToArray())).ToArray();

        var activeOrderByTableId = orders
            .Where(o => o.TableId > 0 && !string.Equals(o.StatusCode, "COMPLETED", StringComparison.OrdinalIgnoreCase))
            .GroupBy(o => o.TableId)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(x => x.OrderTime).First());

        var orderById = orderCards.ToDictionary(o => o.OrderId);
        IReadOnlyList<CashierTableDto> tableCards;

        var tables = await _catalogClient.GetBranchTablesAsync(branchId, cancellationToken);
        if (tables?.Tables is { Count: > 0 })
        {
            tableCards = tables.Tables.Select(t =>
            {
                activeOrderByTableId.TryGetValue(t.TableId, out var activeOrderRow);
                CashierOrderCardDto? order = null;
                if (activeOrderRow is not null)
                {
                    orderById.TryGetValue(activeOrderRow.OrderId, out order);
                }

                var number = t.DisplayTableNumber > 0 ? t.DisplayTableNumber : t.TableId;
                return new CashierTableDto(
                    t.TableId,
                    $"Ban {number}",
                    t.NumberOfSeats,
                    order is not null ? "OCCUPIED" : MapTableStatusCode(t.StatusName, t.IsAvailable),
                    order?.OrderId);
            }).ToArray();
        }
        else
        {
            tableCards = orders
                .GroupBy(o => o.TableId)
                .Select(g => new CashierTableDto(g.Key, g.First().TableName, 0, "OCCUPIED", g.First().OrderId))
                .OrderBy(x => x.TableId)
                .ToArray();
        }

        var today = DateOnly.FromDateTime(DateTime.Today);
        var todayReport = await _billingClient.GetBranchReportAsync(branchId, today, cancellationToken);
        var todayOrders = todayReport?.BillCount ?? orderCards.Length;
        var todayRevenue = todayReport?.TotalRevenue ?? orderCards.Sum(x => x.Items.Sum(i => i.LineTotal));

        _ = includeBills;
        _ = billsDate;
        return new CashierDashboardDto(staff, tableCards, orderCards, todayOrders, todayRevenue, BuildAccountDto(staff));
    }

    private CashierBillHistoryItemDto MapBill(CashierBillSummaryDto bill) => new(
        bill.BillId,
        bill.BillCode,
        bill.BillTime,
        bill.OrderCode ?? string.Empty,
        bill.TableName,
        bill.Subtotal,
        bill.Discount,
        bill.PointsDiscount,
        bill.PointsUsed,
        bill.TotalAmount,
        bill.PaymentMethod,
        bill.PaymentAmount,
        bill.ChangeAmount,
        bill.CustomerName ?? string.Empty);

    private CashierAccountDto BuildAccountDto(StaffSessionUserDto staff) => new(
        staff.EmployeeId,
        HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? staff.Name,
        HttpContext.Session.GetString(SessionKeys.EmployeeUsername) ?? staff.Username,
        HttpContext.Session.GetString(SessionKeys.EmployeeEmail) ?? string.Empty,
        HttpContext.Session.GetString(SessionKeys.EmployeePhone) ?? string.Empty,
        HttpContext.Session.GetString(SessionKeys.EmployeeBranchName) ?? staff.BranchName,
        HttpContext.Session.GetString(SessionKeys.EmployeeRoleName) ?? staff.RoleName);

    private static string MapTableStatusCode(string statusName, bool isAvailable)
    {
        if (isAvailable) return "AVAILABLE";
        var text = (statusName ?? string.Empty).Trim().ToLowerInvariant();
        if (text.Contains("available") || text.Contains("empty") || text.Contains("trong") || text.Contains("trống")) return "AVAILABLE";
        return "OCCUPIED";
    }

    private static string ResolveDishImage(string? rawImage, string? dishName)
    {
        var normalized = NormalizeImagePath(rawImage);
        var slug = SlugifyDishName(dishName);
        if (!string.IsNullOrWhiteSpace(normalized))
        {
            if (normalized.Contains("/images/dish_", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(slug))
            {
                return $"/images/{slug}.jpg";
            }

            return normalized;
        }

        return string.IsNullOrWhiteSpace(slug) ? "/images/placeholder-dish.svg" : $"/images/{slug}.jpg";
    }

    private static string? NormalizeImagePath(string? rawImage)
    {
        if (string.IsNullOrWhiteSpace(rawImage)) return null;
        var image = rawImage.Trim().Replace('\\', '/');
        if (image.StartsWith("~/", StringComparison.Ordinal)) image = "/" + image[2..];
        if (!image.StartsWith("/", StringComparison.Ordinal) &&
            !image.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
            !image.StartsWith("https://", StringComparison.OrdinalIgnoreCase) &&
            !image.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
        {
            image = "/" + image;
        }
        if (image.StartsWith("/Images/", StringComparison.OrdinalIgnoreCase)) image = "/images/" + image["/Images/".Length..];
        return image;
    }

    private static string? SlugifyDishName(string? dishName)
    {
        if (string.IsNullOrWhiteSpace(dishName)) return null;
        var normalized = dishName.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(normalized.Length);
        var previousDash = false;
        foreach (var ch in normalized)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category == UnicodeCategory.NonSpacingMark) continue;
            var output = ch switch
            {
                'đ' => 'd',
                'Đ' => 'd',
                _ => char.ToLowerInvariant(ch)
            };
            if (char.IsLetterOrDigit(output))
            {
                builder.Append(output);
                previousDash = false;
            }
            else if (!previousDash)
            {
                builder.Append('-');
                previousDash = true;
            }
        }
        return builder.ToString().Trim('-');
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
    private StaffSessionUserDto? RequireCashier() => RequireStaff(CashierRoles);

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
        => StatusCode(statusCode, new ApiErrorResponse(false, code, message, details));
}
