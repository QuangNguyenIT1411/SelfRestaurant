using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Controllers;

[Area("Staff")]
[StaffAuthorize(AllowedRoles = new[] { "MANAGER", "ADMIN" })]
public sealed class ManagerController : Controller
{
    private readonly OrdersClient _ordersClient;
    private readonly BillingClient _billingClient;
    private readonly CatalogClient _catalogClient;

    public ManagerController(OrdersClient ordersClient, BillingClient billingClient, CatalogClient catalogClient)
    {
        _ordersClient = ordersClient;
        _billingClient = billingClient;
        _catalogClient = catalogClient;
    }

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            TempData["Error"] = "Không tìm thấy chi nhánh của nhân viên.";
            return View(new ManagerDashboardViewModel());
        }

        var chefOrders = await _ordersClient.GetChefOrdersAsync(branchId.Value, status: null, cancellationToken);
        var cashierOrders = await _billingClient.GetCashierOrdersAsync(branchId.Value, cancellationToken);
        var branchReport = await _billingClient.GetBranchReportAsync(branchId.Value, DateOnly.FromDateTime(DateTime.Today), cancellationToken);

        var menu = await _catalogClient.GetMenuAsync(
            branchId.Value,
            DateOnly.FromDateTime(DateTime.Today),
            cancellationToken: cancellationToken);

        var topDishIds = await _ordersClient.GetTopDishIdsAsync(branchId.Value, 5, cancellationToken) ?? Array.Empty<int>();
        var dishMap = menu?.Categories
            .SelectMany(c => c.Dishes)
            .GroupBy(d => d.DishId)
            .ToDictionary(g => g.Key, g => g.First().Name) ?? new Dictionary<int, string>();

        var topDishes = topDishIds
            .Select(id => new ManagerTopDishItem(id, dishMap.TryGetValue(id, out var name) ? name : $"Món #{id}"))
            .ToList();

        var vm = new ManagerDashboardViewModel
        {
            EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? "",
            RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName) ?? "",
            BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName) ?? "",
            BranchId = branchId.Value,
            PendingKitchenCount = chefOrders.Count(x => x.StatusCode is "PENDING" or "CONFIRMED"),
            PreparingKitchenCount = chefOrders.Count(x => x.StatusCode == "PREPARING"),
            ReadyKitchenCount = chefOrders.Count(x => x.StatusCode is "READY" or "SERVING"),
            ActiveCashierOrdersCount = cashierOrders.Count,
            TodayBillCount = branchReport?.BillCount ?? 0,
            TodayRevenue = branchReport?.TotalRevenue ?? 0,
            TopDishes = topDishes,
        };

        return View(vm);
    }
}
