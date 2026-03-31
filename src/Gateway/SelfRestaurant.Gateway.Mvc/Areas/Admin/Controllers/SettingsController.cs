using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class SettingsController : Controller
{
    private readonly IdentityClient _identityClient;

    public SettingsController(IdentityClient identityClient)
    {
        _identityClient = identityClient;
    }

    [HttpGet]
    public IActionResult Index()
    {
        FillCommonViewData();

        var model = new AdminSettingsViewModel
        {
            Name = HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? "",
            Username = HttpContext.Session.GetString(SessionKeys.EmployeeUsername) ?? "",
            Phone = HttpContext.Session.GetString(SessionKeys.EmployeePhone) ?? "",
            Email = HttpContext.Session.GetString(SessionKeys.EmployeeEmail)
        };

        return View(model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Index(AdminSettingsViewModel model, CancellationToken cancellationToken)
    {
        FillCommonViewData();

        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        if (!ModelState.IsValid)
        {
            return View(model);
        }

        if (!string.IsNullOrWhiteSpace(model.NewPassword))
        {
            if (!string.Equals(model.NewPassword, model.ConfirmPassword, StringComparison.Ordinal))
            {
                ModelState.AddModelError(nameof(model.ConfirmPassword), "Xac nhan mat khau khong khop.");
                return View(model);
            }

            if (string.IsNullOrWhiteSpace(model.CurrentPassword))
            {
                ModelState.AddModelError(nameof(model.CurrentPassword), "Vui long nhap mat khau hien tai.");
                return View(model);
            }
        }

        try
        {
            var profile = await _identityClient.UpdateStaffProfileAsync(
                employeeId.Value,
                new StaffUpdateProfileRequest(model.Name, model.Phone, model.Email),
                cancellationToken);

            if (!string.IsNullOrWhiteSpace(model.NewPassword))
            {
                await _identityClient.StaffChangePasswordAsync(
                    new StaffChangePasswordRequest(employeeId.Value, model.CurrentPassword!, model.NewPassword),
                    cancellationToken);
            }

            if (profile is not null)
            {
                HttpContext.Session.SetString(SessionKeys.EmployeeName, profile.Name);
                HttpContext.Session.SetString(SessionKeys.EmployeePhone, profile.Phone ?? "");
                HttpContext.Session.SetString(SessionKeys.EmployeeEmail, profile.Email ?? "");
                HttpContext.Session.SetString(SessionKeys.EmployeeUsername, profile.Username);
                model.Username = profile.Username;
            }

            TempData["Success"] = "Da cap nhat thong tin tai khoan.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            return View(model);
        }
    }

    private void FillCommonViewData()
    {
        ViewBag.ActiveNav = "settings";
        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);
        ViewBag.SuccessMessage = TempData["Success"] ?? TempData["SuccessMessage"];
        ViewBag.ErrorMessage = TempData["Error"] ?? TempData["ErrorMessage"];
    }
}
