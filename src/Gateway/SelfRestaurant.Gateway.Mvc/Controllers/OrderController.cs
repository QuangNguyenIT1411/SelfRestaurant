using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Controllers;

public sealed class OrderController : Controller
{
    private readonly OrdersClient _ordersClient;

    public OrderController(OrdersClient ordersClient)
    {
        _ordersClient = ordersClient;
    }

    private bool IsAjaxRequest() =>
        string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);

    [HttpGet]
    public async Task<IActionResult> Index(int? tableId, CancellationToken cancellationToken)
    {
        if (tableId is null)
        {
            tableId = HttpContext.Session.GetInt32(SessionKeys.CurrentTableId);
        }

        if (tableId is null)
        {
            return RedirectToAction("Index", "Home");
        }

        var order = await _ordersClient.GetActiveOrderAsync(tableId.Value, cancellationToken);
        ViewBag.TableId = tableId.Value;
        ViewBag.TableNumber = HttpContext.Session.GetInt32(SessionKeys.CurrentTableNumber) ?? tableId.Value;
        ViewBag.BranchId = HttpContext.Session.GetInt32(SessionKeys.CurrentBranchId);
        ViewBag.CustomerName = HttpContext.Session.GetString(SessionKeys.CustomerName) ?? "";
        ViewBag.LoyaltyPoints = HttpContext.Session.GetInt32(SessionKeys.CustomerLoyaltyPoints) ?? 0;
        return View(order);
    }

    [HttpGet]
    public async Task<IActionResult> ActiveJson(int tableId, CancellationToken cancellationToken)
    {
        var order = await _ordersClient.GetActiveOrderAsync(tableId, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        return Json(order);
    }

    [HttpGet]
    public async Task<IActionResult> GetOrderItems(int tableId, CancellationToken cancellationToken)
    {
        try
        {
            var order = await _ordersClient.GetActiveOrderAsync(tableId, cancellationToken);
            if (order is null)
            {
                return Json(new { success = true, orderId = (int?)null, items = Array.Empty<object>(), subtotal = 0m });
            }

            var items = order.Items.Select(x => new
            {
                id = x.ItemId,
                itemId = x.ItemId,
                dishId = x.DishId,
                dishName = x.DishName,
                quantity = x.Quantity,
                unitPrice = x.UnitPrice,
                lineTotal = x.LineTotal,
                note = x.Note,
                unit = x.Unit,
                image = x.Image
            });

            return Json(new
            {
                success = true,
                orderId = order.OrderId,
                items,
                subtotal = order.Subtotal
            });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddItem(int tableId, int dishId, int quantity, string? note, CancellationToken cancellationToken)
    {
        var isAjax = IsAjaxRequest();

        try
        {
            await _ordersClient.AddItemAsync(tableId, dishId, quantity, note, cancellationToken);
            if (isAjax)
            {
                return Json(new { success = true });
            }

            TempData["Success"] = "Added.";
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { tableId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Submit(int tableId, CancellationToken cancellationToken)
    {
        var isAjax = IsAjaxRequest();

        try
        {
            await _ordersClient.SubmitOrderAsync(tableId, cancellationToken);
            if (isAjax)
            {
                return Json(new { success = true });
            }

            TempData["Success"] = "Submitted to kitchen.";
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { tableId });
    }

    [HttpPost]
    public async Task<IActionResult> SendToKitchen([FromBody] SendToKitchenBody? body, int? tableId, CancellationToken cancellationToken)
    {
        var resolvedTableId = body?.TableId ?? tableId ?? HttpContext.Session.GetInt32(SessionKeys.CurrentTableId);
        if (resolvedTableId is null || resolvedTableId <= 0)
        {
            return Json(new { success = false, message = "Không xác định được bàn hiện tại." });
        }

        try
        {
            await _ordersClient.SubmitOrderAsync(resolvedTableId.Value, cancellationToken);
            return Json(new { success = true, message = "Đã gửi yêu cầu xuống bếp." });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ConfirmReceived(int tableId, int orderId, CancellationToken cancellationToken)
    {
        var isAjax = IsAjaxRequest();

        try
        {
            await _ordersClient.ConfirmOrderReceivedAsync(orderId, cancellationToken);
            if (isAjax)
            {
                return Json(new { success = true });
            }

            TempData["Success"] = "Thanks!";
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { tableId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateQuantity(int tableId, int itemId, int quantity, CancellationToken cancellationToken)
    {
        var isAjax = IsAjaxRequest();

        try
        {
            await _ordersClient.UpdateQuantityAsync(tableId, itemId, quantity, cancellationToken);
            if (isAjax)
            {
                return Json(new { success = true });
            }

            TempData["Success"] = "Updated.";
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { tableId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateItemNote(int tableId, int itemId, string? note, CancellationToken cancellationToken)
    {
        var isAjax = IsAjaxRequest();

        try
        {
            await _ordersClient.UpdateItemNoteAsync(tableId, itemId, note, cancellationToken);
            if (isAjax)
            {
                return Json(new { success = true });
            }

            TempData["Success"] = "Updated.";
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { tableId });
    }

    [HttpPost]
    public async Task<IActionResult> RemoveItem([FromBody] RemoveItemBody? body, int itemId, int? tableId, CancellationToken cancellationToken)
    {
        var resolvedItemId = body?.ItemId ?? itemId;
        var resolvedTableId = body?.TableId ?? tableId ?? HttpContext.Session.GetInt32(SessionKeys.CurrentTableId);
        if (resolvedItemId <= 0)
        {
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Món ăn không hợp lệ." });
            }

            return RedirectToAction(nameof(Index), new { tableId = resolvedTableId });
        }

        if (resolvedTableId is null || resolvedTableId <= 0)
        {
            if (IsAjaxRequest())
            {
                return Json(new { success = false, message = "Không xác định được bàn hiện tại." });
            }

            return RedirectToAction("Index", "Home");
        }

        var isAjax = IsAjaxRequest();

        try
        {
            await _ordersClient.RemoveItemAsync(resolvedTableId.Value, resolvedItemId, cancellationToken);
            if (isAjax)
            {
                return Json(new { success = true });
            }

            TempData["Success"] = "Removed.";
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { tableId = resolvedTableId.Value });
    }

    [HttpPost]
    public async Task<IActionResult> ScanLoyaltyCard([FromBody] ScanLoyaltyCardBody? body, CancellationToken cancellationToken)
    {
        var resolvedTableId = body?.TableId ?? HttpContext.Session.GetInt32(SessionKeys.CurrentTableId);
        if (resolvedTableId is null || resolvedTableId <= 0)
        {
            return Json(new
            {
                success = false,
                message = "Không xác định được bàn hiện tại."
            });
        }

        var phoneNumber = body?.PhoneNumber?.Trim();
        if (string.IsNullOrWhiteSpace(phoneNumber))
        {
            return Json(new
            {
                success = false,
                message = "Vui lòng nhập số điện thoại"
            });
        }

        try
        {
            var response = await _ordersClient.ScanLoyaltyCardAsync(resolvedTableId.Value, phoneNumber, cancellationToken);
            if (response is null)
            {
                return Json(new
                {
                    success = false,
                    message = "Không nhận được phản hồi từ hệ thống."
                });
            }

            return Json(new
            {
                success = response.Success,
                message = response.Message,
                customer = response.Customer is null ? null : new
                {
                    name = response.Customer.Name,
                    phone = response.Customer.Phone,
                    currentPoints = response.Customer.CurrentPoints,
                    cardPoints = response.Customer.CardPoints
                }
            });
        }
        catch (Exception ex)
        {
            return Json(new
            {
                success = false,
                message = ex.Message
            });
        }
    }

    public sealed record SendToKitchenBody(int? TableId);
    public sealed record RemoveItemBody(int? ItemId, int? TableId);
    public sealed record ScanLoyaltyCardBody(int? TableId, string? PhoneNumber);
}
