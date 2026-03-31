using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly CatalogClient _catalogClient;
    private readonly OrdersClient _ordersClient;
    private readonly CustomersClient _customersClient;

    public HomeController(
        ILogger<HomeController> logger,
        CatalogClient catalogClient,
        OrdersClient ordersClient,
        CustomersClient customersClient)
    {
        _logger = logger;
        _catalogClient = catalogClient;
        _ordersClient = ordersClient;
        _customersClient = customersClient;
    }

    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        try
        {
            var branches = await _catalogClient.GetBranchesAsync(cancellationToken);

            if (HttpContext.Session.GetInt32(SessionKeys.CustomerId) is not null)
            {
                await RefreshCustomerSessionAsync(cancellationToken);

                var currentTableId = HttpContext.Session.GetInt32(SessionKeys.CurrentTableId);
                var currentBranchId = HttpContext.Session.GetInt32(SessionKeys.CurrentBranchId);
                if (currentTableId is > 0 && currentBranchId is > 0)
                {
                    try
                    {
                        var branchTables = await _catalogClient.GetBranchTablesAsync(currentBranchId.Value, cancellationToken);
                        var currentTable = branchTables?.Tables?.FirstOrDefault(t => t.TableId == currentTableId.Value);

                        // Chỉ xóa context khi bàn không còn tồn tại.
                        // Nếu bàn đang occupied thì có thể đó vẫn là chính bàn khách đang dùng
                        // và họ cần được phép quay lại từ tab khác trong cùng session trình duyệt.
                        if (currentTable is null)
                        {
                            ClearCurrentTableContextInSession();
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogDebug(ex, "Skip clearing current table context due to temporary catalog lookup issue.");
                    }
                }
            }

            return View(branches);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to load branches.");
            ViewBag.Error = ex.Message;
            return View(Array.Empty<BranchDto>());
        }
    }

    private async Task RefreshCustomerSessionAsync(CancellationToken cancellationToken)
    {
        var customerId = HttpContext.Session.GetInt32(SessionKeys.CustomerId);
        if (customerId is null || customerId <= 0)
        {
            return;
        }

        try
        {
            var profile = await _customersClient.GetCustomerAsync(customerId.Value, cancellationToken);
            if (profile is null)
            {
                return;
            }

            HttpContext.Session.SetString(SessionKeys.CustomerName, profile.Name);
            HttpContext.Session.SetString(SessionKeys.CustomerUsername, profile.Username);
            HttpContext.Session.SetString(SessionKeys.CustomerPhoneNumber, profile.PhoneNumber);
            HttpContext.Session.SetInt32(SessionKeys.CustomerLoyaltyPoints, profile.LoyaltyPoints);

            if (!string.IsNullOrWhiteSpace(profile.Email))
            {
                HttpContext.Session.SetString(SessionKeys.CustomerEmail, profile.Email);
            }
            else
            {
                HttpContext.Session.Remove(SessionKeys.CustomerEmail);
            }
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Skip refreshing customer session profile due to temporary customer service issue.");
        }
    }

    public IActionResult About()
    {
        ViewBag.Title = "Về Chúng Tôi";
        return View();
    }

    public IActionResult Contact()
    {
        ViewBag.Title = "Liên Hệ";
        return View();
    }

    [HttpGet]
    public IActionResult AccessDenied()
    {
        return View("~/Views/Shared/AccessDenied.cshtml");
    }

    [HttpGet]
    public async Task<IActionResult> GetBranchTables(int branchId, CancellationToken cancellationToken)
    {
        if (!HttpContext.Session.TryGetValue(SessionKeys.CustomerId, out _))
        {
            return Json(new { success = false, requiresLogin = true, loginUrl = Url.Action("Login", "Customer") });
        }

        try
        {
            var response = await _catalogClient.GetBranchTablesAsync(branchId, cancellationToken);
            if (response is null)
            {
                return Json(new { success = false, message = "No data." });
            }

            return Json(new { success = true, branchName = response.BranchName, tables = response.Tables });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetBranchTables failed.");
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetOrderStatus(int orderId, CancellationToken cancellationToken)
    {
        if (orderId <= 0)
        {
            return Json(new { success = false, message = "Mã đơn không hợp lệ." });
        }

        try
        {
            var order = await _ordersClient.GetOrderByIdAsync(orderId, cancellationToken);
            if (order is null)
            {
                return Json(new { success = false, message = "Không tìm thấy đơn hàng." });
            }

            var payload = new
            {
                OrderID = order.OrderId,
                OrderCode = order.OrderCode,
                StatusCode = order.StatusCode,
                StatusName = order.OrderStatus,
                Items = order.Items.Select(i => new
                {
                    ItemID = i.ItemId,
                    DishID = i.DishId,
                    DishName = i.DishName,
                    Quantity = i.Quantity,
                    UnitPrice = i.UnitPrice,
                    LineTotal = i.LineTotal,
                    Note = i.Note,
                    Unit = i.Unit,
                    Image = ResolveDishImage(i.Image, i.DishName)
                })
            };

            return Json(new { success = true, order = payload });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetOrderStatus failed. orderId={OrderId}", orderId);
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetTableOrderStatuses(int tableId, CancellationToken cancellationToken)
    {
        if (tableId <= 0)
        {
            return Json(new { success = false, message = "Mã bàn không hợp lệ." });
        }

        try
        {
            var orders = await _ordersClient.GetActiveOrdersAsync(tableId, cancellationToken);
            var payload = orders.Select(order => new
            {
                OrderID = order.OrderId,
                OrderCode = order.OrderCode,
                StatusCode = order.StatusCode,
                StatusName = order.OrderStatus,
                Items = order.Items.Select(i => new
                {
                    ItemID = i.ItemId,
                    DishID = i.DishId,
                    DishName = i.DishName,
                    Quantity = i.Quantity,
                    UnitPrice = i.UnitPrice,
                    LineTotal = i.LineTotal,
                    Note = i.Note,
                    Unit = i.Unit,
                    Image = ResolveDishImage(i.Image, i.DishName)
                })
            });

            return Json(new { success = true, orders = payload });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetTableOrderStatuses failed. tableId={TableId}", tableId);
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ConfirmOrderReceived(int orderId, CancellationToken cancellationToken)
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

        if (orderId <= 0)
        {
            return Json(new { success = false, message = "Mã đơn không hợp lệ." });
        }

        try
        {
            await _ordersClient.ConfirmOrderReceivedAsync(orderId, cancellationToken);
            return Json(new { success = true, message = "Đã xác nhận nhận món thành công." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "ConfirmOrderReceived failed. orderId={OrderId}", orderId);
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

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
