using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class ReportsController : Controller
{
    private readonly OrdersClient _ordersClient;

    public ReportsController(OrdersClient ordersClient)
    {
        _ordersClient = ordersClient;
    }

    [HttpGet]
    public async Task<IActionResult> Revenue([FromQuery] int days = 30, CancellationToken cancellationToken = default)
    {
        FillCommonViewData("reports-revenue");

        var report = await _ordersClient.GetAdminRevenueReportAsync(days, cancellationToken);
        return View(new AdminRevenueReportViewModel
        {
            Days = Math.Clamp(days, 1, 365),
            TotalRevenue = report?.TotalRevenue ?? 0,
            Rows = report?.RevenueByBranchDate ?? Array.Empty<AdminRevenueReportRowDto>()
        });
    }

    [HttpGet]
    public async Task<IActionResult> TopDishes(
        [FromQuery] int days = 30,
        [FromQuery] int take = 10,
        CancellationToken cancellationToken = default)
    {
        FillCommonViewData("reports-topdishes");

        var report = await _ordersClient.GetAdminTopDishesReportAsync(days, take, cancellationToken);
        return View(new AdminTopDishesReportViewModel
        {
            Days = Math.Clamp(days, 1, 365),
            Take = Math.Clamp(take, 1, 50),
            Items = report?.Items ?? Array.Empty<AdminTopDishReportItemDto>()
        });
    }

    private void FillCommonViewData(string activeNav)
    {
        ViewBag.ActiveNav = activeNav;
        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);
        ViewBag.SuccessMessage = TempData["Success"] ?? TempData["SuccessMessage"];
        ViewBag.ErrorMessage = TempData["Error"] ?? TempData["ErrorMessage"];
    }
}
