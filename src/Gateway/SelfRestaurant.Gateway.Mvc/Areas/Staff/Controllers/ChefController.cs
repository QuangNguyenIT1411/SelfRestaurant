using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Controllers;

[Area("Staff")]
[StaffAuthorize(AllowedRoles = new[] { "CHEF", "MANAGER", "ADMIN" })]
public sealed class ChefController : Controller
{
    private const int CompositeDishIngredientBase = 1_000_000;

    private readonly OrdersClient _ordersClient;
    private readonly CatalogClient _catalogClient;
    private readonly IdentityClient _identityClient;

    public ChefController(OrdersClient ordersClient, CatalogClient catalogClient, IdentityClient identityClient)
    {
        _ordersClient = ordersClient;
        _catalogClient = catalogClient;
        _identityClient = identityClient;
    }

    private bool IsAjaxRequest() =>
        string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            TempData["Error"] = "Không tìm thấy chi nhánh của nhân viên.";
            return View(new ChefDashboardViewModel());
        }

        var vm = await BuildDashboardViewModelAsync(branchId.Value, historyTake: 100, cancellationToken);

        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);

        var flatOrders = vm.PendingOrders.Concat(vm.PreparingOrders).Concat(vm.ReadyOrders)
            .SelectMany(o => o.Items.Select(i => new
            {
                id = i.ItemID,
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                table = o.TableName,
                dish = i.DishName,
                quantity = i.Quantity,
                status = (o.StatusCode == "PENDING" || o.StatusCode == "CONFIRMED") ? "pending"
                    : o.StatusCode == "PREPARING" ? "preparing"
                    : o.StatusCode == "READY" ? "ready"
                    : "completed",
                time = o.OrderTime.ToString("HH:mm"),
                note = i.Note ?? string.Empty
            }));

        var todayMenuItems = vm.TodayMenu.Dishes.Select(d => new
        {
            id = d.DishID,
            name = d.Name,
            price = d.Price,
            unit = d.Unit,
            categoryId = d.CategoryID,
            categoryName = d.CategoryName,
            available = d.Available,
            image = d.Image ?? string.Empty,
            description = d.Description ?? string.Empty,
            isVegetarian = d.IsVegetarian,
            isDailySpecial = d.IsDailySpecial
        });

        var activeIngredients = await GetAllActiveIngredientsAsync(cancellationToken);
        ViewBag.ChefOrdersJson = JsonSerializer.Serialize(flatOrders);
        ViewBag.ChefMenuJson = JsonSerializer.Serialize(todayMenuItems);
        ViewBag.ChefIngredientsJson = JsonSerializer.Serialize(activeIngredients.Select(i => new
        {
            id = i.IngredientId,
            name = i.Name,
            unit = i.Unit,
            stock = i.CurrentStock,
            reorderLevel = i.ReorderLevel
        }));

        return View(vm);
    }

    [HttpGet]
    public async Task<IActionResult> GetOrdersBoard(CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            return Unauthorized();
        }

        var vm = await BuildDashboardViewModelAsync(branchId.Value, historyTake: 50, cancellationToken);
        return PartialView("~/Areas/Staff/Views/Chef/_OrdersBoard.cshtml", vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [ActionName("Index")]
    public IActionResult IndexPost()
    {
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> History(CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            return RedirectToAction(nameof(Index));
        }

        var vm = await BuildDashboardViewModelAsync(branchId.Value, historyTake: 200, cancellationToken);
        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);
        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Start(int orderId, CancellationToken cancellationToken)
    {
        try
        {
            await _ordersClient.ChefStartAsync(orderId, cancellationToken);
            TempData["Success"] = $"Đã chuyển đơn #{orderId} sang Đang chuẩn bị.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Ready(int orderId, CancellationToken cancellationToken)
    {
        try
        {
            await _ordersClient.ChefReadyAsync(orderId, cancellationToken);
            TempData["Success"] = $"Đơn #{orderId} đã sẵn sàng.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Serve(int orderId, CancellationToken cancellationToken)
    {
        try
        {
            await _ordersClient.ChefServeAsync(orderId, cancellationToken);
            TempData["Success"] = $"Đơn #{orderId} đã chuyển trạng thái phục vụ.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Cancel(int orderId, [FromForm] string? reason, CancellationToken cancellationToken)
    {
        try
        {
            await _ordersClient.ChefCancelAsync(orderId, reason, cancellationToken);
            TempData["Success"] = $"Đơn #{orderId} đã được hủy.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateItemNote(
        int orderId,
        int itemId,
        [FromForm] string? note,
        [FromForm] bool append = true,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await _ordersClient.ChefUpdateItemNoteAsync(orderId, itemId, note, append, cancellationToken);
            TempData["Success"] = $"Đã cập nhật ghi chú món #{itemId} của đơn #{orderId}.";
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
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            TempData["Error"] = "Không tìm thấy chi nhánh của nhân viên.";
            return RedirectToAction(nameof(Index));
        }

        var dishIds = await GetTodayMenuDishIdsAsync(branchId.Value, cancellationToken);
        if (!dishIds.Contains(id))
        {
            TempData["Error"] = "Món không thuộc menu chi nhánh hôm nay.";
            return RedirectToAction(nameof(Index));
        }

        var dish = await _catalogClient.GetAdminDishByIdAsync(id, cancellationToken);
        if (dish is null)
        {
            TempData["Error"] = "Không tìm thấy món.";
            return RedirectToAction(nameof(Index));
        }

        var lines = await _catalogClient.GetDishIngredientsAsync(id, cancellationToken);
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
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            TempData["Error"] = "Không tìm thấy chi nhánh của nhân viên.";
            return RedirectToAction(nameof(Index));
        }

        var dishIds = await GetTodayMenuDishIdsAsync(branchId.Value, cancellationToken);
        if (!dishIds.Contains(id))
        {
            TempData["Error"] = "Món không thuộc menu chi nhánh hôm nay.";
            return RedirectToAction(nameof(Index));
        }

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
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SetDishAvailability(int dishId, bool available, CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            TempData["Error"] = "Không tìm thấy chi nhánh của nhân viên.";
            return RedirectToAction(nameof(Index));
        }

        var dishIds = await GetTodayMenuDishIdsAsync(branchId.Value, cancellationToken);
        if (!dishIds.Contains(dishId))
        {
            TempData["Error"] = "Món không thuộc menu chi nhánh hôm nay.";
            return RedirectToAction(nameof(Index));
        }

        try
        {
            var current = await _catalogClient.GetAdminDishByIdAsync(dishId, cancellationToken);
            if (current is null)
            {
                TempData["Error"] = "Không tìm thấy món.";
                return RedirectToAction(nameof(Index));
            }

            await _catalogClient.UpdateAdminDishAsync(
                dishId,
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

            TempData["Success"] = available
                ? $"Đã bật bán món #{dishId}."
                : $"Đã tắt món #{dishId} do hết nguyên liệu.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { tab = "tab-menu" });
    }

    [HttpPost]
    public async Task<IActionResult> UpdateOrderStatus(int orderId, string statusCode, CancellationToken cancellationToken)
    {
        if (orderId <= 0 || string.IsNullOrWhiteSpace(statusCode))
        {
            return Json(new { success = false, message = "Dữ liệu cập nhật trạng thái không hợp lệ." });
        }

        try
        {
            await _ordersClient.ChefUpdateStatusAsync(orderId, statusCode.Trim().ToUpperInvariant(), cancellationToken);
            return Json(new
            {
                success = true,
                message = "Cập nhật trạng thái đơn hàng thành công.",
                statusCode = statusCode.Trim().ToUpperInvariant()
            });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> CancelOrder(int orderId, string reason, CancellationToken cancellationToken)
    {
        if (orderId <= 0)
        {
            return Json(new { success = false, message = "Đơn hàng không hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(reason))
        {
            return Json(new { success = false, message = "Vui lòng nhập lý do hủy đơn." });
        }

        try
        {
            await _ordersClient.ChefCancelAsync(orderId, reason.Trim(), cancellationToken);
            return Json(new { success = true, message = "Đã hủy đơn hàng." });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> HideDish(int dishId, CancellationToken cancellationToken)
    {
        var result = await TrySetDishAvailabilityAsync(dishId, available: false, cancellationToken);
        return Json(new { success = result.success, message = result.message });
    }

    [HttpPost]
    public async Task<IActionResult> ShowDish(int dishId, CancellationToken cancellationToken)
    {
        var result = await TrySetDishAvailabilityAsync(dishId, available: true, cancellationToken);
        return Json(new { success = result.success, message = result.message });
    }

    [HttpPost]
    public async Task<IActionResult> AddDish(
        string name,
        string price,
        string unit,
        int categoryId,
        string? description,
        bool available = true,
        bool isVegetarian = false,
        bool isDailySpecial = false,
        string? image = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return Json(new { success = false, message = "Vui lòng nhập tên món ăn." });
        }

        if (!TryParseDecimal(price, out var parsedPrice) || parsedPrice <= 0)
        {
            return Json(new { success = false, message = "Giá món ăn phải là số lớn hơn 0." });
        }

        if (string.IsNullOrWhiteSpace(unit))
        {
            return Json(new { success = false, message = "Vui lòng nhập đơn vị món ăn." });
        }

        if (categoryId <= 0)
        {
            return Json(new { success = false, message = "Danh mục món ăn không hợp lệ." });
        }

        try
        {
            await _catalogClient.CreateAdminDishAsync(
                new AdminUpsertDishRequest(
                    Name: name.Trim(),
                    Price: parsedPrice,
                    CategoryId: categoryId,
                    Description: description?.Trim(),
                    Unit: unit.Trim(),
                    Image: image,
                    IsVegetarian: isVegetarian,
                    IsDailySpecial: isDailySpecial,
                    Available: available,
                    IsActive: true),
                cancellationToken);

            return Json(new { success = true, message = "Đã thêm món mới vào menu hôm nay." });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> EditDish(
        int dishId,
        string name,
        string price,
        string unit,
        string? description,
        bool isVegetarian = false,
        bool isDailySpecial = false,
        string? image = null,
        CancellationToken cancellationToken = default)
    {
        if (dishId <= 0)
        {
            return Json(new { success = false, message = "Món ăn không hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(name))
        {
            return Json(new { success = false, message = "Vui lòng nhập tên món ăn." });
        }

        if (!TryParseDecimal(price, out var parsedPrice) || parsedPrice <= 0)
        {
            return Json(new { success = false, message = "Giá món ăn phải là số lớn hơn 0." });
        }

        if (string.IsNullOrWhiteSpace(unit))
        {
            return Json(new { success = false, message = "Vui lòng nhập đơn vị món ăn." });
        }

        try
        {
            var current = await _catalogClient.GetAdminDishByIdAsync(dishId, cancellationToken);
            if (current is null)
            {
                return Json(new { success = false, message = "Không tìm thấy món ăn." });
            }

            await _catalogClient.UpdateAdminDishAsync(
                dishId,
                new AdminUpsertDishRequest(
                    Name: name.Trim(),
                    Price: parsedPrice,
                    CategoryId: current.CategoryId,
                    Description: description?.Trim(),
                    Unit: unit.Trim(),
                    Image: string.IsNullOrWhiteSpace(image) ? current.Image : image,
                    IsVegetarian: isVegetarian,
                    IsDailySpecial: isDailySpecial,
                    Available: current.Available,
                    IsActive: current.IsActive),
                cancellationToken);

            return Json(new { success = true, message = "Đã cập nhật thông tin món ăn." });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetDishIngredients(int dishId, CancellationToken cancellationToken)
    {
        if (dishId <= 0)
        {
            return Json(new { success = false, message = "Món ăn không hợp lệ." });
        }

        try
        {
            var lines = await _catalogClient.GetDishIngredientsAsync(dishId, cancellationToken);
            var items = lines
                .Where(x => x.Selected)
                .Select(x => new
                {
                    id = EncodeDishIngredientId(dishId, x.IngredientId),
                    ingredientId = x.IngredientId,
                    ingredientName = x.Name,
                    unit = x.Unit,
                    quantity = x.QuantityPerDish
                });

            return Json(new { success = true, items });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> AddDishIngredient(
        int dishId,
        int ingredientId,
        string quantityPerDish,
        CancellationToken cancellationToken)
    {
        if (dishId <= 0 || ingredientId <= 0)
        {
            return Json(new { success = false, message = "Món ăn hoặc nguyên liệu không hợp lệ." });
        }

        if (!TryParseDecimal(quantityPerDish, out var quantity) || quantity <= 0)
        {
            return Json(new { success = false, message = "Số lượng mỗi phần phải là số lớn hơn 0." });
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
            return Json(new { success = true, message = "Đã lưu thành phần món ăn." });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> RemoveDishIngredient(int id, CancellationToken cancellationToken)
    {
        if (!TryDecodeDishIngredientId(id, out var dishId, out var ingredientId))
        {
            return Json(new { success = false, message = "Thành phần không hợp lệ." });
        }

        try
        {
            var lines = await _catalogClient.GetDishIngredientsAsync(dishId, cancellationToken);
            var payload = lines
                .Where(x => x.Selected && x.IngredientId != ingredientId && x.QuantityPerDish > 0)
                .Select(x => new AdminDishIngredientItemRequest(x.IngredientId, x.QuantityPerDish))
                .ToList();

            await _catalogClient.UpdateDishIngredientsAsync(dishId, payload, cancellationToken);
            return Json(new { success = true, message = "Đã xóa thành phần khỏi món ăn." });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetOrderItemIngredients(int orderItemId, CancellationToken cancellationToken)
    {
        if (orderItemId <= 0)
        {
            return Json(new { success = false, message = "Món trong đơn không hợp lệ." });
        }

        try
        {
            var orderItem = await FindChefOrderItemAsync(orderItemId, cancellationToken);
            if (orderItem is null)
            {
                return Json(new { success = false, message = "Không tìm thấy món trong đơn." });
            }

            var lines = await _catalogClient.GetDishIngredientsAsync(orderItem.DishId, cancellationToken);
            var items = lines
                .Where(x => x.Selected)
                .Select(x => new
                {
                    ingredientId = x.IngredientId,
                    ingredientName = x.Name,
                    unit = x.Unit,
                    quantity = x.QuantityPerDish,
                    isRemoved = false
                });

            return Json(new
            {
                success = true,
                dishName = orderItem.DishName,
                fromOverride = false,
                items
            });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> SaveOrderItemIngredients(int orderItemId, string itemsJson, CancellationToken cancellationToken)
    {
        if (orderItemId <= 0)
        {
            return Json(new { success = false, message = "Món trong đơn không hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(itemsJson))
        {
            return Json(new { success = false, message = "Danh sách thành phần không hợp lệ." });
        }

        try
        {
            var orderItem = await FindChefOrderItemAsync(orderItemId, cancellationToken);
            if (orderItem is null)
            {
                return Json(new { success = false, message = "Không tìm thấy món trong đơn." });
            }

            var parsedItems = JsonSerializer.Deserialize<List<LegacyOrderItemIngredientInput>>(
                itemsJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (parsedItems is null || parsedItems.Count == 0)
            {
                return Json(new { success = false, message = "Danh sách thành phần không hợp lệ." });
            }

            var removedIds = parsedItems
                .Where(x => x.IsRemoved)
                .Select(x => x.IngredientId)
                .ToHashSet();

            var tuned = parsedItems
                .Where(x => !x.IsRemoved && x.Quantity >= 0)
                .Select(x => $"{x.IngredientId}:{x.Quantity.ToString("0.##", CultureInfo.InvariantCulture)}")
                .ToList();

            var noteParts = new List<string>();
            if (removedIds.Count > 0)
            {
                noteParts.Add("Bỏ NL #" + string.Join(",", removedIds.OrderBy(x => x)));
            }
            if (tuned.Count > 0)
            {
                noteParts.Add("ĐL chỉnh: " + string.Join("; ", tuned));
            }

            var note = noteParts.Count == 0 ? null : "[Chef cấu hình] " + string.Join(" | ", noteParts);
            await _ordersClient.ChefUpdateItemNoteAsync(orderItem.OrderId, orderItem.ItemId, note, append: false, cancellationToken);

            return Json(new { success = true, message = "Đã lưu thành phần riêng cho đơn này." });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> UpdateAccount(
        [FromForm] string name,
        [FromForm] string email,
        [FromForm] string phone,
        CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." });
            }

            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        try
        {
            var profile = await _identityClient.UpdateStaffProfileAsync(
                employeeId.Value,
                new StaffUpdateProfileRequest(name, phone, email),
                cancellationToken);

            if (profile is not null)
            {
                HttpContext.Session.SetString(SessionKeys.EmployeeName, profile.Name);
                HttpContext.Session.SetString(SessionKeys.EmployeePhone, profile.Phone ?? "");
                HttpContext.Session.SetString(SessionKeys.EmployeeEmail, profile.Email ?? "");
            }

            TempData["Success"] = "Cập nhật tài khoản thành công.";
            if (IsAjaxRequest())
            {
                return Json(new { success = true, message = "Cập nhật tài khoản thành công." });
            }
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    public async Task<IActionResult> ChangePassword(
        [FromForm] string currentPassword,
        [FromForm] string newPassword,
        [FromForm] string confirmPassword,
        CancellationToken cancellationToken)
    {
        var employeeId = HttpContext.Session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null || employeeId <= 0)
        {
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." });
            }

            return RedirectToAction("Login", "Account", new { area = "Staff" });
        }

        if (!string.Equals(newPassword, confirmPassword, StringComparison.Ordinal))
        {
            TempData["Error"] = "Mật khẩu mới và xác nhận không khớp.";
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Mật khẩu mới và xác nhận không khớp." });
            }

            return RedirectToAction(nameof(Index));
        }

        try
        {
            await _identityClient.StaffChangePasswordAsync(
                new StaffChangePasswordRequest(employeeId.Value, currentPassword, newPassword),
                cancellationToken);

            TempData["Success"] = "Đổi mật khẩu thành công.";
            if (IsAjaxRequest())
            {
                return Json(new { success = true, message = "Đổi mật khẩu thành công." });
            }
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        return RedirectToAction(nameof(Index));
    }

    private async Task<ChefDashboardViewModel> BuildDashboardViewModelAsync(
        int branchId,
        int historyTake,
        CancellationToken cancellationToken)
    {
        var branchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName) ?? "";
        var employeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? "";
        var roleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName) ?? "";

        var list = await _ordersClient.GetChefOrdersAsync(branchId, status: null, cancellationToken);
        var history = await _ordersClient.GetChefHistoryAsync(branchId, take: historyTake, cancellationToken);
        var todayMenu = await _catalogClient.GetMenuAsync(branchId, DateOnly.FromDateTime(DateTime.Today), cancellationToken: cancellationToken);

        var mappedOrders = list.Select(o => new ChefOrderViewModel
        {
            OrderID = o.OrderId,
            OrderCode = o.OrderCode ?? $"ORD{o.OrderId}",
            OrderTime = o.OrderTime,
            TableName = string.IsNullOrWhiteSpace(o.TableName)
                ? (o.TableId is > 0 ? $"Bàn {o.TableId}" : "N/A")
                : o.TableName,
            TableSeats = 0,
            BranchName = branchName,
            StatusCode = o.StatusCode,
            StatusName = o.StatusName,
            Items = o.Items.Select(i => new ChefOrderItemViewModel
            {
                ItemID = i.ItemId,
                DishID = 0,
                DishName = i.DishName,
                Quantity = i.Quantity,
                Unit = "",
                Note = i.Note ?? "",
                IsVegetarian = false,
                CreatedAt = o.OrderTime
            }).ToList()
        }).ToList();

        var pending = mappedOrders.Where(x => x.StatusCode == "PENDING" || x.StatusCode == "CONFIRMED").ToList();
        var preparing = mappedOrders.Where(x => x.StatusCode == "PREPARING").ToList();
        var ready = mappedOrders.Where(x => x.StatusCode == "READY").ToList();

        var menuVm = new ChefMenuViewModel
        {
            MenuID = 0,
            MenuName = $"Thực đơn {DateTime.Today:dd/MM/yyyy}",
            MenuDate = DateTime.Today,
            BranchID = branchId,
            BranchName = branchName,
            Dishes = todayMenu?.Categories
                .SelectMany(c => c.Dishes.Select(d => new ChefDishViewModel
                {
                    DishID = d.DishId,
                    Name = d.Name,
                    Price = d.Price,
                    Unit = d.Unit ?? "",
                    CategoryID = c.CategoryId,
                    CategoryName = c.CategoryName,
                    Image = ResolveDishImage(d.Image, d.Name),
                    Description = d.Description ?? "",
                    Available = d.Available,
                    IsVegetarian = d.IsVegetarian,
                    IsDailySpecial = d.IsDailySpecial,
                }))
                .ToList() ?? new List<ChefDishViewModel>()
        };

        return new ChefDashboardViewModel
        {
            PendingOrders = pending,
            PreparingOrders = preparing,
            ReadyOrders = ready,
            PendingOrdersCount = pending.Count,
            PreparingOrdersCount = preparing.Count,
            ReadyOrdersCount = ready.Count,
            TodayMenu = menuVm,
            History = history.Select(x => new ChefWorkHistoryViewModel
            {
                OrderID = x.OrderId,
                OrderCode = x.OrderCode ?? $"ORD{x.OrderId}",
                OrderTime = x.OrderTime,
                CompletedTime = x.CompletedTime,
                TableName = x.TableName ?? "",
                BranchName = branchName,
                StatusCode = x.StatusCode,
                StatusName = x.StatusName,
                DishesSummary = x.DishesSummary
            }).ToList(),
            Account = new ChefAccountViewModel
            {
                EmployeeID = HttpContext.Session.GetInt32(SessionKeys.EmployeeId) ?? 0,
                Name = employeeName,
                Username = HttpContext.Session.GetString(SessionKeys.EmployeeUsername) ?? "",
                Email = HttpContext.Session.GetString(SessionKeys.EmployeeEmail) ?? "",
                Phone = HttpContext.Session.GetString(SessionKeys.EmployeePhone) ?? "",
                BranchName = branchName,
                RoleName = roleName
            }
        };
    }

    private async Task<(bool success, string message)> TrySetDishAvailabilityAsync(
        int dishId,
        bool available,
        CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            return (false, "Không tìm thấy chi nhánh của nhân viên.");
        }

        var dishIds = await GetTodayMenuDishIdsAsync(branchId.Value, cancellationToken);
        if (!dishIds.Contains(dishId))
        {
            return (false, "Món không thuộc menu chi nhánh hôm nay.");
        }

        var current = await _catalogClient.GetAdminDishByIdAsync(dishId, cancellationToken);
        if (current is null)
        {
            return (false, "Không tìm thấy món ăn.");
        }

        await _catalogClient.UpdateAdminDishAsync(
            dishId,
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

        return available
            ? (true, "Đã mở bán lại món ăn.")
            : (true, "Đã tạm ngưng bán món ăn.");
    }

    private async Task<IReadOnlyList<AdminIngredientDto>> GetAllActiveIngredientsAsync(CancellationToken cancellationToken)
    {
        var result = new List<AdminIngredientDto>();
        var page = 1;

        while (true)
        {
            var response = await _catalogClient.GetAdminIngredientsAsync(null, page, 100, cancellationToken);
            if (response is null || response.Items.Count == 0)
            {
                break;
            }

            result.AddRange(response.Items.Where(x => x.IsActive));
            if (page >= response.TotalPages)
            {
                break;
            }

            page++;
        }

        return result;
    }

    private async Task<HashSet<int>> GetTodayMenuDishIdsAsync(int branchId, CancellationToken cancellationToken)
    {
        var menu = await _catalogClient.GetMenuAsync(
            branchId,
            DateOnly.FromDateTime(DateTime.Today),
            cancellationToken: cancellationToken);

        return menu?.Categories
            .SelectMany(c => c.Dishes.Select(d => d.DishId))
            .ToHashSet() ?? new HashSet<int>();
    }

    private async Task<ChefOrderItemContext?> FindChefOrderItemAsync(int orderItemId, CancellationToken cancellationToken)
    {
        var branchId = HttpContext.Session.GetInt32(SessionKeys.EmployeeBranchId);
        if (branchId is null || branchId <= 0)
        {
            return null;
        }

        var orders = await _ordersClient.GetChefOrdersAsync(branchId.Value, status: null, cancellationToken);
        foreach (var order in orders)
        {
            var matched = order.Items.FirstOrDefault(x => x.ItemId == orderItemId);
            if (matched is null)
            {
                continue;
            }

            var orderDetail = await _ordersClient.GetOrderByIdAsync(order.OrderId, cancellationToken);
            if (orderDetail is null)
            {
                continue;
            }

            var item = orderDetail.Items.FirstOrDefault(x => x.ItemId == orderItemId);
            if (item is null)
            {
                continue;
            }

            return new ChefOrderItemContext(order.OrderId, orderItemId, item.DishId, item.DishName);
        }

        return null;
    }

    private static string ResolveDishImage(string? rawImage, string? dishName)
    {
        var normalized = NormalizeImagePath(rawImage);
        var slug = SlugifyDishName(dishName);

        if (!string.IsNullOrWhiteSpace(normalized))
        {
            if (normalized.Contains("/images/dish_", StringComparison.OrdinalIgnoreCase) &&
                !string.IsNullOrWhiteSpace(slug))
            {
                return $"/images/{slug}.jpg";
            }

            return normalized;
        }

        return string.IsNullOrWhiteSpace(slug)
            ? "/images/placeholder-dish.svg"
            : $"/images/{slug}.jpg";
    }

    private static string? NormalizeImagePath(string? rawImage)
    {
        if (string.IsNullOrWhiteSpace(rawImage))
        {
            return null;
        }

        var image = rawImage.Trim().Replace('\\', '/');
        if (image.StartsWith("~/", StringComparison.Ordinal))
        {
            image = "/" + image[2..];
        }

        if (!image.StartsWith("/", StringComparison.Ordinal) &&
            !image.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
            !image.StartsWith("https://", StringComparison.OrdinalIgnoreCase) &&
            !image.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
        {
            image = "/" + image;
        }

        if (image.StartsWith("/Images/", StringComparison.OrdinalIgnoreCase))
        {
            image = "/images/" + image["/Images/".Length..];
        }

        return image;
    }

    private static string? SlugifyDishName(string? dishName)
    {
        if (string.IsNullOrWhiteSpace(dishName))
        {
            return null;
        }

        var normalized = dishName.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(normalized.Length);
        var previousDash = false;

        foreach (var ch in normalized)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            var mapped = ch is 'đ' or 'Đ' ? 'd' : ch;
            if (char.IsLetterOrDigit(mapped))
            {
                builder.Append(char.ToLowerInvariant(mapped));
                previousDash = false;
            }
            else if (!previousDash)
            {
                builder.Append('-');
                previousDash = true;
            }
        }

        var slug = builder.ToString().Trim('-');
        return slug.Length == 0 ? null : slug;
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

    private static int EncodeDishIngredientId(int dishId, int ingredientId) =>
        (dishId * CompositeDishIngredientBase) + ingredientId;

    private static bool TryDecodeDishIngredientId(int compositeId, out int dishId, out int ingredientId)
    {
        dishId = 0;
        ingredientId = 0;

        if (compositeId <= 0)
        {
            return false;
        }

        dishId = compositeId / CompositeDishIngredientBase;
        ingredientId = compositeId % CompositeDishIngredientBase;
        return dishId > 0 && ingredientId > 0;
    }

    private sealed record ChefOrderItemContext(int OrderId, int ItemId, int DishId, string DishName);
    private sealed record LegacyOrderItemIngredientInput(int IngredientId, decimal Quantity, bool IsRemoved);
}
