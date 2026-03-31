using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;
using System.Globalization;
using System.Text.Json;
using System.Text;
using System.Text.Encodings.Web;

namespace SelfRestaurant.Gateway.Mvc.Controllers;

public sealed class MenuController : Controller
{
    private readonly CatalogClient _catalogClient;
    private readonly OrdersClient _ordersClient;
    private readonly CustomersClient _customersClient;
    private readonly IWebHostEnvironment _webHostEnvironment;

    public MenuController(
        CatalogClient catalogClient,
        OrdersClient ordersClient,
        CustomersClient customersClient,
        IWebHostEnvironment webHostEnvironment)
    {
        _catalogClient = catalogClient;
        _ordersClient = ordersClient;
        _customersClient = customersClient;
        _webHostEnvironment = webHostEnvironment;
    }

    [HttpGet]
    public async Task<IActionResult> FromQr(string? code, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            TempData["Error"] = "Mã QR không hợp lệ.";
            return RedirectToAction("Index", "Home");
        }

        if (HttpContext.Session.GetInt32(SessionKeys.CustomerId) is null)
        {
            var returnUrl = Url.Action("FromQr", "Menu", new { code });
            return RedirectToAction("Login", "Customer", new { returnUrl });
        }

        try
        {
            var table = await _catalogClient.GetTableByQrAsync(code, cancellationToken);
            if (table is null)
            {
                TempData["Error"] = "Không tìm thấy bàn tương ứng với mã QR.";
                return RedirectToAction("Index", "Home");
            }

            return RedirectToAction("Index", "Menu", new
            {
                tableId = table.TableId,
                branchId = table.BranchId,
                tableNumber = table.DisplayTableNumber
            });
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction("Index", "Home");
        }
    }

    [HttpGet]
    public async Task<IActionResult> Index(int? tableId, int? branchId, int? tableNumber, CancellationToken cancellationToken)
    {
        if (tableId is null || branchId is null)
        {
            return RedirectToAction("Index", "Home");
        }

        if (HttpContext.Session.GetInt32(SessionKeys.CustomerId) is null)
        {
            return RedirectToAction("Login", "Customer", new { returnUrl = Url.Action("Index", "Menu", new { tableId, branchId }) });
        }

        try
        {
            await _ordersClient.OccupyTableAsync(tableId.Value, cancellationToken);
            await TryAttachLoggedInCustomerToTableOrderAsync(tableId.Value, cancellationToken);
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction("Index", "Home");
        }

        var menu = await _catalogClient.GetMenuAsync(branchId.Value, cancellationToken: cancellationToken);
        if (menu is null)
        {
            ViewBag.Error = "Không tìm thấy thực đơn.";
            return View(null);
        }

        var requestedTableNumber = tableNumber is > 0 ? tableNumber.Value : (int?)null;
        var currentTableNumberInSession = HttpContext.Session.GetInt32(SessionKeys.CurrentTableNumber);
        var resolvedTableNumber = requestedTableNumber
            ?? (currentTableNumberInSession is > 0 ? currentTableNumberInSession.Value : (int?)null)
            ?? tableId.Value;

        HttpContext.Session.SetInt32(SessionKeys.CurrentTableId, tableId.Value);
        HttpContext.Session.SetInt32(SessionKeys.CurrentBranchId, branchId.Value);
        HttpContext.Session.SetString(SessionKeys.CurrentBranchName, menu.BranchName);
        HttpContext.Session.SetInt32(SessionKeys.CurrentTableNumber, resolvedTableNumber);

        ViewBag.TableId = tableId.Value;
        ViewBag.TableID = tableId.Value;
        ViewBag.TableNumber = resolvedTableNumber;
        ViewBag.BranchId = branchId.Value;
        ViewBag.BranchName = menu.BranchName;
        ViewBag.IsCustomerLoggedIn = true;
        ViewBag.CustomerName = HttpContext.Session.GetString(SessionKeys.CustomerName) ?? "";
        ViewBag.CustomerEmail = HttpContext.Session.GetString(SessionKeys.CustomerEmail) ?? "";
        ViewBag.CustomerPhone = HttpContext.Session.GetString(SessionKeys.CustomerPhoneNumber) ?? "";
        ViewBag.LoyaltyPoints = HttpContext.Session.GetInt32(SessionKeys.CustomerLoyaltyPoints) ?? 0;
        ViewBag.CustomerNameJson = JsonSerializer.Serialize(
            HttpContext.Session.GetString(SessionKeys.CustomerName) ?? string.Empty,
            new JsonSerializerOptions { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
        ViewBag.DishIngredients = menu.Categories
            .SelectMany(category => category.Dishes)
            .SelectMany(dish => (dish.Ingredients ?? Array.Empty<MenuDishIngredientDto>())
                .Select(ingredient => new
                {
                    dishId = dish.DishId,
                    name = ingredient.Name,
                    quantity = ingredient.Quantity,
                    unit = ingredient.Unit ?? string.Empty
                }))
            .ToList();

        // Duy trì shape dữ liệu cũ để view Menu MVC cũ hoạt động tương thích.
        ViewBag.Categories = menu.Categories
            .OrderBy(c => c.DisplayOrder)
            .Select(c => new
            {
                CategoryID = c.CategoryId,
                CategoryName = c.CategoryName,
                Dishes = c.Dishes
                    .Where(d => d.Available)
                    .Select(d => new
                    {
                        DishID = d.DishId,
                        Name = d.Name,
                        Price = d.Price,
                        Image = ResolveDishImage(d.Image, d.Name),
                        Description = d.Description,
                        Unit = d.Unit,
                        IsVegetarian = d.IsVegetarian,
                        IsDailySpecial = d.IsDailySpecial,
                        Available = d.Available,
                        Ingredients = (d.Ingredients ?? Array.Empty<MenuDishIngredientDto>())
                            .Select(ingredient => new
                            {
                                Name = ingredient.Name,
                                Quantity = ingredient.Quantity,
                                Unit = ingredient.Unit ?? string.Empty
                            })
                            .ToList()
                    })
                    .ToList()
            })
            .ToList();

        try
        {
            ViewBag.TopDishIds = await _ordersClient.GetTopDishIdsAsync(branchId.Value, count: 5, cancellationToken);
        }
        catch
        {
            ViewBag.TopDishIds = Array.Empty<int>();
        }

        try
        {
            var activeOrder = await _ordersClient.GetActiveOrderAsync(tableId.Value, cancellationToken);
            ViewBag.CurrentOrderId = activeOrder?.OrderId ?? 0;
        }
        catch
        {
            ViewBag.CurrentOrderId = 0;
        }

        return View(menu);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SendOrderToKitchen(
        int tableId,
        int branchId,
        string? items,
        CancellationToken cancellationToken)
    {
        if (HttpContext.Session.GetInt32(SessionKeys.CustomerId) is null)
        {
            return Json(new
            {
                success = false,
                requiresLogin = true,
                loginUrl = Url.Action("Login", "Customer")
            });
        }

        if (tableId <= 0 || branchId <= 0 || string.IsNullOrWhiteSpace(items))
        {
            return Json(new { success = false, message = "Dữ liệu gửi bếp không hợp lệ." });
        }

        List<SendOrderItemDto> orderItems;
        try
        {
            orderItems = JsonSerializer.Deserialize<List<SendOrderItemDto>>(
                items,
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? new List<SendOrderItemDto>();
        }
        catch
        {
            return Json(new { success = false, message = "Không đọc được dữ liệu món ăn." });
        }

        orderItems = orderItems
            .Where(i => i.DishID > 0 && i.Quantity > 0)
            .ToList();

        if (orderItems.Count == 0)
        {
            return Json(new { success = false, message = "Không có món nào để gửi bếp." });
        }

        try
        {
            await _ordersClient.OccupyTableAsync(tableId, cancellationToken);

            ActiveOrderResponse? lastOrder = null;
            var customerAttached = false;
            foreach (var item in orderItems)
            {
                lastOrder = await _ordersClient.AddItemAsync(
                    tableId,
                    item.DishID,
                    item.Quantity,
                    item.Note,
                    cancellationToken);

                if (!customerAttached)
                {
                    await TryAttachLoggedInCustomerToTableOrderAsync(tableId, cancellationToken);
                    customerAttached = true;
                }
            }

            await _ordersClient.SubmitOrderAsync(tableId, cancellationToken);

            var orderId = lastOrder?.OrderId;
            if (orderId is null or <= 0)
            {
                var activeOrder = await _ordersClient.GetActiveOrderAsync(tableId, cancellationToken);
                orderId = activeOrder?.OrderId;
            }

            return Json(new
            {
                success = true,
                message = "Yêu cầu của bạn đã được gửi cho bếp.",
                orderID = orderId ?? 0
            });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetTable(int tableId, int branchId, CancellationToken cancellationToken)
    {
        try
        {
            await _ordersClient.ResetTableAsync(tableId, cancellationToken);
        }
        catch
        {
            // Best-effort. Still clear session to let user pick another table.
        }

        ClearCurrentTableContextInSession();

        return RedirectToAction("Index", "Home");
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult ClearCurrentTableContext()
    {
        ClearCurrentTableContextInSession();
        return Json(new { success = true });
    }

    [HttpGet]
    public async Task<IActionResult> GetReadyNotifications(int tableId, CancellationToken cancellationToken)
    {
        var customerId = HttpContext.Session.GetInt32(SessionKeys.CustomerId);
        if (customerId is null)
        {
            return Json(new
            {
                success = false,
                requiresLogin = true,
                loginUrl = Url.Action("Login", "Customer")
            });
        }

        try
        {
            var items = await _customersClient.GetReadyNotificationsAsync(customerId.Value, tableId, cancellationToken);
            return Json(new { success = true, notifications = items });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message, notifications = Array.Empty<object>() });
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResolveReadyNotification(long notificationId, CancellationToken cancellationToken)
    {
        var customerId = HttpContext.Session.GetInt32(SessionKeys.CustomerId);
        if (customerId is null)
        {
            return Json(new
            {
                success = false,
                requiresLogin = true,
                loginUrl = Url.Action("Login", "Customer")
            });
        }

        try
        {
            await _customersClient.ResolveReadyNotificationAsync(notificationId, customerId.Value, cancellationToken);
            return Json(new { success = true });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    private void ClearCurrentTableContextInSession()
    {
        HttpContext.Session.Remove(SessionKeys.CurrentTableId);
        HttpContext.Session.Remove(SessionKeys.CurrentBranchId);
        HttpContext.Session.Remove(SessionKeys.CurrentBranchName);
        HttpContext.Session.Remove(SessionKeys.CurrentTableNumber);
    }

    private async Task TryAttachLoggedInCustomerToTableOrderAsync(int tableId, CancellationToken cancellationToken)
    {
        if (HttpContext.Session.GetInt32(SessionKeys.CustomerId) is null)
        {
            return;
        }

        var phoneNumber = HttpContext.Session.GetString(SessionKeys.CustomerPhoneNumber);
        if (string.IsNullOrWhiteSpace(phoneNumber))
        {
            return;
        }

        try
        {
            await _ordersClient.ScanLoyaltyCardAsync(tableId, phoneNumber.Trim(), cancellationToken);
        }
        catch
        {
            // Best-effort only. Customer can still continue ordering even if loyalty attach fails.
        }
    }

    private string ResolveDishImage(string? rawImage, string? dishName)
    {
        const string placeholder = "/images/placeholder-dish.svg";

        var candidates = new List<string>();
        void AddCandidate(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return;
            }

            var trimmed = value.Trim();
            if (!candidates.Contains(trimmed, StringComparer.OrdinalIgnoreCase))
            {
                candidates.Add(trimmed);
            }
        }

        AddCandidate(NormalizeImagePath(rawImage));

        var slug = SlugifyDishName(dishName);
        if (!string.IsNullOrWhiteSpace(slug))
        {
            AddCandidate($"/images/{slug}.jpg");
            AddCandidate($"/images/{slug}.jpeg");
            AddCandidate($"/images/{slug}.png");
            AddCandidate($"/Images/{slug}.jpg");
            AddCandidate($"/Images/{slug}.jpeg");
            AddCandidate($"/Images/{slug}.png");
        }

        foreach (var candidate in candidates)
        {
            if (IsRemoteImageUrl(candidate))
            {
                return candidate;
            }

            if (ExistsInWebRoot(candidate))
            {
                return candidate;
            }
        }

        return placeholder;
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
            image = "/" + image.Substring(2);
        }

        if (!image.StartsWith("/", StringComparison.Ordinal) && !IsRemoteImageUrl(image))
        {
            image = "/" + image;
        }

        if (image.StartsWith("/Images/", StringComparison.OrdinalIgnoreCase))
        {
            image = "/images/" + image.Substring("/Images/".Length);
        }

        return image;
    }

    private static bool IsRemoteImageUrl(string image)
    {
        return image.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
               image.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ||
               image.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase);
    }

    private bool ExistsInWebRoot(string relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath) ||
            _webHostEnvironment.WebRootPath is null ||
            !relativePath.StartsWith("/", StringComparison.Ordinal))
        {
            return false;
        }

        var clean = relativePath.Split('?', '#')[0].Replace('\\', '/');
        if (clean.Contains("..", StringComparison.Ordinal))
        {
            return false;
        }

        var fullPath = Path.Combine(
            _webHostEnvironment.WebRootPath,
            clean.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));

        return System.IO.File.Exists(fullPath);
    }

    private static string? SlugifyDishName(string? dishName)
    {
        if (string.IsNullOrWhiteSpace(dishName))
        {
            return null;
        }

        var normalized = dishName.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(normalized.Length);
        var previousDash = false;

        foreach (var ch in normalized)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            var mapped = ch switch
            {
                'đ' or 'Đ' => 'd',
                _ => ch,
            };

            if (char.IsLetterOrDigit(mapped))
            {
                sb.Append(char.ToLowerInvariant(mapped));
                previousDash = false;
            }
            else if (!previousDash)
            {
                sb.Append('-');
                previousDash = true;
            }
        }

        var slug = sb.ToString().Trim('-');
        return slug.Length == 0 ? null : slug;
    }

    private sealed record SendOrderItemDto(int DishID, int Quantity, string? Note);
}
