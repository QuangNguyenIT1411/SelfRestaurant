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
    private static readonly string[] ActiveCashierStatuses = ["PENDING", "CONFIRMED", "PREPARING", "READY", "SERVING"];

    private readonly OrdersDbContext _db;
    private readonly ICatalogReadModel _catalogApi;
    private readonly ICustomerLoyaltyReadModel _customersApi;
    private readonly IIntegrationEventPublisher _eventPublisher;
    private readonly IHostEnvironment _environment;

    public OrdersController(OrdersDbContext db, ICatalogReadModel catalogApi, ICustomerLoyaltyReadModel customersApi, IIntegrationEventPublisher eventPublisher, IHostEnvironment environment)
    {
        _db = db;
        _catalogApi = catalogApi;
        _customersApi = customersApi;
        _eventPublisher = eventPublisher;
        _environment = environment;
    }

    [HttpPost("api/tables/{tableId:int}/occupy")]
    public async Task<ActionResult> OccupyTable(int tableId, CancellationToken cancellationToken)
    {
        var tableSnapshot = await _catalogApi.GetTableAsync(tableId, cancellationToken);
        if (tableSnapshot is null)
        {
            return NotFound();
        }

        await _catalogApi.OccupyTableAsync(tableId, currentOrderId: null, cancellationToken);
        return NoContent();
    }

    [HttpPost("api/tables/{tableId:int}/reset")]
    public async Task<ActionResult> ResetTable(int tableId, CancellationToken cancellationToken)
    {
        var tableSnapshot = await _catalogApi.GetTableAsync(tableId, cancellationToken);
        if (tableSnapshot is null)
        {
            return NotFound();
        }

        var activeOrder = await _db.Orders
            .Where(x => x.TableID == tableId && (x.IsActive ?? true))
            .OrderByDescending(x => x.OrderTime)
            .FirstOrDefaultAsync(cancellationToken);

        if (activeOrder is not null)
        {
            var statusCode = await GetOrderStatusCodeAsync(activeOrder.StatusID, cancellationToken);
            if (string.Equals(statusCode, "PENDING", StringComparison.OrdinalIgnoreCase))
            {
                var pendingItems = await _db.OrderItems
                    .Where(x => x.OrderID == activeOrder.OrderID)
                    .ToListAsync(cancellationToken);

                if (pendingItems.Count > 0)
                {
                    _db.OrderItems.RemoveRange(pendingItems);
                }

                _db.Orders.Remove(activeOrder);
                await _db.SaveChangesAsync(cancellationToken);
            }
        }

        await _catalogApi.ReleaseTableAsync(tableId, cancellationToken);
        return NoContent();
    }

    [HttpPost("api/dev/reset-test-state")]
    public async Task<ActionResult<object>> ResetDevTestState(CancellationToken cancellationToken)
    {
        if (!_environment.IsDevelopment())
        {
            return NotFound();
        }

        var orderItems = await _db.OrderItems.ToListAsync(cancellationToken);
        var orders = await _db.Orders.ToListAsync(cancellationToken);
        var outboxEvents = await _db.OutboxEvents.ToListAsync(cancellationToken);
        var inboxEvents = await _db.InboxEvents.ToListAsync(cancellationToken);

        if (orderItems.Count > 0)
        {
            _db.OrderItems.RemoveRange(orderItems);
        }

        if (orders.Count > 0)
        {
            _db.Orders.RemoveRange(orders);
        }

        if (outboxEvents.Count > 0)
        {
            _db.OutboxEvents.RemoveRange(outboxEvents);
        }

        if (inboxEvents.Count > 0)
        {
            _db.InboxEvents.RemoveRange(inboxEvents);
        }

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            success = true,
            clearedOrders = orders.Count,
            clearedOrderItems = orderItems.Count,
            clearedOutboxEvents = outboxEvents.Count,
            clearedInboxEvents = inboxEvents.Count
        });
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

    [HttpGet("api/internal/customers/{customerId:int}/orders")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetCustomerOrderHistory(
        int customerId,
        [FromQuery] int take = 10,
        CancellationToken cancellationToken = default)
    {
        take = Math.Clamp(take, 1, 50);

        var orders = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Where(o => o.CustomerID == customerId)
            .OrderByDescending(o => o.OrderTime)
            .Take(take)
            .Select(o => new
            {
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                orderTime = o.OrderTime,
                statusCode = o.Status.StatusCode,
                orderStatus = o.Status.StatusName
            })
            .ToListAsync(cancellationToken);

        if (orders.Count == 0)
        {
            return Ok(Array.Empty<object>());
        }

        var orderIds = orders.Select(o => o.orderId).ToArray();

        var aggregates = await _db.OrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.OrderID))
            .GroupBy(i => i.OrderID)
            .Select(g => new
            {
                orderId = g.Key,
                totalAmount = g.Sum(x => x.LineTotal),
                itemCount = g.Sum(x => x.Quantity)
            })
            .ToListAsync(cancellationToken);

        var aggregateLookup = aggregates.ToDictionary(
            x => x.orderId,
            x => new { x.totalAmount, x.itemCount });

        var payload = orders.Select(o =>
        {
            var totals = aggregateLookup.GetValueOrDefault(o.orderId);
            return new
            {
                o.orderId,
                o.orderCode,
                o.orderTime,
                o.statusCode,
                o.orderStatus,
                totalAmount = totals?.totalAmount ?? 0m,
                itemCount = totals?.itemCount ?? 0
            };
        }).ToList();

        return Ok(payload);
    }

    [HttpGet("api/internal/customers/{customerId:int}/active-order-context")]
    public async Task<ActionResult<object>> GetCustomerActiveOrderContext(
        int customerId,
        CancellationToken cancellationToken = default)
    {
        if (customerId <= 0)
        {
            return BadRequest();
        }

        var order = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Where(o =>
                o.CustomerID == customerId
                && o.TableID.HasValue
                && (o.IsActive ?? true)
                && ActiveCashierStatuses.Contains(o.Status.StatusCode))
            .OrderByDescending(o => o.OrderTime)
            .FirstOrDefaultAsync(cancellationToken);

        if (order is null || !order.TableID.HasValue)
        {
            return NotFound();
        }

        var table = await _catalogApi.GetTableAsync(order.TableID.Value, cancellationToken);
        if (table is null)
        {
            return NotFound();
        }

        var branch = (await _catalogApi.GetBranchesAsync([table.BranchId], cancellationToken))
            ?.FirstOrDefault(x => x.BranchId == table.BranchId);

        return Ok(new
        {
            orderId = order.OrderID,
            orderCode = order.OrderCode,
            orderTime = order.OrderTime,
            statusCode = order.Status.StatusCode,
            orderStatus = order.Status.StatusName,
            tableId = table.TableId,
            branchId = table.BranchId,
            branchName = branch?.Name,
            tableNumber = table.TableId,
        });
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

        await UpsertOrderItemAsync(order.OrderID, dishSnapshot, request, cancellationToken);

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
                await _catalogApi.ReleaseTableAsync(tableIdValue, cancellationToken);
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

    [HttpPost("api/tables/{tableId:int}/order/submit-batch")]
    public async Task<ActionResult<object>> SubmitOrderBatch(
        int tableId,
        [FromBody] SubmitOrderBatchRequest request,
        CancellationToken cancellationToken)
    {
        var items = (request.Items ?? Array.Empty<AddItemRequest>())
            .Where(x => x.DishId > 0 && x.Quantity > 0)
            .ToList();

        if (items.Count == 0)
        {
            return BadRequest("Đơn hàng trống");
        }

        var tableSnapshot = await _catalogApi.GetTableAsync(tableId, cancellationToken);
        if (tableSnapshot is null)
        {
            return NotFound("Table not found.");
        }

        var existingOrder = await _db.Orders
            .Where(x => x.TableID == tableId && (x.IsActive ?? true))
            .OrderByDescending(x => x.OrderTime)
            .FirstOrDefaultAsync(cancellationToken);

        if (existingOrder is not null)
        {
            var currentStatus = await GetOrderStatusCodeAsync(existingOrder.StatusID, cancellationToken);
            if (string.Equals(currentStatus, "PENDING", StringComparison.OrdinalIgnoreCase))
            {
                var existingItems = await _db.OrderItems
                    .Where(x => x.OrderID == existingOrder.OrderID)
                    .ToListAsync(cancellationToken);

                if (existingItems.Count > 0)
                {
                    _db.OrderItems.RemoveRange(existingItems);
                }

                _db.Orders.Remove(existingOrder);
                await _db.SaveChangesAsync(cancellationToken);
            }
        }

        var order = await CreatePendingOrderAsync(tableId, cancellationToken);

        foreach (var item in items)
        {
            var dishSnapshot = await _catalogApi.GetDishAsync(item.DishId, cancellationToken);
            if (dishSnapshot is null || !dishSnapshot.IsActive || !dishSnapshot.Available)
            {
                return NotFound($"Dish {item.DishId} not found.");
            }

            await UpsertOrderItemAsync(order.OrderID, dishSnapshot, item, cancellationToken);
        }

        if (!string.IsNullOrWhiteSpace(request.CustomerPhoneNumber))
        {
            await AttachCustomerByPhoneAsync(order, request.CustomerPhoneNumber, cancellationToken);
        }

        await _db.SaveChangesAsync(cancellationToken);

        var itemCount = await _db.OrderItems.CountAsync(x => x.OrderID == order.OrderID, cancellationToken);
        if (itemCount == 0)
        {
            return BadRequest("Đơn hàng trống");
        }

        var confirmedId = await GetOrderStatusIdAsync("CONFIRMED", cancellationToken);
        if (confirmedId is null)
        {
            return BadRequest("Status 'CONFIRMED' is missing.");
        }

        order.StatusID = confirmedId.Value;
        await _db.SaveChangesAsync(cancellationToken);

        await PublishOrderEventAsync("order.submitted.v1", order, new
        {
            orderId = order.OrderID,
            orderCode = order.OrderCode,
            tableId = order.TableID,
            customerId = order.CustomerID,
            statusCode = "CONFIRMED"
        }, cancellationToken);

        return Ok(await BuildActiveOrderResponseAsync(order, cancellationToken));
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
        var customer = await _customersApi.GetLoyaltyByPhoneAsync(phoneNumber, cancellationToken);

        if (customer is null)
        {
            return Ok(new
            {
                success = false,
                message = "Không tìm thấy khách hàng với số điện thoại này"
            });
        }

        var order = await GetOrCreateOrderAsync(tableId, createIfMissing: false, cancellationToken);
        if (order is null)
        {
            return Ok(new
            {
                success = false,
                message = "Không tìm thấy đơn hàng"
            });
        }

        AttachCustomer(order, customer.CustomerId);
        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            success = true,
            message = "Đã quét thẻ thành công",
            customer = new
            {
                name = customer.Name,
                phone = customer.Phone,
                currentPoints = customer.CurrentPoints,
                cardPoints = customer.CardPoints
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

    [HttpGet("api/branches/{branchId:int}/top-dishes")]
    public async Task<ActionResult<IReadOnlyList<int>>> GetTopDishes(int branchId, [FromQuery] int count = 5, CancellationToken cancellationToken = default)
    {
        var branchTableIds = await _catalogApi.GetBranchTableIdsAsync(branchId, cancellationToken) ?? Array.Empty<int>();
        if (branchTableIds.Count == 0)
        {
            return Ok(Array.Empty<int>());
        }

        var ids = await _db.OrderItems
            .AsNoTracking()
            .Join(_db.Orders.AsNoTracking(), i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Where(x => x.o.TableID != null && branchTableIds.Contains(x.o.TableID.Value))
            .GroupBy(x => x.i.DishID)
            .Select(g => new { dishId = g.Key, qty = g.Sum(x => x.i.Quantity) })
            .OrderByDescending(x => x.qty)
            .Take(Math.Clamp(count, 1, 20))
            .Select(x => x.dishId)
            .ToListAsync(cancellationToken);

        return Ok(ids);
    }

    [HttpGet("api/internal/branches/{branchId:int}/cashier/orders")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetCashierOrdersInternal(
        int branchId,
        CancellationToken cancellationToken)
    {
        var branchTableIds = await _catalogApi.GetBranchTableIdsAsync(branchId, cancellationToken) ?? Array.Empty<int>();
        if (branchTableIds.Count == 0)
        {
            return Ok(Array.Empty<object>());
        }

        var orders = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Where(o =>
                (o.IsActive ?? false)
                && o.TableID != null
                && branchTableIds.Contains(o.TableID.Value)
                && ActiveCashierStatuses.Contains(o.Status.StatusCode))
            .OrderBy(o => o.OrderTime)
            .Select(o => new
            {
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                orderTime = o.OrderTime,
                tableId = o.TableID,
                customerId = o.CustomerID,
                statusCode = o.Status.StatusCode,
                statusName = o.Status.StatusName,
            })
            .ToListAsync(cancellationToken);

        var orderIds = orders.Select(o => o.orderId).ToList();
        var items = await _db.OrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.OrderID))
            .OrderBy(i => i.OrderID)
            .ThenBy(i => i.ItemID)
            .Select(i => new
            {
                itemId = i.ItemID,
                orderId = i.OrderID,
                dishId = i.DishID,
                quantity = i.Quantity,
                unitPrice = i.UnitPrice,
                lineTotal = i.LineTotal,
                note = i.Note,
            })
            .ToListAsync(cancellationToken);

        var tableLookup = (await _catalogApi.GetTablesAsync(
                orders.Where(x => x.tableId.HasValue).Select(x => x.tableId!.Value),
                cancellationToken)
            ?? Array.Empty<CatalogApiClient.TableSnapshotResponse>())
            .ToDictionary(x => x.TableId);

        var dishLookup = (await _catalogApi.GetDishesAsync(items.Select(x => x.dishId).Distinct(), cancellationToken)
            ?? Array.Empty<CatalogApiClient.DishSnapshotResponse>())
            .ToDictionary(x => x.DishId);

        var itemsByOrder = items
            .GroupBy(i => i.orderId)
            .ToDictionary(g => g.Key, g => g.ToList());

        var payload = orders.Select(o =>
        {
            itemsByOrder.TryGetValue(o.orderId, out var orderItems);
            orderItems ??= [];

            var materializedItems = orderItems.Select(i => new
            {
                itemId = i.itemId,
                orderId = i.orderId,
                dishId = i.dishId,
                dishName = dishLookup.TryGetValue(i.dishId, out var dish) ? dish.Name : $"Món #{i.dishId}",
                quantity = i.quantity,
                unitPrice = i.unitPrice,
                lineTotal = i.lineTotal,
                image = dishLookup.TryGetValue(i.dishId, out var imageDish) ? imageDish.Image : null,
                note = i.note,
            }).ToList();

            var tableName = o.tableId.HasValue && tableLookup.TryGetValue(o.tableId.Value, out var table)
                ? (table.QrCode ?? ("Bàn " + o.tableId.Value))
                : ("Bàn " + (o.tableId?.ToString() ?? "?"));

            return new
            {
                orderId = o.orderId,
                orderCode = o.orderCode,
                orderTime = o.orderTime,
                tableId = o.tableId ?? 0,
                tableName,
                customerId = o.customerId,
                statusCode = o.statusCode,
                statusName = o.statusName,
                subtotal = materializedItems.Sum(x => x.lineTotal),
                itemCount = materializedItems.Sum(x => x.quantity),
                items = materializedItems
            };
        }).ToList();

        return Ok(payload);
    }

    [HttpGet("api/internal/orders/{orderId:int}/checkout-context")]
    public async Task<ActionResult<object>> GetCheckoutContext(int orderId, CancellationToken cancellationToken)
    {
        var order = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Where(o => o.OrderID == orderId)
            .Select(o => new
            {
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                tableId = o.TableID,
                customerId = o.CustomerID,
                statusCode = o.Status.StatusCode,
                statusName = o.Status.StatusName,
                isActive = o.IsActive ?? false,
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (order is null)
        {
            return NotFound();
        }

        CatalogApiClient.TableSnapshotResponse? table = null;
        CatalogApiClient.BranchSnapshotResponse? branch = null;
        if (order.tableId is int tableId)
        {
            table = await _catalogApi.GetTableAsync(tableId, cancellationToken);
            if (table is not null)
            {
                branch = (await _catalogApi.GetBranchesAsync(new[] { table.BranchId }, cancellationToken))
                    ?.FirstOrDefault();
            }
        }

        var subtotal = await _db.OrderItems
            .AsNoTracking()
            .Where(oi => oi.OrderID == orderId)
            .SumAsync(oi => (decimal?)oi.LineTotal, cancellationToken) ?? 0m;

        return Ok(new
        {
            order.orderId,
            order.orderCode,
            order.tableId,
            tableName = table?.QrCode ?? (order.tableId.HasValue ? ("Bàn " + order.tableId.Value) : null),
            branchId = table?.BranchId,
            branchName = branch?.Name,
            order.customerId,
            order.statusCode,
            order.statusName,
            order.isActive,
            subtotal
        });
    }

    [HttpGet("api/internal/orders:bill-context")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetOrderBillContexts([FromQuery] int[]? ids, CancellationToken cancellationToken)
    {
        var orderIds = (ids ?? Array.Empty<int>())
            .Where(x => x > 0)
            .Distinct()
            .ToArray();

        if (orderIds.Length == 0)
        {
            return Ok(Array.Empty<object>());
        }

        var orders = await _db.Orders
            .AsNoTracking()
            .Where(o => orderIds.Contains(o.OrderID))
            .Select(o => new
            {
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                tableId = o.TableID,
            })
            .ToListAsync(cancellationToken);

        var tableLookup = (await _catalogApi.GetTablesAsync(
                orders.Where(x => x.tableId.HasValue).Select(x => x.tableId!.Value),
                cancellationToken)
            ?? Array.Empty<CatalogApiClient.TableSnapshotResponse>())
            .ToDictionary(x => x.TableId);

        var branchLookup = (await _catalogApi.GetBranchesAsync(
                tableLookup.Values.Select(x => x.BranchId),
                cancellationToken)
            ?? Array.Empty<CatalogApiClient.BranchSnapshotResponse>())
            .ToDictionary(x => x.BranchId);

        var payload = orders.Select(o =>
        {
            CatalogApiClient.TableSnapshotResponse? table = null;
            CatalogApiClient.BranchSnapshotResponse? branch = null;

            if (o.tableId.HasValue && tableLookup.TryGetValue(o.tableId.Value, out var foundTable))
            {
                table = foundTable;
                branchLookup.TryGetValue(foundTable.BranchId, out branch);
            }

            return new
            {
                orderId = o.orderId,
                orderCode = o.orderCode,
                tableId = o.tableId,
                tableName = table?.QrCode ?? ("Bàn " + (o.tableId?.ToString() ?? "?")),
                branchId = table?.BranchId,
                branchName = branch?.Name
            };
        }).ToList();

        return Ok(payload);
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

        var orderRows = await _db.OrderItems
            .AsNoTracking()
            .Join(_db.Orders.AsNoTracking(), i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Select(x => new
            {
                x.o.OrderID,
                x.o.OrderTime,
                x.o.TableID,
                Revenue = x.i.LineTotal
            })
            .Where(x => x.OrderTime >= from)
            .ToListAsync(cancellationToken);

        var tableLookup = (await _catalogApi.GetTablesAsync(
                orderRows.Where(x => x.TableID.HasValue).Select(x => x.TableID!.Value),
                cancellationToken)
            ?? Array.Empty<CatalogApiClient.TableSnapshotResponse>())
            .ToDictionary(x => x.TableId);

        var branchLookup = (await _catalogApi.GetBranchesAsync(
                tableLookup.Values.Select(x => x.BranchId),
                cancellationToken)
            ?? Array.Empty<CatalogApiClient.BranchSnapshotResponse>())
            .ToDictionary(x => x.BranchId);

        var rawRows = orderRows
            .Where(x => x.TableID.HasValue && tableLookup.ContainsKey(x.TableID.Value))
            .Select(x =>
            {
                var table = tableLookup[x.TableID!.Value];
                branchLookup.TryGetValue(table.BranchId, out var branch);
                return new
                {
                    x.OrderID,
                    x.OrderTime,
                    BranchId = table.BranchId,
                    BranchName = branch?.Name ?? $"Chi nhánh {table.BranchId}",
                    x.Revenue
                };
            })
            .ToList();

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
            .Join(_db.Orders.AsNoTracking(), i => i.OrderID, o => o.OrderID, (i, o) => new { i, o })
            .Where(x => x.o.OrderTime >= from)
            .Select(x => new
            {
                x.i.DishID,
                x.i.Quantity,
                x.i.LineTotal
            })
            .ToListAsync(cancellationToken);

        var dishLookup = (await _catalogApi.GetDishesAsync(rawItems.Select(x => x.DishID).Distinct(), cancellationToken)
            ?? Array.Empty<CatalogApiClient.DishSnapshotResponse>())
            .ToDictionary(x => x.DishId);

        var items = rawItems
            .Select(x =>
            {
                dishLookup.TryGetValue(x.DishID, out var dish);
                return new
                {
                    x.DishID,
                    DishName = dish?.Name ?? $"Món #{x.DishID}",
                    CategoryName = string.IsNullOrWhiteSpace(dish?.CategoryName) ? "Khác" : dish!.CategoryName!,
                    x.Quantity,
                    x.LineTotal
                };
            })
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
            .Where(o => (o.IsActive ?? true))
            .AsQueryable();

        var branchTableIds = await _catalogApi.GetBranchTableIdsAsync(branchId, cancellationToken) ?? Array.Empty<int>();
        query = query.Where(o => o.TableID != null && branchTableIds.Contains(o.TableID.Value));

        if (!string.IsNullOrWhiteSpace(status))
        {
            var statusCode = status.Trim().ToUpperInvariant();
            query = query.Where(o => o.Status.StatusCode == statusCode);
        }
        else
        {
            query = query.Where(o =>
                o.Status.StatusCode == "CONFIRMED"
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
                statusCode = o.Status.StatusCode,
                statusName = o.Status.StatusName,
                orderTime = o.OrderTime,
            })
            .ToListAsync(cancellationToken);

        var tableLookup = (await _catalogApi.GetTablesAsync(
                orders.Where(x => x.tableId.HasValue).Select(x => x.tableId!.Value),
                cancellationToken)
            ?? Array.Empty<CatalogApiClient.TableSnapshotResponse>())
            .ToDictionary(x => x.TableId);

        var orderIds = orders.Select(o => o.orderId).ToList();
        var items = await _db.OrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.OrderID))
            .OrderBy(i => i.ItemID)
            .Select(i => new
            {
                orderId = i.OrderID,
                itemId = i.ItemID,
                dishId = i.DishID,
                quantity = i.Quantity,
                note = i.Note,
            })
            .ToListAsync(cancellationToken);

        var dishLookup = (await _catalogApi.GetDishesAsync(items.Select(x => x.dishId).Distinct(), cancellationToken)
            ?? Array.Empty<CatalogApiClient.DishSnapshotResponse>())
            .ToDictionary(x => x.DishId);

        var payload = orders.Select(o => new
        {
            o.orderId,
            o.orderCode,
            o.tableId,
            tableName = o.tableId.HasValue && tableLookup.TryGetValue(o.tableId.Value, out var table)
                ? (table.QrCode ?? ("Bàn " + o.tableId.Value))
                : ("Bàn " + (o.tableId?.ToString() ?? "?")),
            o.statusCode,
            o.statusName,
            o.orderTime,
            items = items.Where(i => i.orderId == o.orderId).Select(i => new
            {
                i.orderId,
                i.itemId,
                i.dishId,
                dishName = dishLookup.TryGetValue(i.dishId, out var dish) ? dish.Name : $"Món #{i.dishId}",
                i.quantity,
                i.note,
            }).ToList(),
        }).ToList();

        return Ok(payload);
    }

    [HttpGet("api/branches/{branchId:int}/chef/history")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetChefHistory(
        int branchId,
        [FromQuery] int take = 50,
        CancellationToken cancellationToken = default)
    {
        var payload = await BuildChefHistoryAsync(branchId, days: 365, Math.Clamp(take, 1, 200), cancellationToken);

        return Ok(payload.Select(o => new
        {
            o.OrderId,
            o.OrderCode,
            o.OrderTime,
            o.CompletedTime,
            o.TableName,
            o.StatusCode,
            o.StatusName,
            o.DishesSummary,
        }).ToList());
    }

    [HttpGet("api/internal/branches/{branchId:int}/chef/history")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetInternalChefHistory(
        int branchId,
        [FromQuery] int days = 90,
        [FromQuery] int take = 200,
        CancellationToken cancellationToken = default)
    {
        var payload = await BuildChefHistoryAsync(branchId, days, take, cancellationToken);
        return Ok(payload);
    }

    private async Task<IReadOnlyList<ChefHistoryItemResponse>> BuildChefHistoryAsync(
        int branchId,
        int days,
        int take,
        CancellationToken cancellationToken)
    {
        days = Math.Clamp(days, 1, 365);
        take = Math.Clamp(take, 1, 500);
        var fromDate = DateTime.Today.AddDays(-days);

        var orders = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Where(o => o.TableID != null && o.OrderTime >= fromDate)
            .OrderByDescending(o => o.CompletedTime ?? o.OrderTime)
            .Take(take)
            .Select(o => new
            {
                orderId = o.OrderID,
                orderCode = o.OrderCode,
                orderTime = o.OrderTime,
                completedTime = o.CompletedTime,
                tableId = o.TableID,
                statusCode = o.Status.StatusCode,
                statusName = o.Status.StatusName,
            })
            .ToListAsync(cancellationToken);

        var branchTableIds = await _catalogApi.GetBranchTableIdsAsync(branchId, cancellationToken) ?? Array.Empty<int>();
        var filteredOrders = orders
            .Where(o => o.tableId.HasValue && branchTableIds.Contains(o.tableId.Value))
            .ToList();

        var tableLookup = (await _catalogApi.GetTablesAsync(
                filteredOrders.Where(x => x.tableId.HasValue).Select(x => x.tableId!.Value),
                cancellationToken)
            ?? Array.Empty<CatalogApiClient.TableSnapshotResponse>())
            .ToDictionary(x => x.TableId);

        var branchName = (await _catalogApi.GetBranchesAsync(new[] { branchId }, cancellationToken))
            ?.FirstOrDefault()?.Name ?? $"Chi nhánh {branchId}";

        var orderIds = filteredOrders.Select(o => o.orderId).ToList();
        var items = await _db.OrderItems
            .AsNoTracking()
            .Where(i => orderIds.Contains(i.OrderID))
            .Select(i => new
            {
                orderId = i.OrderID,
                dishId = i.DishID,
                quantity = i.Quantity,
            })
            .ToListAsync(cancellationToken);

        var dishLookup = (await _catalogApi.GetDishesAsync(items.Select(x => x.dishId).Distinct(), cancellationToken)
            ?? Array.Empty<CatalogApiClient.DishSnapshotResponse>())
            .ToDictionary(x => x.DishId);

        return filteredOrders.Select(o => new ChefHistoryItemResponse(
            o.orderId,
            o.orderCode,
            o.orderTime,
            o.completedTime,
            o.tableId.HasValue && tableLookup.TryGetValue(o.tableId.Value, out var table)
                ? (table.QrCode ?? ("Bàn " + o.tableId.Value))
                : ("Bàn " + (o.tableId?.ToString() ?? "?")),
            branchName,
            o.statusCode,
            o.statusName,
            string.Join(", ", items.Where(i => i.orderId == o.orderId).Select(i =>
            {
                var dishName = dishLookup.TryGetValue(i.dishId, out var dish) ? dish.Name : $"Món #{i.dishId}";
                return $"{i.quantity}x {dishName}";
            })))).ToList();
    }

    [HttpPost("api/orders/{orderId:int}/chef/start")]
    public Task<ActionResult> ChefStart(int orderId, CancellationToken cancellationToken) =>
        UpdateOrderStatusAsync(orderId, "PREPARING", cancellationToken);

    [HttpPost("api/orders/{orderId:int}/chef/ready")]
    public Task<ActionResult> ChefReady(int orderId, CancellationToken cancellationToken) =>
        UpdateOrderStatusAsync(orderId, "READY", cancellationToken);

    [HttpPost("api/orders/{orderId:int}/chef/serve")]
    public ActionResult ChefServe(int orderId, CancellationToken cancellationToken) =>
        BadRequest("Chef khong the xac nhan da phuc vu. Khach hang se tu xac nhan khi da nhan mon.");

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
            await _catalogApi.ReleaseTableAsync(tableId, cancellationToken);
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
        if (tableSnapshot is null)
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

        return await CreatePendingOrderAsync(tableId, cancellationToken);
    }

    private async Task<OrderEntity> CreatePendingOrderAsync(int tableId, CancellationToken cancellationToken)
    {
        var pendingId = await GetOrderStatusIdAsync("PENDING", cancellationToken) ?? 1;
        var order = new OrderEntity
        {
            TableID = tableId,
            StatusID = pendingId,
            IsActive = true,
            OrderTime = DateTime.Now,
            OrderCode = await GenerateOrderCodeAsync(cancellationToken),
        };
        _db.Orders.Add(order);
        await _db.SaveChangesAsync(cancellationToken);
        await _catalogApi.OccupyTableAsync(tableId, order.OrderID, cancellationToken);
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

        var dishLookup = (await _catalogApi.GetDishesAsync(dishIds, cancellationToken)
            ?? Array.Empty<CatalogApiClient.DishSnapshotResponse>())
            .ToDictionary(x => x.DishId, x => (x.Name, x.Unit, x.Image));

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

        var currentStatusCode = await GetOrderStatusCodeAsync(order.StatusID, cancellationToken);
        var entersKitchenFlow = IsKitchenStatus(statusCode) && !IsKitchenStatus(currentStatusCode);

        if (entersKitchenFlow)
        {
            var orderItems = await _db.OrderItems
                .AsNoTracking()
                .Where(x => x.OrderID == order.OrderID)
                .Select(x => new CatalogApiClient.OrderIngredientConsumptionItem(x.DishID, x.Quantity))
                .ToListAsync(cancellationToken);

            if (orderItems.Count == 0)
            {
                return BadRequest("Đơn hàng không có món để chuyển sang bếp.");
            }

            var consumption = await _catalogApi.ConsumeIngredientsForOrderAsync(order.OrderID, orderItems, cancellationToken);
            if (!consumption.Success)
            {
                return Conflict(new
                {
                    message = consumption.Message ?? "Không thể trừ nguyên liệu trong kho.",
                    issues = consumption.Issues.Select(x => new
                    {
                        ingredientId = x.IngredientId,
                        ingredientName = x.IngredientName,
                        requiredQuantity = x.RequiredQuantity,
                        availableQuantity = x.AvailableQuantity,
                        unit = x.Unit
                    }).ToList()
                });
            }
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

    private static bool IsKitchenStatus(string? statusCode) =>
        string.Equals(statusCode, "PREPARING", StringComparison.OrdinalIgnoreCase)
        || string.Equals(statusCode, "READY", StringComparison.OrdinalIgnoreCase)
        || string.Equals(statusCode, "SERVING", StringComparison.OrdinalIgnoreCase);

    private async Task UpsertOrderItemAsync(
        int orderId,
        CatalogApiClient.DishSnapshotResponse dishSnapshot,
        AddItemRequest request,
        CancellationToken cancellationToken)
    {
        var normalizedNote = NormalizeNote(request.Note);
        var item = await _db.OrderItems
            .FirstOrDefaultAsync(x => x.OrderID == orderId && x.DishID == request.DishId && x.Note == normalizedNote, cancellationToken);

        if (item is null)
        {
            item = new OrderItems
            {
                OrderID = orderId,
                DishID = request.DishId,
                Quantity = request.Quantity,
                UnitPrice = dishSnapshot.Price,
                LineTotal = dishSnapshot.Price * request.Quantity,
                Note = normalizedNote,
            };
            _db.OrderItems.Add(item);
            return;
        }

        item.Quantity += request.Quantity;
        item.LineTotal = item.UnitPrice * item.Quantity;
    }

    private async Task AttachCustomerByPhoneAsync(OrderEntity order, string phoneNumber, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(phoneNumber))
        {
            return;
        }

        var customer = await _customersApi.GetLoyaltyByPhoneAsync(phoneNumber.Trim(), cancellationToken);
        if (customer is null)
        {
            return;
        }

        AttachCustomer(order, customer.CustomerId);
    }

    private static void AttachCustomer(OrderEntity order, int customerId)
    {
        if (customerId > 0)
        {
            order.CustomerID = customerId;
        }
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
    public sealed record SubmitOrderBatchRequest(IReadOnlyList<AddItemRequest>? Items, string? CustomerPhoneNumber);
    public sealed record CancelOrderRequest(string? Reason);
    public sealed record AdminRevenueRowResponse(
        DateOnly Date,
        int BranchId,
        string BranchName,
        int TotalOrders,
        decimal TotalRevenue);
    public sealed record ChefHistoryItemResponse(
        int OrderId,
        string? OrderCode,
        DateTime OrderTime,
        DateTime? CompletedTime,
        string? TableName,
        string? BranchName,
        string StatusCode,
        string StatusName,
        string DishesSummary);
    public sealed record AdminRevenueReportResponse(decimal TotalRevenue, IReadOnlyList<AdminRevenueRowResponse> RevenueByBranchDate);
    public sealed record AdminTopDishReportItemResponse(
        int DishId,
        string DishName,
        string CategoryName,
        int TotalQuantity,
        decimal TotalRevenue);
    public sealed record AdminTopDishReportResponse(IReadOnlyList<AdminTopDishReportItemResponse> Items);
}
