using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Infrastructure;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Controllers;

[Area("Staff")]
public sealed class HomeController : Controller
{
    [HttpGet]
    public IActionResult Index()
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        var roleCode = (HttpContext.Session.GetString(SessionKeys.EmployeeRoleCode) ?? string.Empty).Trim().ToUpperInvariant();
        return roleCode switch
        {
            "ADMIN" => RedirectToAction("Index", "Dashboard", new { area = "Admin" }),
            "CASHIER" => RedirectToAction("Index", "Cashier", new { area = "Staff" }),
            "CHEF" or "KITCHEN_STAFF" => RedirectToAction("Index", "Chef", new { area = "Staff" }),
            "MANAGER" => RedirectToAction("Index", "Manager", new { area = "Staff" }),
            _ => RedirectToAction("Index", "Home", new { area = "" })
        };
    }
}
