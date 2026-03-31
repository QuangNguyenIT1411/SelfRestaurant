using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Orders.Api.Infrastructure;
using SelfRestaurant.Orders.Api.Infrastructure.Eventing;
using SelfRestaurant.Orders.Api.Persistence;
using SelfRestaurant.Orders.Api.Persistence.Entities;
using OrderEntity = SelfRestaurant.Orders.Api.Persistence.Entities.Orders;

namespace SelfRestaurant.Orders.Api.Controllers;

[ApiController]
public sealed class OrdersController : ControllerBase
{
    private readonly OrdersDbContext _db;
    private readonly CatalogApiClient _catalogApi;
    private readonly IIntegrationEventPublisher _eventPublisher;

    public OrdersController(OrdersDbContext db, CatalogApiClient catalogApi, IIntegrationEventPublisher eventPublisher)
    {
        _db = db;
        _catalogApi = catalogApi;
        _eventPublisher = eventPublisher;
    }

    [HttpPost("api/tables/{tableId:int}/occupy")]
    public async Task<ActionResult> OccupyTable(int tableId, CancellationToken cancellationToken)
    {
        var tableSnapshot = await _catalogApi.GetTableAsync(tableId, cancellationToken);
        var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableId, cancellationToken);
        if (tableSnapshot is null || table is null)
        {
            return NotFound();
        }

        var occupiedId = await GetTableStatusIdAsync("OCCUPIED", cancellationToken);
        if (occupiedId is not null)
        {
            table.StatusID = occupiedId.Value;
            table.UpdatedAt = DateTime.Now;
            await _db.SaveChangesAsync(cancellationToken);
        }

        return NoContent();
    }

    [HttpPost("api/tables/{tableId:int}/reset")]
    public async Task<ActionResult> ResetTable(int tableId, CancellationToken cancellationToken)
    {
        var tableSnapshot = await _catalogApi.GetTableAsync(tableId, cancellationToken);
        var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableId, cancellationToken);
        if (tableSnapshot is null || table is null)
        {
            return NotFound();
        }

        var activeOrders = await _db.Orders
            .Where(x => x.TableID == tableId && (x.IsActive ?? true))
            .ToListAsync(cancellationToken);

        foreach (var order in activeOrders)
        {
            order.IsActive = false;
            order.CompletedTime = DateTime.Now;
        }

        var availableId = await GetTableStatusIdAsync("AVAILABLE", cancellationToken);
        if (availableId is not null)
        {
            table.StatusID = availableId.Value;
            table.UpdatedAt = DateTime.Now;
        }

        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpGet("api/tables/{tableId:int}/order")]
    public async Task<ActionResult<object>> GetActiveOrder(int tableId, CancellationToken cancellationToken)
    {
        var order = await GetOrCreateOrderAsync(tableId, createIfMissing: false, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        return Ok(await BuildActiveOrderResponseAsync(order, cancellationToken));
    }

    [HttpGet("api/orders/{orderId:int}")]
    public async Task<ActionResult<object>> GetOrderById(int orderId, CancellationToken cancellationToken)
    {
        var order = await _db.Orders
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.OrderID == orderId, cancellationToken);

        if (order is null)
        {
            return NotFound();
        }

        return Ok(await BuildActiveOrderResponseAsync(order, cancellationToken));
    }

    [HttpGet("api/tables/{tableId:int}/orders/active")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetActiveOrders(int tableId, CancellationToken cancellationToken)
    {
        var orders = await _db.Orders
            .AsNoTracking()
            .Where(x => x.TableID == tableId && (x.IsActive ?? true))
            .OrderBy(x => x.OrderTime)
            .ToListAsync(cancellationToken);

        if (orders.Count == 0)
        {
            return Ok(Array.Empty<object>());
        }

        var payload = new List<object>(orders.Count);
        foreach (var order in orders)
        {
            payload.Add(await BuildActiveOrderResponseAsync(order, cancellationToken));
        }

        return Ok(payload);
    }

    [HttpPost("api/tables/{tableId:int}/order/items")]
    public async Task<ActionResult<object>> AddItem(int tableId, [FromBody] AddItemRequest request, CancellationToken cancellationToken)
    {
        if (request.Quantity <= 0)
        {
            return BadRequest("Quantity must be > 0.");
        }
        var dishSnapshot = await _catalogApi.GetDishAsync(request.DishId, cancellationToken);
        if (dishSnapshot is null || !dishSnapshot.IsActive || !dishSnapshot.Available)
        {
            return NotFound("Dish not found.");
        }

        var order = await GetOrCreateOrderAsync(tableId, createIfMissing: true, cancellationToken);
        if (order is null)
        {
            return NotFound("Table not found.");
        }

        var item = await _db.OrderItems
            .FirstOrDefaultAsync(x => x.OrderID == order.OrderID && x.DishID == request.DishId && x.Note == request.Note, cancellationToken);

        if (item is null)
        {
            item = new OrderItems
            {
                OrderID = order.OrderID,
                DishID = request.DishId,
                Quantity = request.Quantity,
                UnitPrice = dishSnapshot.Price,
                LineTotal = dishSnapshot.Price * request.Quantity,
                Note = request.Note,
            };
            _db.OrderItems.Add(item);
        }
        else
        {
            item.Quantity += request.Quantity;
            item.LineTotal = item.UnitPrice * item.Quantity;
        }

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(await BuildActiveOrderResponseAsync(order, cancellationToken));
    }

    [HttpPut("api/tables/{tableId:int}/order/items/{itemId:int}")]
    public async Task<ActionResult> UpdateQuantity(int tableId, int itemId, [FromBody] UpdateQuantityRequest request, CancellationToken cancellationToken)
    {
        var order = await GetOrCreateOrderAsync(tableId, createIfMissing: false, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var item = await _db.OrderItems.FirstOrDefaultAsync(x => x.ItemID == itemId && x.OrderID == order.OrderID, cancellationToken);
        if (item is null)
        {
            return NotFound();
        }

        var statusCode = await GetOrderStatusCodeAsync(order.StatusID, cancellationToken);
        if (!string.Equals(statusCode, "PENDING", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest("Không thể cập nhật món đã gửi bếp");
        }

        if (request.Quantity <= 0)
        {
            return BadRequest("Số lượng phải lớn hơn 0");
        }

        item.Quantity = request.Quantity;
        item.LineTotal = item.UnitPrice * item.Quantity;

        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpDelete("api/tables/{tableId:int}/order/items/{itemId:int}")]
    public async Task<ActionResult> RemoveItem(int tableId, int itemId, CancellationToken cancellationToken)
    {
        var order = await GetOrCreateOrderAsync(tableId, createIfMissing: false, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var item = await _db.OrderItems.FirstOrDefaultAsync(x => x.ItemID == itemId && x.OrderID == order.OrderID, cancellationToken);
        if (item is null)
        {
            return NotFound();
        }

        var statusCode = await GetOrderStatusCodeAsync(order.StatusID, cancellationToken);
        if (!string.Equals(statusCode, "PENDING", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest("Không thể xóa món đã gửi bếp");
        }

        var itemCountBeforeDelete = await _db.OrderItems
            .AsNoTracking()
            .Where(x => x.OrderID == order.OrderID)
            .CountAsync(cancellationToken);

        _db.OrderItems.Remove(item);
        await _db.SaveChangesAsync(cancellationToken);

        if (itemCountBeforeDelete <= 1)
        {
            order.IsActive = false;
            order.CompletedTime ??= DateTime.Now;

            if (order.TableID is int tableIdValue)
            {
                var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableIdValue, cancellationToken);
                var availableId = await GetTableStatusIdAsync("AVAILABLE", cancellationToken);
                if (table is not null && availableId is not null)
                {
                    table.StatusID = availableId.Value;
                    table.CurrentOrderID = null;
                    table.UpdatedAt = DateTime.Now;
                }
            }

            await _db.SaveChangesAsync(cancellationToken);
        }

        return NoContent();
    }

    [HttpPut("api/tables/{tableId:int}/order/items/{itemId:int}/note")]
    public async Task<ActionResult> UpdateItemNote(
        int tableId,
        int itemId,
        [FromBody] UpdateItemNoteRequest request,
        CancellationToken cancellationToken)
    {
        var order = await GetOrCreateOrderAsync(tableId, createIfMissing: false, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var statusCode = await _db.OrderStatus
            .Where(s => s.StatusID == order.StatusID)
            .Select(s => s.StatusCode)
            .FirstOrDefaultAsync(cancellationToken);

        if (!string.Equals(statusCode, "PENDING", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest("Only pending order items can be edited by customer.");
        }

        var item = await _db.OrderItems
            .FirstOrDefaultAsync(x => x.ItemID == itemId && x.OrderID == order.OrderID, cancellationToken);
        if (item is null)
        {
            return NotFound();
        }

        item.Note = NormalizeNote(request.Note);
        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpPost("api/tables/{tableId:int}/order/submit")]
    public async Task<ActionResult> SubmitOrder(int tableId, CancellationToken cancellationToken)
    {
        var order = await GetOrCreateOrderAsync(tableId, createIfMissing: false, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var statusCode = await GetOrderStatusCodeAsync(order.StatusID, cancellationToken);
        if (!string.Equals(statusCode, "PENDING", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest("Đơn hàng đã được gửi");
        }

        var itemCount = await _db.OrderItems.CountAsync(x => x.OrderID == order.OrderID, cancellationToken);
        if (itemCount == 0)
        {
            return BadRequest("Đơn hàng trống");
        }

        var statusId = await GetOrderStatusIdAsync("CONFIRMED", cancellationToken);
        if (statusId is not null)
        {
            order.StatusID = statusId.Value;
            await _db.SaveChangesAsync(cancellationToken);
            await PublishOrderEventAsync("order.submitted.v1", order, new
            {
                orderId = order.OrderID,
                orderCode = order.OrderCode,
                tableId = order.TableID,
                customerId = order.CustomerID,
                statusCode = "CONFIRMED"
            }, cancellationToken);
        }

        return NoContent();
    }

    [HttpPost("api/tables/{tableId:int}/order/scan-loyalty-card")]
    public async Task<ActionResult<object>> ScanLoyaltyCard(
        int tableId,
        [FromBody] ScanLoyaltyCardRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.PhoneNumber))
        {
            return Ok(new
            {
                success = false,
                message = "Vui lòng nhập số điện thoại"
            });
        }

        var phoneNumber = request.PhoneNumber.Trim();
        var customer = await _db.Customers
            .Include(c => c.LoyaltyCards)
            .FirstOrDefaultAsync(c => c.PhoneNumber == phoneNumber && (c.IsActive ?? true), cancellationToken);

        if (customer is null)
        {
            return Ok(new
            {
                success = false,
                message = "Không tìm thấy khách hàng với số điện thoại này"
            });
        }

        var order = await _db.Orders
            .FirstOrDefaultAsync(o => o.TableID == tableId && (o.IsActive ?? true), cancellationToken);
        if (order is null)
        {
            return Ok(new
            {
                success = false,
                message = "Không tìm thấy đơn hàng"
            });
        }

        order.CustomerID = customer.CustomerID;
        await _db.SaveChangesAsync(cancellationToken);

        var loyaltyCard = customer.LoyaltyCards
            .Where(lc => lc.IsActive == true)
            .OrderByDescending(lc => lc.IssueDate)
            .FirstOrDefault();

        return Ok(new
        {
            success = true,
            message = "Đã quét thẻ thành công",
            customer = new
            {
                name = customer.Name,
                phone = customer.PhoneNumber,
                currentPoints = customer.LoyaltyPoints ?? 0,
                cardPoints = loyaltyCard?.Points ?? 0
            }
        });
    }

    [HttpPost("api/orders/{orderId:int}/confirm-received")]
    public async Task<ActionResult> ConfirmReceived(int orderId, CancellationToken cancellationToken)
    {
        var order = await _db.Orders.FirstOrDefaultAsync(x => x.OrderID == orderId, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var currentStatus = await GetOrderStatusCodeAsync(order.StatusID, cancellationToken);
        if (string.Equals(currentStatus, "SERVING", StringComparison.OrdinalIgnoreCase))
        {
            // Idempotent call: already confirmed by customer.
            return NoContent();
        }

        if (!string.Equals(currentStatus, "READY", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest("Chỉ có thể xác nhận nhận món khi đơn ở trạng thái READY.");
        }

        // Customer confirms pickup: keep order active for cashier checkout,
        // and keep table occupied until payment is completed at cashier.
        var servingId = await GetOrderStatusIdAsync("SERVING", cancellationToken);
        if (servingId is null)
        {
            return BadRequest("Status 'SERVING' is missing.");
        }

        order.StatusID = servingId.Value;
        order.IsActive = true;

        await _db.SaveChangesAsync(cancellationToken);
        await PublishOrderEventAsync("order.received-confirmed.v1", order, new
        {
            orderId = order.OrderID,
            orderCode = order.OrderCode,
            tableId = order.TableID,
            customerId = order.CustomerID,
            statusCode = "SERVING"
        }, cancellationToken);
        return NoContent();
    }

    [HttpPost("api/orders/{orderId:int}/billing/complete")]
    public async Task<ActionResult> CompleteCheckout(
        int orderId,
        [FromBody] CompleteCheckoutRequest request,
        CancellationToken cancellationToken)
    {
        var order = await _db.Orders.FirstOrDefaultAsync(o => o.OrderID == orderId, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var completedId = await GetOrderStatusIdAsync("COMPLETED", cancellationToken);
        if (completedId is null)
        {
            return BadRequest("Status 'COMPLETED' is missing.");
        }

        order.StatusID = completedId.Value;
        order.IsActive = false;
        order.CompletedTime ??= DateTime.Now;
        order.CashierID = request.CashierId > 0 ? request.CashierId : order.CashierID;

        if (order.TableID is int tableId)
        {
            var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableId, cancellationToken);
            var availableId = await GetTableStatusIdAsync("AVAILABLE", cancellationToken);
            if (table is not null && availableId is not null)
            {
                table.StatusID = availableId.Value;
                table.UpdatedAt = DateTime.Now;
                table.CurrentOrderID = null;
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
        await PublishOrderEventAsync("order.checkout-completed.v1", order, new
        {
            orderId = order.OrderID,
            orderCode = order.OrderCode,
            tableId = order.TableID,
            customerId = order.CustomerID,
            cashierId = order.CashierID,
            statusCode = "COMPLETED"
        }, cancellationToken);
        return NoContent();
    }

    [HttpGet("api/branches/{branchId:int}/top-dishes")]
    public async Task<ActionResult<IReadOnlyList<int>>> GetTopDishes(int branchId, [FromQuery] int count = 5, CancellationToken cancellationToken = default)
    {
        var ids = await _db.OrderItems
            .AsNoTracking()
            .Join(_db.Orders.AsNoTracking(), i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Join(_db.DiningTables.AsNoTracking(), x => x.o.TableID, t => t.TableID, (x, t) => new { x.i, x.o, t })
            .Where(x => x.t.BranchID == branchId)
            .GroupBy(x => x.i.DishID)
            .Select(g => new { dishId = g.Key, qty = g.Sum(x => x.i.Quantity) })
            .OrderByDescending(x => x.qty)
            .Take(Math.Clamp(count, 1, 20))
            .Select(x => x.dishId)
            .ToListAsync(cancellationToken);

        return Ok(ids);
    }

    [HttpGet("api/admin/stats")]
    public async Task<ActionResult<object>> GetAdminStats([FromQuery] DateOnly? date, CancellationToken cancellationToken)
    {
        var targetDate = date ?? DateOnly.FromDateTime(DateTime.Now);
        var from = targetDate.ToDateTime(TimeOnly.MinValue);
        var to = from.AddDays(1);

        var todayOrders = await _db.Orders.CountAsync(x => x.OrderTime >= from && x.OrderTime < to, cancellationToken);
        var pendingOrders = await _db.Orders
            .Join(_db.OrderStatus, o => o.StatusID, s => s.StatusID, (o, s) => new { o, s })
            .CountAsync(x => x.o.OrderTime >= from && x.o.OrderTime < to && x.s.StatusCode == "PENDING", cancellationToken);

        var completedRevenue = await _db.OrderItems
            .Join(_db.Orders, i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Join(_db.OrderStatus, x => x.o.StatusID, s => s.StatusID, (x, s) => new { x.i, x.o, s })
            .Where(x => x.o.OrderTime >= from && x.o.OrderTime < to && x.s.StatusCode == "COMPLETED")
            .SumAsync(x => (decimal?)x.i.LineTotal, cancellationToken) ?? 0m;

        return Ok(new
        {
            todayOrders,
            pendingOrders,
            todayRevenue = completedRevenue,
        });
    }

    [HttpGet("api/admin/reports/revenue")]
    public async Task<ActionResult<AdminRevenueReportResponse>> GetAdminRevenueReport(
        [FromQuery] int days = 30,
        CancellationToken cancellationToken = default)
    {
        days = Math.Clamp(days, 1, 365);
        var from = DateTime.Today.AddDays(-(days - 1));

        var totalRevenue = await _db.OrderItems
            .AsNoTracking()
            .Join(_db.Orders.AsNoTracking(), i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Where(x => x.o.OrderTime >= from)
            .SumAsync(x => (decimal?)x.i.LineTotal, cancellationToken) ?? 0m;

        var rawRows = await _db.OrderItems
            .AsNoTracking()
            .Join(_db.Orders.AsNoTracking(), i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Join(_db.DiningTables.AsNoTracking(), x => x.o.TableID, t => t.TableID, (x, t) => new { x.i, x.o, t })
            .Join(_db.Branches.AsNoTracking(), x => x.t.BranchID, b => b.BranchID, (x, b) => new
            {
                x.o.OrderID,
                x.o.OrderTime,
                BranchId = b.BranchID,
                BranchName = b.Name,
                Revenue = x.i.LineTotal
            })
            .Where(x => x.OrderTime >= from)
            .ToListAsync(cancellationToken);

        var rows = rawRows
            .GroupBy(x => new { Date = DateOnly.FromDateTime(x.OrderTime), x.BranchId, x.BranchName })
            .Select(g => new AdminRevenueRowResponse(
                g.Key.Date,
                g.Key.BranchId,
                g.Key.BranchName,
                g.Select(x => x.OrderID).Distinct().Count(),
                g.Sum(x => x.Revenue)))
            .OrderByDescending(x => x.Date)
            .ThenBy(x => x.BranchName)
            .Take(500)
            .ToList();

        return Ok(new AdminRevenueReportResponse(totalRevenue, rows));
    }

    [HttpGet("api/admin/reports/top-dishes")]
    public async Task<ActionResult<AdminTopDishReportResponse>> GetAdminTopDishesReport(
        [FromQuery] int days = 30,
        [FromQuery] int take = 10,
        CancellationToken cancellationToken = default)
    {
        days = Math.Clamp(days, 1, 365);
        take = Math.Clamp(take, 1, 50);
        var from = DateTime.Today.AddDays(-(days - 1));

        var rawItems = await _db.OrderItems
            .AsNoTracking()
            .Include(i => i.Dish)
                .ThenInclude(d => d.Category)
            .Join(_db.Orders.AsNoTracking(), i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Where(x => x.o.OrderTime >= from)
            .Select(x => new
            {
                x.i.DishID,
                DishName = x.i.Dish.Name,
                CategoryName = x.i.Dish.Category != null ? x.i.Dish.Category.Name : "Khac",
                x.i.Quantity,
                x.i.LineTotal
            })
            .ToListAsync(cancellationToken);

        var items = rawItems
            .GroupBy(x => new { x.DishID, x.DishName, x.CategoryName })
            .Select(g => new AdminTopDishReportItemResponse(
                g.Key.DishID,
                g.Key.DishName,
                g.Key.CategoryName,
                g.Sum(x => x.Quantity),
                g.Sum(x => x.LineTotal)))
            .OrderByDescending(x => x.TotalQuantity)
            .ThenByDescending(x => x.TotalRevenue)
            .Take(take)
            .ToList();

        return Ok(new AdminTopDishReportResponse(items));
    }

    [HttpGet("api/branches/{branchId:int}/chef/orders")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetChefOrders(
        int branchId,
        [FromQuery] string? status,
        CancellationToken cancellationToken)
    {
        var query = _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Include(o => o.Table)
            .Where(o => (o.IsActive ?? true) && o.Table != null && o.Table.BranchID == branchId)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status))
        {
            var statusCode = status.Trim().ToUpperInvariant();
            query = query.Where(o => o.Status.StatusCode == statusCode);
        }
        else
        {
            query = query.Where(o =>
                o.Status.StatusCode == "PENDING"
                || o.Status.StatusCode == "CONFIRMED"
                || o.Status.StatusCode == "PREPARING"
                || o.Status.StatusCode == "READY");
        }

        var orders = await query
            .OrderBy(o => o.OrderTime)
            .Select(o => new
            {
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                tableId = o.TableID,
                tableName = o.Table!.QRCode ?? ("Bàn " + o.TableID),
                statusCode = o.Status.StatusCode,
                statusName = o.Status.StatusName,
                orderTime = o.OrderTime,
            })
            .ToListAsync(cancellationToken);

        var orderIds = orders.Select(o => o.orderId).ToList();
        var items = await _db.OrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.OrderID))
            .Include(i => i.Dish)
            .OrderBy(i => i.ItemID)
            .Select(i => new
            {
                orderId = i.OrderID,
                itemId = i.ItemID,
                dishName = i.Dish.Name,
                quantity = i.Quantity,
                note = i.Note,
            })
            .ToListAsync(cancellationToken);

        var payload = orders.Select(o => new
        {
            o.orderId,
            o.orderCode,
            o.tableId,
            o.tableName,
            o.statusCode,
            o.statusName,
            o.orderTime,
            items = items.Where(i => i.orderId == o.orderId).ToList(),
        }).ToList();

        return Ok(payload);
    }

    [HttpGet("api/branches/{branchId:int}/chef/history")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetChefHistory(
        int branchId,
        [FromQuery] int take = 50,
        CancellationToken cancellationToken = default)
    {
        take = Math.Clamp(take, 1, 200);

        var orders = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Include(o => o.Table)
            .Where(o => o.Table != null && o.Table.BranchID == branchId)
            .OrderByDescending(o => o.CompletedTime ?? o.OrderTime)
            .Take(take)
            .Select(o => new
            {
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                orderTime = o.OrderTime,
                completedTime = o.CompletedTime,
                tableName = o.Table!.QRCode ?? ("Bàn " + o.TableID),
                statusCode = o.Status.StatusCode,
                statusName = o.Status.StatusName,
            })
            .ToListAsync(cancellationToken);

        var orderIds = orders.Select(o => o.orderId).ToList();
        var items = await _db.OrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.OrderID))
            .Include(i => i.Dish)
            .Select(i => new
            {
                orderId = i.OrderID,
                dishName = i.Dish.Name,
                quantity = i.Quantity,
            })
            .ToListAsync(cancellationToken);

        var payload = orders.Select(o => new
        {
            o.orderId,
            o.orderCode,
            o.orderTime,
            o.completedTime,
            o.tableName,
            o.statusCode,
            o.statusName,
            dishesSummary = string.Join(", ", items.Where(i => i.orderId == o.orderId).Select(i => $"{i.quantity}x {i.dishName}")),
        }).ToList();

        return Ok(payload);
    }

    [HttpPost("api/orders/{orderId:int}/chef/start")]
    public Task<ActionResult> ChefStart(int orderId, CancellationToken cancellationToken) =>
        UpdateOrderStatusAsync(orderId, "PREPARING", cancellationToken);

    [HttpPost("api/orders/{orderId:int}/chef/ready")]
    public Task<ActionResult> ChefReady(int orderId, CancellationToken cancellationToken) =>
        UpdateOrderStatusAsync(orderId, "READY", cancellationToken);

    [HttpPost("api/orders/{orderId:int}/chef/serve")]
    public Task<ActionResult> ChefServe(int orderId, CancellationToken cancellationToken) =>
        UpdateOrderStatusAsync(orderId, "SERVING", cancellationToken);

    [HttpPost("api/orders/{orderId:int}/status")]
    public Task<ActionResult> UpdateStatus(
        int orderId,
        [FromBody] UpdateOrderStatusRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.StatusCode))
        {
            return Task.FromResult<ActionResult>(BadRequest("Missing statusCode."));
        }

        return UpdateOrderStatusAsync(orderId, request.StatusCode.Trim().ToUpperInvariant(), cancellationToken);
    }

    [HttpPost("api/orders/{orderId:int}/cancel")]
    public async Task<ActionResult> CancelOrder(
        int orderId,
        [FromBody] CancelOrderRequest request,
        CancellationToken cancellationToken)
    {
        var order = await _db.Orders.FirstOrDefaultAsync(o => o.OrderID == orderId, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var cancelStatusId = await GetOrderStatusIdAsync("CANCELLED", cancellationToken);
        if (cancelStatusId is null)
        {
            return BadRequest("Status 'CANCELLED' is missing.");
        }

        order.StatusID = cancelStatusId.Value;
        order.IsActive = false;
        order.CompletedTime ??= DateTime.Now;
        if (!string.IsNullOrWhiteSpace(request.Reason))
        {
            var reason = request.Reason.Trim();
            order.Note = string.IsNullOrWhiteSpace(order.Note) ? $"[CANCEL] {reason}" : $"{order.Note} | [CANCEL] {reason}";
        }

        if (order.TableID is int tableId)
        {
            var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableId, cancellationToken);
            var availableId = await GetTableStatusIdAsync("AVAILABLE", cancellationToken);
            if (table is not null && availableId is not null)
            {
                table.StatusID = availableId.Value;
                table.UpdatedAt = DateTime.Now;
                table.CurrentOrderID = null;
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
        await PublishOrderEventAsync("order.cancelled.v1", order, new
        {
            orderId = order.OrderID,
            orderCode = order.OrderCode,
            tableId = order.TableID,
            customerId = order.CustomerID,
            reason = request.Reason,
            statusCode = "CANCELLED"
        }, cancellationToken);
        return NoContent();
    }

    [HttpPut("api/orders/{orderId:int}/items/{itemId:int}/chef-note")]
    public async Task<ActionResult> ChefUpdateItemNote(
        int orderId,
        int itemId,
        [FromBody] UpdateItemNoteRequest request,
        CancellationToken cancellationToken)
    {
        var order = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .FirstOrDefaultAsync(o => o.OrderID == orderId && (o.IsActive ?? true), cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var allowStatuses = new[] { "CONFIRMED", "PREPARING", "READY", "SERVING" };
        if (!allowStatuses.Contains(order.Status.StatusCode))
        {
            return BadRequest("Order is not in chef processing state.");
        }

        var item = await _db.OrderItems
            .FirstOrDefaultAsync(x => x.ItemID == itemId && x.OrderID == orderId, cancellationToken);
        if (item is null)
        {
            return NotFound();
        }

        var incoming = NormalizeNote(request.Note);
        if (request.Append == true && !string.IsNullOrWhiteSpace(incoming))
        {
            var chefNote = $"[BEP] {incoming}";
            item.Note = string.IsNullOrWhiteSpace(item.Note)
                ? chefNote
                : $"{item.Note} | {chefNote}";
        }
        else
        {
            item.Note = incoming;
        }

        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private async Task<OrderEntity?> GetOrCreateOrderAsync(int tableId, bool createIfMissing, CancellationToken cancellationToken)
    {
        var tableSnapshot = await _catalogApi.GetTableAsync(tableId, cancellationToken);
        var table = await _db.DiningTables.FirstOrDefaultAsync(x => x.TableID == tableId && (x.IsActive ?? true), cancellationToken);
        if (tableSnapshot is null || table is null)
        {
            return null;
        }

        var order = await _db.Orders
            .Where(x => x.TableID == tableId && (x.IsActive ?? true))
            .OrderByDescending(x => x.OrderTime)
            .FirstOrDefaultAsync(cancellationToken);

        if (!createIfMissing)
        {
            return order;
        }

        if (order is not null)
        {
            var statusCode = await GetOrderStatusCodeAsync(order.StatusID, cancellationToken);
            if (string.Equals(statusCode, "PENDING", StringComparison.OrdinalIgnoreCase))
            {
                return order;
            }
        }

        var pendingId = await GetOrderStatusIdAsync("PENDING", cancellationToken) ?? 1;
        order = new OrderEntity
        {
            TableID = tableId,
            StatusID = pendingId,
            IsActive = true,
            OrderTime = DateTime.Now,
            OrderCode = await GenerateOrderCodeAsync(cancellationToken),
        };
        _db.Orders.Add(order);
        await _db.SaveChangesAsync(cancellationToken);
        return order;
    }

    private async Task<string> GenerateOrderCodeAsync(CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 30; attempt++)
        {
            var now = DateTime.Now;
            var suffix = Random.Shared.Next(100, 999);
            var code = $"ORD-{now:yyyyMMddHHmmssfff}-{suffix}";
            var exists = await _db.Orders.AnyAsync(o => o.OrderCode == code, cancellationToken);
            if (!exists)
            {
                return code;
            }
        }

        return $"ORD-{DateTime.Now:yyyyMMddHHmmssfff}-{Guid.NewGuid():N}".Substring(0, 36);
    }

    private async Task<int?> GetOrderStatusIdAsync(string statusCode, CancellationToken cancellationToken)
    {
        return await _db.OrderStatus
            .Where(x => x.StatusCode == statusCode)
            .Select(x => (int?)x.StatusID)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<string?> GetOrderStatusCodeAsync(int statusId, CancellationToken cancellationToken)
    {
        return await _db.OrderStatus
            .Where(x => x.StatusID == statusId)
            .Select(x => x.StatusCode)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<int?> GetTableStatusIdAsync(string statusCode, CancellationToken cancellationToken)
    {
        var remote = await _catalogApi.GetTableStatusAsync(statusCode, cancellationToken);
        if (remote is not null)
        {
            return remote.StatusId;
        }

        return await _db.TableStatus
            .Where(x => x.StatusCode == statusCode)
            .Select(x => (int?)x.StatusID)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<object> BuildActiveOrderResponseAsync(OrderEntity order, CancellationToken cancellationToken)
    {
        var status = await _db.OrderStatus
            .AsNoTracking()
            .Select(x => new
            {
                x.StatusID,
                x.StatusCode,
                x.StatusName,
            })
            .FirstOrDefaultAsync(x => x.StatusID == order.StatusID, cancellationToken);

        var rawItems = await _db.OrderItems
            .AsNoTracking()
            .Where(x => x.OrderID == order.OrderID)
            .OrderBy(x => x.ItemID)
            .Select(x => new
            {
                x.ItemID,
                x.DishID,
                x.Quantity,
                x.UnitPrice,
                x.LineTotal,
                x.Note,
            })
            .ToListAsync(cancellationToken);

        var dishIds = rawItems
            .Select(x => x.DishID)
            .Distinct()
            .ToList();

        var dishLookup = dishIds.Count == 0
            ? new Dictionary<int, (string Name, string? Unit, string? Image)>()
            : await _db.Dishes
                .AsNoTracking()
                .Where(x => dishIds.Contains(x.DishID))
                .Select(x => new
                {
                    x.DishID,
                    x.Name,
                    x.Unit,
                    x.Image,
                })
                .ToDictionaryAsync(
                    x => x.DishID,
                    x => (x.Name, x.Unit, x.Image),
                    cancellationToken);

        var items = rawItems.Select(x =>
        {
            dishLookup.TryGetValue(x.DishID, out var dish);
            return new
            {
                itemId = x.ItemID,
                dishId = x.DishID,
                dishName = dish.Name ?? $"Mon #{x.DishID}",
                quantity = x.Quantity,
                unitPrice = x.UnitPrice,
                lineTotal = x.LineTotal,
                note = x.Note,
                unit = dish.Unit,
                image = dish.Image,
                status = (string?)null,
            };
        }).ToList();

        return new
        {
            orderId = order.OrderID,
            orderCode = order.OrderCode,
            tableId = order.TableID,
            statusCode = status?.StatusCode ?? "PENDING",
            orderStatus = status?.StatusName ?? "Pending",
            subtotal = items.Sum(x => x.lineTotal),
            totalItems = items.Sum(x => x.quantity),
            items,
        };
    }

    private async Task<ActionResult> UpdateOrderStatusAsync(int orderId, string statusCode, CancellationToken cancellationToken)
    {
        var order = await _db.Orders.FirstOrDefaultAsync(o => o.OrderID == orderId, cancellationToken);
        if (order is null)
        {
            return NotFound();
        }

        var statusId = await GetOrderStatusIdAsync(statusCode, cancellationToken);
        if (statusId is null)
        {
            return BadRequest($"Status '{statusCode}' is missing.");
        }

        order.StatusID = statusId.Value;
        await _db.SaveChangesAsync(cancellationToken);

        if (string.Equals(statusCode, "READY", StringComparison.OrdinalIgnoreCase)
            || string.Equals(statusCode, "PREPARING", StringComparison.OrdinalIgnoreCase)
            || string.Equals(statusCode, "SERVING", StringComparison.OrdinalIgnoreCase))
        {
            await PublishOrderEventAsync($"order.status-{statusCode.ToLowerInvariant()}.v1", order, new
            {
                orderId = order.OrderID,
                orderCode = order.OrderCode,
                tableId = order.TableID,
                customerId = order.CustomerID,
                statusCode
            }, cancellationToken);
        }

        return NoContent();
    }

    private async Task PublishOrderEventAsync(string eventName, OrderEntity order, object payload, CancellationToken cancellationToken)
    {
        await _eventPublisher.PublishAsync(new IntegrationEventEnvelope(
            EventName: eventName,
            OccurredAtUtc: DateTime.UtcNow,
            Source: "Orders.Api",
            CorrelationId: HttpContext.Response.Headers["X-Correlation-Id"].FirstOrDefault() ?? HttpContext.TraceIdentifier,
            Payload: payload), cancellationToken);
    }

    private static string? NormalizeNote(string? note)
    {
        var cleaned = note?.Trim();
        return string.IsNullOrWhiteSpace(cleaned) ? null : cleaned[..Math.Min(cleaned.Length, 500)];
    }

    public sealed record AddItemRequest(int DishId, int Quantity, string? Note);
    public sealed record UpdateQuantityRequest(int Quantity);
    public sealed record UpdateItemNoteRequest(string? Note, bool? Append);
    public sealed record ScanLoyaltyCardRequest(string? PhoneNumber);
    public sealed record UpdateOrderStatusRequest(string? StatusCode);
    public sealed record CompleteCheckoutRequest(int CashierId);
    public sealed record CancelOrderRequest(string? Reason);
    public sealed record AdminRevenueRowResponse(
        DateOnly Date,
        int BranchId,
        string BranchName,
        int TotalOrders,
        decimal TotalRevenue);
    public sealed record AdminRevenueReportResponse(decimal TotalRevenue, IReadOnlyList<AdminRevenueRowResponse> RevenueByBranchDate);
    public sealed record AdminTopDishReportItemResponse(
        int DishId,
        string DishName,
        string CategoryName,
        int TotalQuantity,
        decimal TotalRevenue);
    public sealed record AdminTopDishReportResponse(IReadOnlyList<AdminTopDishReportItemResponse> Items);
}
