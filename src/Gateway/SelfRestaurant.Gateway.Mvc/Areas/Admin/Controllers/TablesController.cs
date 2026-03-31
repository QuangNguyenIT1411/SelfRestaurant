using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class TablesController : Controller
{
    private readonly CatalogClient _catalogClient;

    public TablesController(CatalogClient catalogClient)
    {
        _catalogClient = catalogClient;
    }

    [HttpGet]
    public async Task<IActionResult> Index(
        [FromQuery] int? branchId,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        CancellationToken cancellationToken = default)
    {
        FillCommonViewData("tablesqr");
        page = Math.Max(1, page);
        var data = await _catalogClient.GetAdminTablesAsync(branchId, search, page, 10, cancellationToken);
        var branches = await _catalogClient.GetBranchesAsync(cancellationToken) ?? Array.Empty<BranchDto>();

        ViewBag.Search = search;
        ViewBag.BranchId = branchId;
        ViewBag.Page = data?.Page ?? page;
        ViewBag.TotalPages = data?.TotalPages ?? 0;

        return View(new AdminTablesIndexViewModel
        {
            Items = data?.Items ?? Array.Empty<AdminTableDto>(),
            Branches = branches,
            Search = search,
            BranchId = branchId,
            Page = data?.Page ?? page,
            TotalPages = data?.TotalPages ?? 0,
            TotalItems = data?.TotalItems ?? 0
        });
    }

    [HttpGet]
    public async Task<IActionResult> Create(CancellationToken cancellationToken)
    {
        FillCommonViewData("tablesqr");
        var vm = await BuildFormAsync(null, cancellationToken);
        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AdminTableFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.CreateAdminTableAsync(
                new AdminUpsertTableRequest(
                    model.BranchId,
                    model.NumberOfSeats,
                    model.QRCode,
                    model.StatusId,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã thêm bàn.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("tablesqr");
            var vm = await BuildFormAsync(model, cancellationToken);
            return View(vm);
        }
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken cancellationToken)
    {
        FillCommonViewData("tablesqr");
        var table = await _catalogClient.GetAdminTableByIdAsync(id, cancellationToken);
        if (table is null)
        {
            TempData["Error"] = "Không tìm thấy bàn.";
            TempData["ErrorMessage"] = TempData["Error"];
            return RedirectToAction(nameof(Index));
        }

        var vm = await BuildFormAsync(new AdminTableFormViewModel
        {
            TableId = table.TableId,
            BranchId = table.BranchId,
            NumberOfSeats = table.NumberOfSeats,
            QRCode = table.QRCode,
            StatusId = table.StatusId,
            IsActive = table.IsActive
        }, cancellationToken);

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, AdminTableFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.UpdateAdminTableAsync(
                id,
                new AdminUpsertTableRequest(
                    model.BranchId,
                    model.NumberOfSeats,
                    model.QRCode,
                    model.StatusId,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã cập nhật bàn.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("tablesqr");
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
            await _catalogClient.DeactivateAdminTableAsync(id, cancellationToken);
            TempData["Success"] = "Đã vô hiệu hóa bàn.";
            TempData["SuccessMessage"] = TempData["Success"];
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> Delete(int id, CancellationToken cancellationToken) =>
        Deactivate(id, cancellationToken);

    private async Task<AdminTableFormViewModel> BuildFormAsync(AdminTableFormViewModel? seed, CancellationToken cancellationToken)
    {
        var branches = await _catalogClient.GetBranchesAsync(cancellationToken) ?? Array.Empty<BranchDto>();
        var statuses = await _catalogClient.GetTableStatusesAsync(cancellationToken);

        if (seed is null)
        {
            return new AdminTableFormViewModel
            {
                BranchId = branches.FirstOrDefault()?.BranchId ?? 0,
                StatusId = statuses.FirstOrDefault()?.StatusId ?? 1,
                NumberOfSeats = 4,
                IsActive = true,
                Branches = branches,
                Statuses = statuses
            };
        }

        return new AdminTableFormViewModel
        {
            TableId = seed.TableId,
            BranchId = seed.BranchId,
            NumberOfSeats = seed.NumberOfSeats,
            QRCode = seed.QRCode,
            StatusId = seed.StatusId,
            IsActive = seed.IsActive,
            Branches = branches,
            Statuses = statuses
        };
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

