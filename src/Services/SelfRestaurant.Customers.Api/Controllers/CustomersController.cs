using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Customers.Api.Infrastructure;
using SelfRestaurant.Customers.Api.Persistence;

namespace SelfRestaurant.Customers.Api.Controllers;

[ApiController]
public sealed class CustomersController : ControllerBase
{
    private readonly CustomersDbContext _db;
    private readonly OrdersQueryClient _ordersQueryClient;
    private readonly IHostEnvironment _environment;

    public CustomersController(CustomersDbContext db, OrdersQueryClient ordersQueryClient, IHostEnvironment environment)
    {
        _db = db;
        _ordersQueryClient = ordersQueryClient;
        _environment = environment;
    }

    [HttpGet("api/customers/{customerId:int}/orders")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetOrders(
        int customerId,
        [FromQuery] int take = 10,
        CancellationToken cancellationToken = default)
    {
        take = Math.Clamp(take, 1, 50);
        var orders = await _ordersQueryClient.GetCustomerOrdersAsync(customerId, take, cancellationToken);
        return Ok(orders);
    }

    [HttpGet("api/customers/{customerId:int}/ready-notifications")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetReadyNotifications(
        int customerId,
        [FromQuery] int? tableId = null,
        [FromQuery] string status = "OPEN",
        CancellationToken cancellationToken = default)
    {
        var normalizedStatus = string.IsNullOrWhiteSpace(status) ? "OPEN" : status.Trim().ToUpperInvariant();

        var query = _db.ReadyDishNotifications
            .AsNoTracking()
            .Where(x => x.Status == normalizedStatus)
            .AsQueryable();

        if (tableId is > 0)
        {
            query = query.Where(x => x.TableId == tableId.Value || x.CustomerId == customerId);
        }
        else
        {
            query = query.Where(x => x.CustomerId == customerId);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new
            {
                notificationId = x.ReadyDishNotificationId,
                orderId = x.OrderId,
                orderItemId = x.OrderItemId,
                dishId = x.DishId,
                dishName = x.DishName,
                customerId = x.CustomerId,
                tableId = x.TableId,
                eventName = x.EventName,
                message = x.Message,
                status = x.Status,
                createdAt = x.CreatedAtUtc,
            })
            .ToListAsync(cancellationToken);

        return Ok(items);
    }

    [HttpPost("api/customers/{customerId:int}/ready-notifications/{notificationId:long}/resolve")]
    public async Task<ActionResult<object>> ResolveReadyNotification(
        int customerId,
        long notificationId,
        CancellationToken cancellationToken)
    {
        var entity = await _db.ReadyDishNotifications
            .FirstOrDefaultAsync(
                x => x.ReadyDishNotificationId == notificationId
                     && (x.CustomerId == customerId || x.CustomerId == null),
                cancellationToken);

        if (entity is null)
        {
            return NotFound(new { message = "Notification not found." });
        }

        var resolvedAtUtc = DateTime.UtcNow;
        var siblingNotifications = await _db.ReadyDishNotifications
            .Where(x =>
                x.Status == "OPEN"
                && x.OrderId == entity.OrderId
                && x.OrderItemId == entity.OrderItemId
                && (
                    x.CustomerId == customerId
                    || x.CustomerId == null
                    || (entity.TableId != null && x.TableId == entity.TableId)
                ))
            .ToListAsync(cancellationToken);

        foreach (var notification in siblingNotifications)
        {
            notification.Status = "RESOLVED";
            notification.ResolvedAtUtc = resolvedAtUtc;
        }

        if (siblingNotifications.Count == 0)
        {
            entity.Status = "RESOLVED";
            entity.ResolvedAtUtc = resolvedAtUtc;
        }

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            readyDishNotificationId = entity.ReadyDishNotificationId,
            orderId = entity.OrderId,
            resolvedCount = siblingNotifications.Count == 0 ? 1 : siblingNotifications.Count,
            status = "RESOLVED",
        });
    }

    [HttpPost("api/dev/reset-test-state")]
    public async Task<ActionResult<object>> ResetDevTestState(CancellationToken cancellationToken)
    {
        if (!_environment.IsDevelopment())
        {
            return NotFound();
        }

        var readyNotifications = await _db.ReadyDishNotifications.ToListAsync(cancellationToken);
        var inboxEvents = await _db.InboxEvents.ToListAsync(cancellationToken);

        if (readyNotifications.Count > 0)
        {
            _db.ReadyDishNotifications.RemoveRange(readyNotifications);
        }

        if (inboxEvents.Count > 0)
        {
            _db.InboxEvents.RemoveRange(inboxEvents);
        }

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            success = true,
            clearedReadyNotifications = readyNotifications.Count,
            clearedInboxEvents = inboxEvents.Count
        });
    }
}
