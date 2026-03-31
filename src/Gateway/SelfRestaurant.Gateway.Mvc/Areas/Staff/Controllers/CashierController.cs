using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Controllers;

[Area("Staff")]
[StaffAuthorize(AllowedRoles = new[] { "CASHIER", "MANAGER", "ADMIN" })]
public sealed class CashierController : Controller
{
    private readonly BillingClient _billingClient;
    private readonly IdentityClient _identityClient;
    private readonly CatalogClient _catalogClient;

    public CashierController(BillingClient billingClient, IdentityClient identityClient, CatalogClient catalogClient)
    {
        _billingClient = billingClient;
        _identityClient = identityClient;
        _catalogClient = catalogClient;
    }

    private bool IsAjaxRequest() =>
        string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (branchId is null || branchId <= 0)
        {
            TempData["Error"] = "Không tìm thấy chi nhánh của nhân viên.";
            return View(new CashierDashboardViewModel());
        }

        var vm = await BuildDashboardAsync(
            branchId.Value,
            employeeId,
            includeBills: false,
            billsDate: null,
            cancellationToken);

        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);

        ViewBag.CashierTablesJson = JsonSerializer.Serialize(vm.Tables);
        var ordersDict = vm.Orders.ToDictionary(
            o => o.OrderID,
            o => new
            {
                orderID = o.OrderID,
                tableID = vm.Tables.FirstOrDefault(t => t.OrderID == o.OrderID)?.TableID,
                orderCode = o.OrderCode,
                statusCode = o.StatusCode,
                customerID = o.CustomerID,
                customerName = o.CustomerName,
                customerCreditPoints = o.CustomerCreditPoints,
                items = o.Items.Select(i => new
                {
                    name = i.DishName,
                    quantity = i.Quantity,
                    unitPrice = i.UnitPrice,
                    lineTotal = i.LineTotal,
                    image = i.Image
                }).ToList()
            });
        ViewBag.CashierOrdersJson = JsonSerializer.Serialize(ordersDict);
        ViewBag.TodayOrders = vm.TodayOrders;
        ViewBag.TodayRevenue = vm.TodayRevenue;

        return View(vm);
    }

    [HttpPost]
    public async Task<IActionResult> Checkout(
        int orderId,
        decimal discount,
        int pointsUsed,
        string paymentMethod,
        decimal paymentAmount,
        CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        try
        {
            var response = await _billingClient.CheckoutAsync(
                orderId,
                new CashierCheckoutRequest(
                    EmployeeId: employeeId.Value,
                    Discount: discount,
                    PointsUsed: pointsUsed,
                    PaymentMethod: paymentMethod,
                    PaymentAmount: paymentAmount),
                cancellationToken);

            var billCode = response?.BillCode ?? "(không rõ mã)";
            var changeText = response is null ? "" : $" Tiền thừa: {response.ChangeAmount:n0}.";
            TempData["Success"] = $"Thanh toán thành công. Mã bill: {billCode}.{changeText}";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    public async Task<IActionResult> ProcessPayment([FromBody] LegacyPaymentRequest? model, CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            return Json(new { success = false, message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." });
        }

        if (model is null || model.OrderID <= 0)
        {
            return Json(new { success = false, message = "Đơn hàng không hợp lệ." });
        }

        try
        {
            var response = await _billingClient.CheckoutAsync(
                model.OrderID,
                new CashierCheckoutRequest(
                    EmployeeId: employeeId.Value,
                    Discount: Math.Max(0, model.Discount),
                    PointsUsed: Math.Max(0, model.PointsUsed),
                    PaymentMethod: string.IsNullOrWhiteSpace(model.PaymentMethod) ? "CASH" : model.PaymentMethod.Trim().ToUpperInvariant(),
                    PaymentAmount: Math.Max(0, model.PaymentAmount)),
                cancellationToken);

            if (response is null)
            {
                return Json(new { success = false, message = "Không nhận được phản hồi thanh toán." });
            }

            return Json(new
            {
                success = true,
                billCode = response.BillCode,
                totalAmount = response.TotalAmount,
                changeAmount = response.ChangeAmount,
                pointsUsed = response.PointsUsed,
                pointsEarned = response.PointsEarned,
                customerPoints = response.CustomerPoints,
                customerName = response.CustomerName,
                pointsBefore = response.PointsBefore,
                message = $"Thanh toán thành công. Mã bill: {response.BillCode}"
            });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpGet]
    public async Task<IActionResult> History(CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (employeeId is null || branchId is null || employeeId <= 0 || branchId <= 0)
        {
            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        var vm = await BuildDashboardAsync(
            branchId.Value,
            employeeId,
            includeBills: true,
            billsDate: null,
            cancellationToken);

        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> Report([FromQuery] DateOnly? date, CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (employeeId is null || branchId is null || employeeId <= 0 || branchId <= 0)
        {
            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        var targetDate = date ?? DateOnly.FromDateTime(DateTime.Today);
        var vm = await BuildDashboardAsync(
            branchId.Value,
            employeeId,
            includeBills: true,
            billsDate: targetDate,
            cancellationToken);

        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? "";
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName) ?? "";

        return View(vm);
    }

    [HttpPost]
    public async Task<IActionResult> UpdateAccount(
        [FromForm] string name,
        [FromForm] string email,
        [FromForm] string phone,
        CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." });
            }

            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        try
        {
            var profile = await _identityClient.UpdateStaffProfileAsync(
                employeeId.Value,
                new StaffUpdateProfileRequest(name, phone, email),
                cancellationToken);

            if (profile is not null)
            {
                HttpContext.Session.SetString(SessionKeys.EmployeeName, profile.Name);
                HttpContext.Session.SetString(SessionKeys.EmployeePhone, profile.Phone ?? "");
                HttpContext.Session.SetString(SessionKeys.EmployeeEmail, profile.Email ?? "");
            }

            TempData["Success"] = "Cập nhật tài khoản thành công.";
            if (IsAjaxRequest())
            {
                return Json(new { success = true, message = "Cập nhật tài khoản thành công." });
            }
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        return RedirectToAction(nameof(History));
    }

    [HttpPost]
    public async Task<IActionResult> ChangePassword(
        [FromForm] string currentPassword,
        [FromForm] string newPassword,
        [FromForm] string confirmPassword,
        CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." });
            }

            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        if (!string.Equals(newPassword, confirmPassword, StringComparison.Ordinal))
        {
            TempData["Error"] = "Mật khẩu mới và xác nhận không khớp.";
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Mật khẩu mới và xác nhận không khớp." });
            }

            return RedirectToAction(nameof(History));
        }

        try
        {
            await _identityClient.StaffChangePasswordAsync(
                new StaffChangePasswordRequest(employeeId.Value, currentPassword, newPassword),
                cancellationToken);

            TempData["Success"] = "Đổi mật khẩu thành công.";
            if (IsAjaxRequest())
            {
                return Json(new { success = true, message = "Đổi mật khẩu thành công." });
            }
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        return RedirectToAction(nameof(History));
    }

    private async Task<CashierDashboardViewModel> BuildDashboardAsync(
        int branchId,
        int? employeeId,
        bool includeBills,
        DateOnly? billsDate,
        CancellationToken cancellationToken)
    {
        var vm = new CashierDashboardViewModel();

        var orders = await _billingClient.GetCashierOrdersAsync(branchId, cancellationToken);
        vm.Orders = orders.Select(o => new CashierOrderViewModel
        {
            OrderID = o.OrderId,
            OrderCode = o.OrderCode ?? $"ORD{o.OrderId}",
            StatusCode = o.StatusCode,
            StatusName = o.StatusName,
            CustomerID = o.CustomerId,
            CustomerName = o.CustomerName ?? string.Empty,
            CustomerCreditPoints = o.CustomerPoints,
            Items = o.Items.Select(i => new CashierOrderItemViewModel
            {
                DishName = i.DishName,
                Quantity = i.Quantity,
                UnitPrice = i.UnitPrice,
                LineTotal = i.LineTotal,
                Image = ResolveDishImage(i.Image, i.DishName)
            }).ToList()
        }).ToList();

        var activeOrderByTableId = orders
            .Where(o => o.TableId > 0 && !string.Equals(o.StatusCode, "COMPLETED", StringComparison.OrdinalIgnoreCase))
            .GroupBy(o => o.TableId)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(x => x.OrderTime).First());

        var vmOrderById = vm.Orders.ToDictionary(o => o.OrderID);

        var tables = await _catalogClient.GetBranchTablesAsync(branchId, cancellationToken);
        if (tables?.Tables is { Count: > 0 })
        {
            vm.Tables = tables.Tables.Select(t =>
            {
                activeOrderByTableId.TryGetValue(t.TableId, out var activeOrderRow);

                CashierOrderViewModel? order = null;
                if (activeOrderRow is not null)
                {
                    vmOrderById.TryGetValue(activeOrderRow.OrderId, out order);
                }

                var number = t.DisplayTableNumber > 0 ? t.DisplayTableNumber : t.TableId;

                return new CashierTableViewModel
                {
                    TableID = t.TableId,
                    Number = $"Bàn {number}",
                    Seats = t.NumberOfSeats,
                    Status = order is not null ? "OCCUPIED" : MapTableStatusCode(t.StatusName, t.IsAvailable),
                    OrderID = order?.OrderID
                };
            }).ToList();
        }
        else
        {
            vm.Tables = orders
                .GroupBy(o => o.TableId)
                .Select(g => new CashierTableViewModel
                {
                    TableID = g.Key,
                    Number = g.First().TableName,
                    Seats = 0,
                    Status = "OCCUPIED",
                    OrderID = g.First().OrderId
                })
                .OrderBy(x => x.TableID)
                .ToList();
        }

        var today = DateOnly.FromDateTime(DateTime.Today);
        var todayReport = await _billingClient.GetBranchReportAsync(branchId, today, cancellationToken);
        if (todayReport is not null)
        {
            vm.TodayOrders = todayReport.BillCount;
            vm.TodayRevenue = todayReport.TotalRevenue;
        }
        else
        {
            vm.TodayOrders = vm.Orders.Count;
            vm.TodayRevenue = vm.Orders.Sum(x => x.Items.Sum(i => i.LineTotal));
        }

        if (includeBills && employeeId is > 0)
        {
            var bills = await _billingClient.GetBillsAsync(employeeId.Value, branchId, billsDate, 100, cancellationToken);
            vm.Bills = bills.Select(b => new CashierBillHistoryViewModel
            {
                BillID = b.BillId,
                BillCode = b.BillCode,
                BillTime = b.BillTime,
                OrderCode = b.OrderCode ?? "",
                TableName = b.TableName,
                CustomerName = b.CustomerName ?? "",
                Subtotal = b.Subtotal,
                Discount = b.Discount,
                PointsDiscount = b.PointsDiscount,
                PointsUsed = b.PointsUsed,
                TotalAmount = b.TotalAmount,
                PaymentMethod = b.PaymentMethod,
                PaymentAmount = b.PaymentAmount,
                ChangeAmount = b.ChangeAmount
            }).ToList();
        }

        vm.Account = new CashierAccountViewModel
        {
            EmployeeID = employeeId ?? 0,
            Name = HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? "",
            Username = HttpContext.Session.GetString(SessionKeys.EmployeeUsername) ?? "",
            Email = HttpContext.Session.GetString(SessionKeys.EmployeeEmail) ?? "",
            Phone = HttpContext.Session.GetString(SessionKeys.EmployeePhone) ?? "",
            BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName) ?? "",
            RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName) ?? ""
        };

        return vm;
    }

    private static string MapTableStatusCode(string statusName, bool isAvailable)
    {
        if (isAvailable)
        {
            return "AVAILABLE";
        }

        var text = (statusName ?? "").Trim().ToLowerInvariant();
        if (text.Contains("available") || text.Contains("empty") || text.Contains("trống") || text.Contains("trong"))
        {
            return "AVAILABLE";
        }

        return "OCCUPIED";
    }

    private static string ResolveDishImage(string? rawImage, string? dishName)
    {
        var normalized = NormalizeImagePath(rawImage);
        var slug = SlugifyDishName(dishName);

        if (!string.IsNullOrWhiteSpace(normalized))
        {
            if (normalized.Contains("/images/dish_", StringComparison.OrdinalIgnoreCase) &&
                !string.IsNullOrWhiteSpace(slug))
            {
                return $"/images/{slug}.jpg";
            }

            return normalized;
        }

        return string.IsNullOrWhiteSpace(slug)
            ? "/images/placeholder-dish.svg"
            : $"/images/{slug}.jpg";
    }

    private static string? NormalizeImagePath(string? rawImage)
    {
        if (string.IsNullOrWhiteSpace(rawImage))
        {
            return null;
        }

        var image = rawImage.Trim().Replace('\\', '/');
        if (image.StartsWith("~/", StringComparison.Ordinal))
        {
            image = "/" + image[2..];
        }

        if (!image.StartsWith("/", StringComparison.Ordinal) &&
            !image.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
            !image.StartsWith("https://", StringComparison.OrdinalIgnoreCase) &&
            !image.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
        {
            image = "/" + image;
        }

        if (image.StartsWith("/Images/", StringComparison.OrdinalIgnoreCase))
        {
            image = "/images/" + image["/Images/".Length..];
        }

        return image;
    }

    private static string? SlugifyDishName(string? dishName)
    {
        if (string.IsNullOrWhiteSpace(dishName))
        {
            return null;
        }

        var normalized = dishName.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(normalized.Length);
        var previousDash = false;

        foreach (var ch in normalized)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            var mapped = ch is 'đ' or 'Đ' ? 'd' : ch;
            if (char.IsLetterOrDigit(mapped))
            {
                builder.Append(char.ToLowerInvariant(mapped));
                previousDash = false;
            }
            else if (!previousDash)
            {
                builder.Append('-');
                previousDash = true;
            }
        }

        var slug = builder.ToString().Trim('-');
        return slug.Length == 0 ? null : slug;
    }

    public sealed record LegacyPaymentRequest(
        int OrderID,
        decimal Discount,
        int PointsUsed,
        string PaymentMethod,
        decimal PaymentAmount);
}
