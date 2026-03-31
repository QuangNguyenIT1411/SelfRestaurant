using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class EmployeesController : Controller
{
    private readonly IdentityClient _identityClient;
    private readonly CatalogClient _catalogClient;

    public EmployeesController(IdentityClient identityClient, CatalogClient catalogClient)
    {
        _identityClient = identityClient;
        _catalogClient = catalogClient;
    }

    [HttpGet]
    public async Task<IActionResult> Index(
        [FromQuery] string? search,
        [FromQuery] int? branchId,
        [FromQuery] int? roleId,
        [FromQuery] int page = 1,
        CancellationToken cancellationToken = default)
    {
        FillCommonViewData("employees");
        page = Math.Max(1, page);

        var employees = await _identityClient.GetAdminEmployeesAsync(search, branchId, roleId, page, 10, cancellationToken);
        var branches = await _catalogClient.GetBranchesAsync(cancellationToken) ?? Array.Empty<BranchDto>();
        var roles = await _identityClient.GetEmployeeRolesAsync(cancellationToken);

        ViewBag.SearchTerm = search;
        ViewBag.Page = employees?.Page ?? page;
        ViewBag.TotalPages = employees?.TotalPages ?? 0;

        var vm = new AdminEmployeesIndexViewModel
        {
            Items = employees?.Items ?? Array.Empty<AdminEmployeeDto>(),
            Branches = branches,
            Roles = roles,
            Search = search,
            BranchId = branchId,
            RoleId = roleId,
            Page = employees?.Page ?? page,
            TotalPages = employees?.TotalPages ?? 0,
            TotalItems = employees?.TotalItems ?? 0,
        };

        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> Create(CancellationToken cancellationToken)
    {
        FillCommonViewData("employees");
        var vm = await BuildFormAsync(null, cancellationToken);
        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AdminEmployeeFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _identityClient.CreateAdminEmployeeAsync(
                new AdminUpsertEmployeeRequest(
                    model.Name,
                    model.Username,
                    model.Password,
                    model.Phone,
                    model.Email,
                    model.Salary,
                    model.Shift,
                    model.IsActive,
                    model.BranchId,
                    model.RoleId),
                cancellationToken);

            TempData["Success"] = "Đã thêm nhân viên mới.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("employees");
            var vm = await BuildFormAsync(model, cancellationToken);
            return View(vm);
        }
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken cancellationToken)
    {
        FillCommonViewData("employees");
        var employee = await _identityClient.GetAdminEmployeeByIdAsync(id, cancellationToken);
        if (employee is null)
        {
            TempData["Error"] = "Không tìm thấy nhân viên.";
            TempData["ErrorMessage"] = TempData["Error"];
            return RedirectToAction(nameof(Index));
        }

        var vm = await BuildFormAsync(new AdminEmployeeFormViewModel
        {
            EmployeeId = employee.EmployeeId,
            Name = employee.Name,
            Username = employee.Username,
            Phone = employee.Phone,
            Email = employee.Email,
            Salary = employee.Salary,
            Shift = employee.Shift,
            IsActive = employee.IsActive,
            BranchId = employee.BranchId,
            RoleId = employee.RoleId,
        }, cancellationToken);

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, AdminEmployeeFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _identityClient.UpdateAdminEmployeeAsync(
                id,
                new AdminUpsertEmployeeRequest(
                    model.Name,
                    model.Username,
                    model.Password,
                    model.Phone,
                    model.Email,
                    model.Salary,
                    model.Shift,
                    model.IsActive,
                    model.BranchId,
                    model.RoleId),
                cancellationToken);

            TempData["Success"] = "Đã cập nhật nhân viên.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("employees");
            var vm = await BuildFormAsync(model, cancellationToken);
            return View(vm);
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _identityClient.DeactivateAdminEmployeeAsync(id, cancellationToken);
            TempData["Success"] = "Đã vô hiệu hóa nhân viên.";
            TempData["SuccessMessage"] = TempData["Success"];
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> History(int id, [FromQuery] int days = 90, CancellationToken cancellationToken = default)
    {
        try
        {
            var data = await _identityClient.GetAdminEmployeeHistoryAsync(id, days, take: 200, cancellationToken);
            if (data is null)
            {
                TempData["Error"] = "Không tải được lịch sử làm việc.";
                TempData["ErrorMessage"] = TempData["Error"];
                return RedirectToAction(nameof(Index));
            }

            FillCommonViewData("employees");
            return View(new AdminEmployeeHistoryViewModel
            {
                Employee = data.Employee,
                ChefHistory = data.ChefHistory ?? Array.Empty<AdminChefHistoryItemDto>(),
                CashierHistory = data.CashierHistory ?? Array.Empty<AdminCashierHistoryItemDto>()
            });
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            return RedirectToAction(nameof(Index));
        }
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> Delete(int id, CancellationToken cancellationToken) =>
        Deactivate(id, cancellationToken);

    private void FillCommonViewData(string activeNav)
    {
        ViewBag.ActiveNav = activeNav;
        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);
        ViewBag.SuccessMessage = TempData["Success"] ?? TempData["SuccessMessage"];
        ViewBag.ErrorMessage = TempData["Error"] ?? TempData["ErrorMessage"];
    }

    private async Task<AdminEmployeeFormViewModel> BuildFormAsync(AdminEmployeeFormViewModel? seed, CancellationToken cancellationToken)
    {
        var branches = await _catalogClient.GetBranchesAsync(cancellationToken) ?? Array.Empty<BranchDto>();
        var roles = await _identityClient.GetEmployeeRolesAsync(cancellationToken);

        if (seed is null)
        {
            return new AdminEmployeeFormViewModel
            {
                IsActive = true,
                BranchId = branches.FirstOrDefault()?.BranchId ?? 0,
                RoleId = roles.FirstOrDefault()?.RoleId ?? 0,
                Branches = branches,
                Roles = roles,
            };
        }

        return new AdminEmployeeFormViewModel
        {
            EmployeeId = seed.EmployeeId,
            Name = seed.Name,
            Username = seed.Username,
            Password = seed.Password,
            Phone = seed.Phone,
            Email = seed.Email,
            Salary = seed.Salary,
            Shift = seed.Shift,
            IsActive = seed.IsActive,
            BranchId = seed.BranchId,
            RoleId = seed.RoleId,
            Branches = branches,
            Roles = roles,
        };
    }
}
