using System.Globalization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Rendering;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class DishesController : Controller
{
    private readonly CatalogClient _catalogClient;
    private readonly IWebHostEnvironment _environment;

    public DishesController(CatalogClient catalogClient, IWebHostEnvironment environment)
    {
        _catalogClient = catalogClient;
        _environment = environment;
    }

    [HttpGet]
    public async Task<IActionResult> Index(
        [FromQuery] string? search,
        [FromQuery] int? categoryId,
        [FromQuery] bool? onlyVegetarian,
        [FromQuery] int page = 1,
        CancellationToken cancellationToken = default)
    {
        FillCommonViewData("dishes");
        page = Math.Max(1, page);
        var dishes = await _catalogClient.GetAdminDishesAsync(search, categoryId, page, 10, includeInactive: false, cancellationToken);
        var categories = await _catalogClient.GetCategoriesAsync(includeInactive: false, cancellationToken) ?? Array.Empty<CategoryDto>();
        var items = dishes?.Items ?? Array.Empty<AdminDishDto>();
        if (onlyVegetarian == true)
        {
            items = items.Where(x => x.IsVegetarian).ToArray();
        }

        ViewBag.Search = search;
        ViewBag.CategoryId = categoryId;
        ViewBag.OnlyVegetarian = onlyVegetarian;
        ViewBag.Page = dishes?.Page ?? page;
        ViewBag.TotalPages = dishes?.TotalPages ?? 0;
        ViewBag.Categories = new SelectList(categories, "CategoryId", "Name", categoryId);

        return View(new AdminDishesIndexViewModel
        {
            Items = items,
            Categories = categories,
            Search = search,
            CategoryId = categoryId,
            Page = dishes?.Page ?? page,
            TotalPages = dishes?.TotalPages ?? 0,
            TotalItems = dishes?.TotalItems ?? 0
        });
    }

    [HttpGet]
    public async Task<IActionResult> Create(CancellationToken cancellationToken)
    {
        FillCommonViewData("dishes");
        var vm = await BuildFormAsync(null, cancellationToken);
        ViewBag.Categories = new SelectList(vm.Categories, "CategoryId", "Name", vm.CategoryId);
        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AdminDishFormViewModel model, IFormFile? imageFile, CancellationToken cancellationToken)
    {
        try
        {
            model = NormalizeDishFormAliases(model);
            model = await WithResolvedImageAsync(model, imageFile, cancellationToken);
            await _catalogClient.CreateAdminDishAsync(
                new AdminUpsertDishRequest(
                    model.Name,
                    model.Price,
                    model.CategoryId,
                    model.Description,
                    model.Unit,
                    model.Image,
                    model.IsVegetarian,
                    model.IsDailySpecial,
                    model.Available,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã thêm món.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            FillCommonViewData("dishes");
            var vm = await BuildFormAsync(model, cancellationToken);
            ViewBag.Categories = new SelectList(vm.Categories, "CategoryId", "Name", vm.CategoryId);
            return View(vm);
        }
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken cancellationToken)
    {
        FillCommonViewData("dishes");
        var dish = await _catalogClient.GetAdminDishByIdAsync(id, cancellationToken);
        if (dish is null)
        {
            TempData["Error"] = "Không tìm thấy món.";
            return RedirectToAction(nameof(Index));
        }

        var vm = await BuildFormAsync(new AdminDishFormViewModel
        {
            DishId = dish.DishId,
            Name = dish.Name,
            Price = dish.Price,
            CategoryId = dish.CategoryId,
            Description = dish.Description,
            Unit = dish.Unit,
            Image = dish.Image,
            IsVegetarian = dish.IsVegetarian,
            IsDailySpecial = dish.IsDailySpecial,
            Available = dish.Available,
            IsActive = dish.IsActive
        }, cancellationToken);
        ViewBag.Categories = new SelectList(vm.Categories, "CategoryId", "Name", vm.CategoryId);

        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, AdminDishFormViewModel model, IFormFile? imageFile, CancellationToken cancellationToken)
    {
        try
        {
            model = NormalizeDishFormAliases(model);
            if (string.IsNullOrWhiteSpace(model.Image) && (imageFile is null || imageFile.Length <= 0))
            {
                var existingDish = await _catalogClient.GetAdminDishByIdAsync(id, cancellationToken);
                model = new AdminDishFormViewModel
                {
                    DishId = model.DishId,
                    Name = model.Name,
                    Price = model.Price,
                    CategoryId = model.CategoryId,
                    Description = model.Description,
                    Unit = model.Unit,
                    Image = existingDish?.Image,
                    IsVegetarian = model.IsVegetarian,
                    IsDailySpecial = model.IsDailySpecial,
                    Available = model.Available,
                    IsActive = model.IsActive,
                    Categories = model.Categories
                };
            }
            model = await WithResolvedImageAsync(model, imageFile, cancellationToken);
            await _catalogClient.UpdateAdminDishAsync(
                id,
                new AdminUpsertDishRequest(
                    model.Name,
                    model.Price,
                    model.CategoryId,
                    model.Description,
                    model.Unit,
                    model.Image,
                    model.IsVegetarian,
                    model.IsDailySpecial,
                    model.Available,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã cập nhật món.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            FillCommonViewData("dishes");
            var vm = await BuildFormAsync(model, cancellationToken);
            ViewBag.Categories = new SelectList(vm.Categories, "CategoryId", "Name", vm.CategoryId);
            return View(vm);
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.DeactivateAdminDishAsync(id, cancellationToken);
            TempData["Success"] = "Đã vô hiệu hóa món.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    public async Task<IActionResult> ToggleAvailability(int id, bool available, CancellationToken cancellationToken)
    {
        try
        {
            var current = await _catalogClient.GetAdminDishByIdAsync(id, cancellationToken);
            if (current is null)
            {
                TempData["Error"] = "Không tìm thấy món.";
                return RedirectToAction(nameof(Index));
            }

            await _catalogClient.UpdateAdminDishAsync(
                id,
                new AdminUpsertDishRequest(
                    current.Name,
                    current.Price,
                    current.CategoryId,
                    current.Description,
                    current.Unit,
                    current.Image,
                    current.IsVegetarian,
                    current.IsDailySpecial,
                    available,
                    current.IsActive),
                cancellationToken);

            TempData["Success"] = available ? "Đã mở bán món." : "Đã tạm ngưng bán món.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        FillCommonViewData("dishes");
        var dish = await _catalogClient.GetAdminDishByIdAsync(id, cancellationToken);
        if (dish is null)
        {
            TempData["Error"] = "Không tìm thấy món.";
            return RedirectToAction(nameof(Index));
        }

        return View(dish);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _catalogClient.DeactivateAdminDishAsync(id, cancellationToken);
            TempData["Success"] = "Đã ẩn món ăn.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> Ingredients(int id, CancellationToken cancellationToken)
    {
        FillCommonViewData("dishes");
        var dish = await _catalogClient.GetAdminDishByIdAsync(id, cancellationToken);
        if (dish is null)
        {
            TempData["Error"] = "Không tìm thấy món.";
            return RedirectToAction(nameof(Index));
        }

        var lines = await _catalogClient.GetDishIngredientsAsync(id, cancellationToken);
        ViewBag.AllIngredients = lines
            .Where(x => x.IsActive)
            .OrderBy(x => x.Name)
            .ToArray();

        return View(new AdminDishIngredientsViewModel
        {
            DishId = id,
            DishName = dish.Name,
            Lines = lines
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Ingredients(
        int id,
        [FromForm] int[] ingredientId,
        [FromForm] decimal[] quantityPerDish,
        CancellationToken cancellationToken)
    {
        try
        {
            var items = new List<AdminDishIngredientItemRequest>();
            for (var i = 0; i < Math.Min(ingredientId.Length, quantityPerDish.Length); i++)
            {
                if (ingredientId[i] > 0 && quantityPerDish[i] > 0)
                {
                    items.Add(new AdminDishIngredientItemRequest(ingredientId[i], quantityPerDish[i]));
                }
            }

            await _catalogClient.UpdateDishIngredientsAsync(id, items, cancellationToken);
            TempData["Success"] = "Đã cập nhật nguyên liệu cho món.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Ingredients), new { id });
    }

    [HttpPost]
    public async Task<IActionResult> AddIngredient(int dishId, int ingredientId, string quantityPerDish, CancellationToken cancellationToken)
    {
        if (dishId <= 0 || ingredientId <= 0)
        {
            TempData["Error"] = "Món hoặc nguyên liệu không hợp lệ.";
            return RedirectToAction(nameof(Ingredients), new { id = dishId });
        }

        if (!TryParseDecimal(quantityPerDish, out var quantity) || quantity <= 0)
        {
            TempData["Error"] = "Số lượng mỗi phần phải là số lớn hơn 0.";
            return RedirectToAction(nameof(Ingredients), new { id = dishId });
        }

        try
        {
            var lines = await _catalogClient.GetDishIngredientsAsync(dishId, cancellationToken);
            var selected = lines
                .Where(x => x.Selected)
                .ToDictionary(x => x.IngredientId, x => x.QuantityPerDish);

            selected[ingredientId] = quantity;

            var payload = selected
                .Where(x => x.Key > 0 && x.Value > 0)
                .Select(x => new AdminDishIngredientItemRequest(x.Key, x.Value))
                .ToList();

            await _catalogClient.UpdateDishIngredientsAsync(dishId, payload, cancellationToken);
            TempData["Success"] = "Đã lưu thành phần món ăn.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Ingredients), new { id = dishId });
    }

    [HttpGet]
    public Task<IActionResult> RemoveIngredient(int id, int dishId, CancellationToken cancellationToken)
        => RemoveIngredientCoreAsync(id, dishId, cancellationToken);

    [HttpPost]
    public Task<IActionResult> RemoveIngredientPost(int id, int dishId, CancellationToken cancellationToken)
        => RemoveIngredientCoreAsync(id, dishId, cancellationToken);

    private async Task<IActionResult> RemoveIngredientCoreAsync(int id, int dishId, CancellationToken cancellationToken)
    {
        if (id <= 0 || dishId <= 0)
        {
            TempData["Error"] = "Thành phần hoặc món ăn không hợp lệ.";
            return RedirectToAction(nameof(Ingredients), new { id = dishId });
        }

        try
        {
            var lines = await _catalogClient.GetDishIngredientsAsync(dishId, cancellationToken);
            var payload = lines
                .Where(x => x.Selected && x.IngredientId != id && x.QuantityPerDish > 0)
                .Select(x => new AdminDishIngredientItemRequest(x.IngredientId, x.QuantityPerDish))
                .ToList();

            await _catalogClient.UpdateDishIngredientsAsync(dishId, payload, cancellationToken);
            TempData["Success"] = "Đã xóa thành phần khỏi món ăn.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Ingredients), new { id = dishId });
    }

    private async Task<string?> ResolveDishImageAsync(string? currentImage, IFormFile? imageFile, CancellationToken cancellationToken)
    {
        if (imageFile is null || imageFile.Length <= 0)
        {
            return currentImage;
        }

        var extension = Path.GetExtension(imageFile.FileName);
        if (string.IsNullOrWhiteSpace(extension))
        {
            extension = ".jpg";
        }

        var uploadsRoot = Path.Combine(_environment.WebRootPath, "uploads", "dishes");
        Directory.CreateDirectory(uploadsRoot);

        var fileName = $"{Guid.NewGuid():N}{extension}";
        var filePath = Path.Combine(uploadsRoot, fileName);

        await using var stream = System.IO.File.Create(filePath);
        await imageFile.CopyToAsync(stream, cancellationToken);

        return $"/uploads/dishes/{fileName}";
    }

    private async Task<AdminDishFormViewModel> WithResolvedImageAsync(AdminDishFormViewModel model, IFormFile? imageFile, CancellationToken cancellationToken)
    {
        var resolvedImage = await ResolveDishImageAsync(model.Image, imageFile, cancellationToken);
        return new AdminDishFormViewModel
        {
            DishId = model.DishId,
            Name = model.Name,
            Price = model.Price,
            CategoryId = model.CategoryId,
            Description = model.Description,
            Unit = model.Unit,
            Image = resolvedImage,
            IsVegetarian = model.IsVegetarian,
            IsDailySpecial = model.IsDailySpecial,
            Available = model.Available,
            IsActive = model.IsActive,
            Categories = model.Categories
        };
    }

    private async Task<AdminDishFormViewModel> BuildFormAsync(AdminDishFormViewModel? seed, CancellationToken cancellationToken)
    {
        var categories = await _catalogClient.GetCategoriesAsync(includeInactive: false, cancellationToken) ?? Array.Empty<CategoryDto>();
        if (seed is null)
        {
            return new AdminDishFormViewModel
            {
                Available = true,
                IsActive = true,
                CategoryId = categories.FirstOrDefault()?.CategoryId ?? 0,
                Categories = categories
            };
        }

        return new AdminDishFormViewModel
        {
            DishId = seed.DishId,
            Name = seed.Name,
            Price = seed.Price,
            CategoryId = seed.CategoryId,
            Description = seed.Description,
            Unit = seed.Unit,
            Image = seed.Image,
            IsVegetarian = seed.IsVegetarian,
            IsDailySpecial = seed.IsDailySpecial,
            Available = seed.Available,
            IsActive = seed.IsActive,
            Categories = categories
        };
    }

    private AdminDishFormViewModel NormalizeDishFormAliases(AdminDishFormViewModel model)
    {
        if (model.CategoryId > 0)
        {
            return model;
        }

        if (Request.HasFormContentType &&
            int.TryParse(Request.Form["CategoryID"], out var categoryId) &&
            categoryId > 0)
        {
            return new AdminDishFormViewModel
            {
                DishId = model.DishId,
                Name = model.Name,
                Price = model.Price,
                CategoryId = categoryId,
                Description = model.Description,
                Unit = model.Unit,
                Image = model.Image,
                IsVegetarian = model.IsVegetarian,
                IsDailySpecial = model.IsDailySpecial,
                Available = model.Available,
                IsActive = model.IsActive,
                Categories = model.Categories
            };
        }

        return model;
    }

    private static bool TryParseDecimal(string? raw, out decimal value)
    {
        value = 0;
        if (string.IsNullOrWhiteSpace(raw))
        {
            return false;
        }

        var normalized = raw.Trim().Replace(',', '.');
        return decimal.TryParse(normalized, NumberStyles.Number, CultureInfo.InvariantCulture, out value);
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

