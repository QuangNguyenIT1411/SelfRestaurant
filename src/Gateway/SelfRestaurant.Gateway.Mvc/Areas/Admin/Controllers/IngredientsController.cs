using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class IngredientsController : Controller
{
    private readonly CatalogClient _catalogClient;

    public IngredientsController(CatalogClient catalogClient)
    {
        _catalogClient = catalogClient;
    }

    [HttpGet]
    public async Task<IActionResult> Index(
        [FromQuery] string? search,
        [FromQuery] bool? onlyActive,
        [FromQuery] int page = 1,
        CancellationToken cancellationToken = default)
    {
        FillCommonViewData("ingredients");
        page = Math.Max(1, page);
        onlyActive ??= true;

        if (onlyActive == true)
        {
            var filteredItems = new List<AdminIngredientDto>();
            var fetchPage = 1;

            while (true)
            {
                var batch = await _catalogClient.GetAdminIngredientsAsync(search, fetchPage, 100, cancellationToken);
                if (batch is null || batch.Items.Count == 0)
                {
                    break;
                }

                filteredItems.AddRange(batch.Items.Where(x => x.IsActive));

                if (fetchPage >= batch.TotalPages)
                {
                    break;
                }

                fetchPage++;
            }

            var totalItems = filteredItems.Count;
            var totalPages = totalItems == 0 ? 0 : (int)Math.Ceiling(totalItems / 10d);
            if (totalPages > 0)
            {
                page = Math.Min(page, totalPages);
            }

            ViewBag.Search = search;
            ViewBag.OnlyActive = onlyActive;
            ViewBag.Page = page;
            ViewBag.TotalPages = totalPages;

            return View(new AdminIngredientsIndexViewModel
            {
                Items = filteredItems
                    .Skip((page - 1) * 10)
                    .Take(10)
                    .ToArray(),
                Search = search,
                OnlyActive = onlyActive,
                Page = page,
                TotalPages = totalPages,
                TotalItems = totalItems
            });
        }

        var data = await _catalogClient.GetAdminIngredientsAsync(search, page, 10, cancellationToken);

        ViewBag.Search = search;
        ViewBag.OnlyActive = onlyActive;
        ViewBag.Page = data?.Page ?? page;
        ViewBag.TotalPages = data?.TotalPages ?? 0;

        return View(new AdminIngredientsIndexViewModel
        {
            Items = data?.Items ?? Array.Empty<AdminIngredientDto>(),
            Search = search,
            OnlyActive = onlyActive,
            Page = data?.Page ?? page,
            TotalPages = data?.TotalPages ?? 0,
            TotalItems = data?.TotalItems ?? 0
        });
    }

    [HttpGet]
    public IActionResult Create()
    {
        FillCommonViewData("ingredients");
        return View(new AdminIngredientFormViewModel { IsActive = true });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AdminIngredientFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.CreateAdminIngredientAsync(
                new AdminUpsertIngredientRequest(
                    model.Name,
                    model.Unit,
                    model.CurrentStock,
                    model.ReorderLevel,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã thêm nguyên liệu.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("ingredients");
            return View(model);
        }
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken cancellationToken)
    {
        FillCommonViewData("ingredients");
        var item = await _catalogClient.GetAdminIngredientByIdAsync(id, cancellationToken);
        if (item is null)
        {
            TempData["Error"] = "Không tìm thấy nguyên liệu.";
            TempData["ErrorMessage"] = TempData["Error"];
            return RedirectToAction(nameof(Index));
        }

        return View(new AdminIngredientFormViewModel
        {
            IngredientId = item.IngredientId,
            Name = item.Name,
            Unit = item.Unit,
            CurrentStock = item.CurrentStock,
            ReorderLevel = item.ReorderLevel,
            IsActive = item.IsActive
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, AdminIngredientFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.UpdateAdminIngredientAsync(
                id,
                new AdminUpsertIngredientRequest(
                    model.Name,
                    model.Unit,
                    model.CurrentStock,
                    model.ReorderLevel,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã cập nhật nguyên liệu.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("ingredients");
            return View(model);
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.DeactivateAdminIngredientAsync(id, cancellationToken);
            TempData["Success"] = "Đã vô hiệu hóa nguyên liệu.";
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

