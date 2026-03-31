using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Billing.Api.Infrastructure;
using SelfRestaurant.Billing.Api.Infrastructure.Eventing;
using SelfRestaurant.Billing.Api.Persistence;
using SelfRestaurant.Billing.Api.Persistence.Entities;

namespace SelfRestaurant.Billing.Api.Controllers;

[ApiController]
public sealed class CashierController : ControllerBase
{
    private static readonly string[] ActiveStatusCodes = ["PENDING", "CONFIRMED", "PREPARING", "READY", "SERVING"];

    private readonly BillingDbContext _db;
    private readonly CustomersApiClient _customersApi;
    private readonly OrdersApiClient _ordersApi;
    private readonly IIntegrationEventPublisher _eventPublisher;

    public CashierController(BillingDbContext db, CustomersApiClient customersApi, OrdersApiClient ordersApi, IIntegrationEventPublisher eventPublisher)
    {
        _db = db;
        _customersApi = customersApi;
        _ordersApi = ordersApi;
        _eventPublisher = eventPublisher;
    }

    [HttpGet("api/branches/{branchId:int}/cashier/orders")]
    public async Task<ActionResult<IReadOnlyList<CashierOrderResponse>>> GetCashierOrders(
        int branchId,
        CancellationToken cancellationToken)
    {
        var orders = await _db.Orders
            .AsNoTracking()
            .Include(o => o.Status)
            .Include(o => o.Table)
            .Include(o => o.Customer)
            .Where(o =>
                (o.IsActive ?? false) == true
                && o.Table != null
                && o.Table.BranchID == branchId
                && ActiveStatusCodes.Contains(o.Status.StatusCode))
            .OrderBy(o => o.OrderTime)
            .ToListAsync(cancellationToken);

        var orderIds = orders.Select(o => o.OrderID).ToList();
        var items = await _db.OrderItems
            .AsNoTracking()
            .Where(oi => orderIds.Contains(oi.OrderID))
            .Include(oi => oi.Dish)
            .OrderBy(oi => oi.OrderID)
            .ThenBy(oi => oi.ItemID)
            .Select(oi => new CashierOrderItemResponse(
                oi.ItemID,
                oi.OrderID,
                oi.DishID,
                oi.Dish.Name,
                oi.Quantity,
                oi.UnitPrice,
                oi.LineTotal,
                oi.Dish.Image,
                oi.Note))
            .ToListAsync(cancellationToken);

        var itemsByOrder = items
            .GroupBy(i => i.OrderId)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<CashierOrderItemResponse>)g.ToList());

        var payload = orders
            .Select(o =>
            {
                var tableName = o.Table?.QRCode;
                if (string.IsNullOrWhiteSpace(tableName))
                {
                    tableName = o.TableID.HasValue ? $"Bàn {o.TableID.Value}" : "Bàn ?";
                }

                itemsByOrder.TryGetValue(o.OrderID, out var orderItems);
                orderItems ??= Array.Empty<CashierOrderItemResponse>();

                var subtotal = orderItems.Sum(i => i.LineTotal);
                var itemCount = orderItems.Sum(i => i.Quantity);

                return new CashierOrderResponse(
                    o.OrderID,
                    o.OrderCode,
                    o.OrderTime,
                    o.TableID ?? 0,
                    tableName,
                    o.CustomerID,
                    o.Customer != null ? o.Customer.Name : null,
                    o.Customer != null ? (o.Customer.LoyaltyPoints ?? 0) : 0,
                    o.Status.StatusCode,
                    o.Status.StatusName,
                    subtotal,
                    itemCount,
                    orderItems);
            })
            .ToList();

        return Ok(payload);
    }

    [HttpPost("api/orders/{orderId:int}/checkout")]
    public async Task<ActionResult<CheckoutResponse>> Checkout(
        int orderId,
        [FromBody] CheckoutRequest request,
        CancellationToken cancellationToken)
    {
        var employeeId = request.EmployeeId;
        if (employeeId <= 0)
        {
            return BadRequest(new { message = "Thiếu thông tin nhân viên thu ngân." });
        }

        var order = await _db.Orders
            .Include(o => o.Status)
            .Include(o => o.Table)
            .FirstOrDefaultAsync(o => o.OrderID == orderId && (o.IsActive ?? false) == true, cancellationToken);

        if (order is null)
        {
            return NotFound(new { message = "Không tìm thấy đơn hàng." });
        }

        if (!ActiveStatusCodes.Contains(order.Status.StatusCode))
        {
            return BadRequest(new { message = "Đơn hàng không còn hoạt động." });
        }

        var items = await _db.OrderItems
            .AsNoTracking()
            .Where(oi => oi.OrderID == order.OrderID)
            .Select(oi => new { oi.LineTotal })
            .ToListAsync(cancellationToken);

        var subtotal = items.Sum(i => i.LineTotal);
        var discount = request.Discount < 0 ? 0 : request.Discount;
        if (discount > subtotal)
        {
            discount = subtotal;
        }

        var baseTotal = subtotal - discount;
        CustomersApiClient.CustomerSnapshotResponse? customerSnapshot = null;
        if (order.CustomerID is int customerId && customerId > 0)
        {
            customerSnapshot = await _customersApi.GetCustomerAsync(customerId, cancellationToken);
            if (customerSnapshot is null)
            {
                return Problem("Khong the dong bo du lieu khach hang tu Customers API.", statusCode: StatusCodes.Status502BadGateway);
            }
        }

        var pointsBefore = customerSnapshot?.LoyaltyPoints ?? 0;
        var requestedPoints = request.PointsUsed < 0 ? 0 : request.PointsUsed;
        var usedPoints = 0;
        if (customerSnapshot is not null && requestedPoints > 0)
        {
            var maxByCustomerBalance = customerSnapshot.LoyaltyPoints;
            var maxByPolicy = (int)Math.Floor(baseTotal * 0.10m);
            var maxPointsAllowed = Math.Min(maxByCustomerBalance, maxByPolicy);
            maxPointsAllowed = (maxPointsAllowed / 1000) * 1000;

            usedPoints = Math.Min(requestedPoints, maxPointsAllowed);
            usedPoints = (usedPoints / 1000) * 1000;
        }

        var pointsDiscount = (decimal)usedPoints;
        var totalAmount = baseTotal - pointsDiscount;
        if (totalAmount < 0)
        {
            totalAmount = 0;
        }

        var paymentMethod = string.IsNullOrWhiteSpace(request.PaymentMethod) ? "CASH" : request.PaymentMethod.Trim().ToUpperInvariant();
        if (paymentMethod == "CARD")
        {
            paymentMethod = "QR";
        }

        if (paymentMethod is not ("CASH" or "QR" or "TRANSFER"))
        {
            return BadRequest(new { message = "Phương thức thanh toán không hợp lệ." });
        }

        var paymentAmount = request.PaymentAmount;
        if (paymentMethod == "CASH")
        {
            if (paymentAmount < totalAmount)
            {
                return BadRequest(new { message = "Số tiền khách đưa không đủ để thanh toán hóa đơn." });
            }
        }
        else
        {
            paymentAmount = totalAmount;
        }

        var changeAmount = paymentMethod == "CASH" ? paymentAmount - totalAmount : 0;

        var billCode = await GenerateBillCodeAsync(cancellationToken);

        var bill = new Bills
        {
            OrderID = order.OrderID,
            BillCode = billCode,
            BillTime = DateTime.Now,
            Subtotal = subtotal,
            Discount = discount,
            PointsDiscount = pointsDiscount,
            PointsUsed = usedPoints > 0 ? (int?)usedPoints : null,
            TotalAmount = totalAmount,
            PaymentMethod = paymentMethod,
            PaymentAmount = paymentAmount,
            ChangeAmount = changeAmount,
            EmployeeID = employeeId,
            CustomerID = order.CustomerID,
            IsActive = true,
        };

        _db.Bills.Add(bill);
        await _db.SaveChangesAsync(cancellationToken);
        var earnedPoints = 0;
        var customerPointsAfter = customerSnapshot?.LoyaltyPoints ?? 0;
        var customerName = customerSnapshot?.Name;
        if (order.CustomerID is int settlementCustomerId && settlementCustomerId > 0)
        {
            var settlement = await _customersApi.SettleLoyaltyAsync(
                settlementCustomerId,
                new CustomersApiClient.LoyaltySettlementRequest(usedPoints, totalAmount),
                cancellationToken);

            if (settlement is null)
            {
                return Problem("Khong the dong bo diem tich luy voi Customers API.", statusCode: StatusCodes.Status502BadGateway);
            }

            usedPoints = settlement.PointsUsed;
            earnedPoints = settlement.PointsEarned;
            customerPointsAfter = settlement.CustomerPoints;
            customerName = settlement.CustomerName;
        }

        var completedRemotely = await _ordersApi.CompleteCheckoutAsync(order.OrderID, employeeId, cancellationToken);
        if (!completedRemotely)
        {
            return Problem("Khong the dong bo hoan tat thanh toan voi Orders API.", statusCode: StatusCodes.Status502BadGateway);
        }

        await _eventPublisher.PublishAsync(new IntegrationEventEnvelope(
            EventName: "payment.completed.v1",
            OccurredAtUtc: DateTime.UtcNow,
            Source: "Billing.Api",
            CorrelationId: HttpContext.Response.Headers["X-Correlation-Id"].FirstOrDefault() ?? HttpContext.TraceIdentifier,
            Payload: new
            {
                orderId = order.OrderID,
                billCode,
                tableId = order.TableID,
                customerId = order.CustomerID,
                employeeId,
                subtotal,
                discount,
                pointsUsed = usedPoints,
                pointsEarned = earnedPoints,
                totalAmount,
                paymentMethod
            }), cancellationToken);

        return Ok(new CheckoutResponse(
            BillCode: billCode,
            TotalAmount: totalAmount,
            ChangeAmount: changeAmount,
            PointsUsed: usedPoints,
            PointsEarned: earnedPoints,
            CustomerPoints: customerPointsAfter,
            CustomerName: customerName,
            PointsBefore: pointsBefore));
    }

    private async Task<string> GenerateBillCodeAsync(CancellationToken cancellationToken)
    {
        var dateCode = DateTime.Now.ToString("yyyyMMdd");

        for (var attempt = 0; attempt < 20; attempt++)
        {
            var random = Random.Shared.Next(1000, 9999);
            var code = $"BILL-{dateCode}-{random}";

            var exists = await _db.Bills.AnyAsync(b => b.BillCode == code, cancellationToken);
            if (!exists)
            {
                return code;
            }
        }

        return $"BILL-{dateCode}-{Guid.NewGuid():N}";
    }

    public sealed record CashierOrderItemResponse(
        int ItemId,
        int OrderId,
        int DishId,
        string DishName,
        int Quantity,
        decimal UnitPrice,
        decimal LineTotal,
        string? Image,
        string? Note);

    public sealed record CashierOrderResponse(
        int OrderId,
        string? OrderCode,
        DateTime OrderTime,
        int TableId,
        string TableName,
        int? CustomerId,
        string? CustomerName,
        int CustomerPoints,
        string StatusCode,
        string StatusName,
        decimal Subtotal,
        int ItemCount,
        IReadOnlyList<CashierOrderItemResponse> Items);

    public sealed record CheckoutRequest(
        int EmployeeId,
        decimal Discount = 0,
        int PointsUsed = 0,
        string PaymentMethod = "CASH",
        decimal PaymentAmount = 0);

    public sealed record CheckoutResponse(
        string BillCode,
        decimal TotalAmount,
        decimal ChangeAmount,
        int PointsUsed,
        int PointsEarned,
        int CustomerPoints,
        string? CustomerName,
        int PointsBefore);
}
