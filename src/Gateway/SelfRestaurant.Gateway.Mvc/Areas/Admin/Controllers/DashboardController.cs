using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class DashboardController : Controller
{
    private readonly IdentityClient _identityClient;
    private readonly OrdersClient _ordersClient;

    public DashboardController(IdentityClient identityClient, OrdersClient ordersClient)
    {
        _identityClient = identityClient;
        _ordersClient = ordersClient;
    }

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        ViewBag.ActiveNav = "dashboard";
        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);
        ViewBag.SuccessMessage = TempData["Success"] ?? TempData["SuccessMessage"];
        ViewBag.ErrorMessage = TempData["Error"] ?? TempData["ErrorMessage"];

        var identity = await _identityClient.GetAdminStatsAsync(cancellationToken);
        var orders = await _ordersClient.GetAdminStatsAsync(date: null, cancellationToken);
        var employees = await _identityClient.GetAdminEmployeesAsync(
            search: null,
            branchId: null,
            roleId: null,
            page: 1,
            pageSize: 5,
            cancellationToken);

        var vm = new AdminDashboardViewModel
        {
            TotalEmployees = identity?.TotalEmployees ?? 0,
            ActiveEmployees = identity?.ActiveEmployees ?? 0,
            BranchCount = identity?.BranchCount ?? 0,
            TodayOrders = orders?.TodayOrders ?? 0,
            PendingOrders = orders?.PendingOrders ?? 0,
            TodayRevenue = orders?.TodayRevenue ?? 0m,
            LatestEmployees = employees?.Items.Select(e => new AdminDashboardEmployeeViewModel
            {
                EmployeeID = e.EmployeeId,
                Name = e.Name,
                Phone = e.Phone,
                Email = e.Email,
                IsActive = e.IsActive,
                EmployeeRoles = new AdminDashboardEmployeeRoleViewModel
                {
                    RoleCode = e.RoleCode,
                    RoleName = e.RoleName
                },
                Branches = new AdminDashboardBranchViewModel
                {
                    Name = e.BranchName,
                    Location = null
                }
            }).ToList() ?? new List<AdminDashboardEmployeeViewModel>()
        };

        return View(vm);
    }
}
