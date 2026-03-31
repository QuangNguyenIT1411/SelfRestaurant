using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class CategoriesController : Controller
{
    private readonly CatalogClient _catalogClient;

    public CategoriesController(CatalogClient catalogClient)
    {
        _catalogClient = catalogClient;
    }

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        ViewBag.ActiveNav = "categories";
        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);
        ViewBag.SuccessMessage = TempData["Success"] ?? TempData["SuccessMessage"];
        ViewBag.ErrorMessage = TempData["Error"] ?? TempData["ErrorMessage"];

        var categories = await _catalogClient.GetCategoriesAsync(includeInactive: false, cancellationToken);
        var units = await BuildUnitSummaryAsync(cancellationToken);

        var vm = new CategoryManagementViewModel
        {
            Units = units,
            Categories = categories?
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.CategoryId)
                .Select(c => new CategoryItemViewModel
                {
                    CategoryID = c.CategoryId,
                    Name = c.Name,
                    Description = c.Description,
                    DisplayOrder = c.DisplayOrder,
                    IsActive = c.IsActive
                })
                .ToList() ?? new List<CategoryItemViewModel>()
        };

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(
        [FromForm] string name,
        [FromForm] string? description,
        [FromForm] int? displayOrder,
        CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.CreateCategoryAsync(
                new CreateCategoryRequest(name, description, displayOrder ?? 0),
                cancellationToken);
            TempData["Success"] = "Đã tạo danh mục mới.";
            TempData["SuccessMessage"] = TempData["Success"];
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(
        [FromForm] int? id,
        [FromForm] int? categoryId,
        [FromForm] string name,
        [FromForm] string? description,
        [FromForm] int? displayOrder,
        [FromForm] bool? isActive,
        CancellationToken cancellationToken)
    {
        var resolvedCategoryId = categoryId ?? id ?? 0;
        if (resolvedCategoryId <= 0)
        {
            TempData["Error"] = "Danh mục không hợp lệ.";
            return RedirectToAction(nameof(Index));
        }

        try
        {
            await _catalogClient.UpdateCategoryAsync(
                resolvedCategoryId,
                new UpdateCategoryRequest(name, description, displayOrder ?? 0, isActive ?? false),
                cancellationToken);
            TempData["Success"] = "Đã cập nhật danh mục.";
            TempData["SuccessMessage"] = TempData["Success"];
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Delete([FromForm] int? id, [FromForm] int? categoryId, CancellationToken cancellationToken)
    {
        var resolvedCategoryId = categoryId ?? id ?? 0;
        if (resolvedCategoryId <= 0)
        {
            TempData["Error"] = "Danh mục không hợp lệ.";
            return RedirectToAction(nameof(Index));
        }

        try
        {
            await _catalogClient.DeleteCategoryAsync(resolvedCategoryId, cancellationToken);
            TempData["Success"] = "Đã xóa danh mục.";
            TempData["SuccessMessage"] = TempData["Success"];
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
        }

        return RedirectToAction(nameof(Index));
    }

    private async Task<List<UnitSummaryViewModel>> BuildUnitSummaryAsync(CancellationToken cancellationToken)
    {
        var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var page = 1;

        while (true)
        {
            var dishes = await _catalogClient.GetAdminDishesAsync(null, null, page, 100, includeInactive: false, cancellationToken);
            if (dishes is null || dishes.Items.Count == 0)
            {
                break;
            }

            foreach (var dish in dishes.Items)
            {
                var unit = (dish.Unit ?? "").Trim();
                if (string.IsNullOrWhiteSpace(unit))
                {
                    continue;
                }

                counts[unit] = counts.TryGetValue(unit, out var current) ? current + 1 : 1;
            }

            if (page >= dishes.TotalPages)
            {
                break;
            }

            page++;
        }

        return counts
            .OrderBy(x => x.Key)
            .Select(x => new UnitSummaryViewModel { Unit = x.Key, DishCount = x.Value })
            .ToList();
    }

    [HttpPost]
    public async Task<IActionResult> RenameUnit(string oldUnit, string newUnit, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(oldUnit) || string.IsNullOrWhiteSpace(newUnit))
        {
            TempData["Error"] = "Đơn vị cũ/mới không hợp lệ.";
            TempData["ErrorMessage"] = TempData["Error"];
            return RedirectToAction(nameof(Index));
        }

        oldUnit = oldUnit.Trim();
        newUnit = newUnit.Trim();

        if (string.Equals(oldUnit, newUnit, StringComparison.OrdinalIgnoreCase))
        {
            TempData["Error"] = "Đơn vị mới phải khác đơn vị cũ.";
            TempData["ErrorMessage"] = TempData["Error"];
            return RedirectToAction(nameof(Index));
        }

        var changedDishes = 0;
        var changedIngredients = 0;

        try
        {
            var page = 1;
            while (true)
            {
                var dishes = await _catalogClient.GetAdminDishesAsync(null, null, page, 100, includeInactive: false, cancellationToken);
                if (dishes is null || dishes.Items.Count == 0)
                {
                    break;
                }

                foreach (var dish in dishes.Items.Where(x => string.Equals((x.Unit ?? "").Trim(), oldUnit, StringComparison.OrdinalIgnoreCase)))
                {
                    await _catalogClient.UpdateAdminDishAsync(
                        dish.DishId,
                        new AdminUpsertDishRequest(
                            dish.Name,
                            dish.Price,
                            dish.CategoryId,
                            dish.Description,
                            newUnit,
                            dish.Image,
                            dish.IsVegetarian,
                            dish.IsDailySpecial,
                            dish.Available,
                            dish.IsActive),
                        cancellationToken);
                    changedDishes++;
                }

                if (page >= dishes.TotalPages)
                {
                    break;
                }
                page++;
            }

            page = 1;
            while (true)
            {
                var ingredients = await _catalogClient.GetAdminIngredientsAsync(null, page, 100, cancellationToken);
                if (ingredients is null || ingredients.Items.Count == 0)
                {
                    break;
                }

                foreach (var ingredient in ingredients.Items.Where(x => string.Equals((x.Unit ?? "").Trim(), oldUnit, StringComparison.OrdinalIgnoreCase)))
                {
                    await _catalogClient.UpdateAdminIngredientAsync(
                        ingredient.IngredientId,
                        new AdminUpsertIngredientRequest(
                            ingredient.Name,
                            newUnit,
                            ingredient.CurrentStock,
                            ingredient.ReorderLevel,
                            ingredient.IsActive),
                        cancellationToken);
                    changedIngredients++;
                }

                if (page >= ingredients.TotalPages)
                {
                    break;
                }
                page++;
            }

            TempData["Success"] = $"Đã đổi đơn vị từ '{oldUnit}' sang '{newUnit}' cho {changedDishes} món và {changedIngredients} nguyên liệu.";
            TempData["SuccessMessage"] = TempData["Success"];
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
        }

        return RedirectToAction(nameof(Index));
    }
}
