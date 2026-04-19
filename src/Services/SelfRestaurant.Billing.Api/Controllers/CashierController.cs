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
    private readonly IHostEnvironment _environment;

    public CashierController(BillingDbContext db, CustomersApiClient customersApi, OrdersApiClient ordersApi, IIntegrationEventPublisher eventPublisher, IHostEnvironment environment)
    {
        _db = db;
        _customersApi = customersApi;
        _ordersApi = ordersApi;
        _eventPublisher = eventPublisher;
        _environment = environment;
    }

    [HttpGet("api/branches/{branchId:int}/cashier/orders")]
    public async Task<ActionResult<IReadOnlyList<CashierOrderResponse>>> GetCashierOrders(
        int branchId,
        CancellationToken cancellationToken)
    {
        var billedOrderIds = await _db.Bills
            .AsNoTracking()
            .Where(b => b.IsActive)
            .Select(b => b.OrderID)
            .Distinct()
            .ToListAsync(cancellationToken);

        var billedOrderLookup = billedOrderIds.ToHashSet();

        var orders = (await _ordersApi.GetCashierOrdersAsync(branchId, cancellationToken))
            .Where(o => !billedOrderLookup.Contains(o.OrderId))
            .ToList();
        var customerLookup = (await _customersApi.GetCustomersAsync(
                orders.Where(o => o.CustomerId.HasValue).Select(o => o.CustomerId!.Value),
                cancellationToken))
            .ToDictionary(x => x.CustomerId);

        var payload = orders
            .Select(o =>
            {
                customerLookup.TryGetValue(o.CustomerId ?? 0, out var customer);

                var items = o.Items
                    .Select(i => new CashierOrderItemResponse(
                        i.ItemId,
                        i.OrderId,
                        i.DishId,
                        i.DishName,
                        i.Quantity,
                        i.UnitPrice,
                        i.LineTotal,
                        i.Image,
                        i.Note))
                    .ToList();

                return new CashierOrderResponse(
                    o.OrderId,
                    o.OrderCode,
                    o.OrderTime,
                    o.TableId,
                    o.TableName,
                    o.CustomerId,
                    customer?.Name,
                    customer?.LoyaltyPoints ?? 0,
                    o.StatusCode,
                    o.StatusName,
                    o.Subtotal,
                    o.ItemCount,
                    items);
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
        var alreadyBilled = await _db.Bills
            .AsNoTracking()
            .AnyAsync(b => b.OrderID == orderId && b.IsActive, cancellationToken);
        if (alreadyBilled)
        {
            return Conflict(new { message = "Đơn hàng này đã được thanh toán." });
        }

        var employeeId = request.EmployeeId;
        if (employeeId <= 0)
        {
            return BadRequest(new { message = "Thiếu thông tin nhân viên thu ngân." });
        }

        var order = await _ordersApi.GetCheckoutContextAsync(orderId, cancellationToken);
        if (order is null)
        {
            return NotFound(new { message = "Không tìm thấy đơn hàng." });
        }

        if (!order.IsActive || !ActiveStatusCodes.Contains(order.StatusCode))
        {
            return BadRequest(new { message = "Đơn hàng không còn hoạt động." });
        }

        var subtotal = order.Subtotal;
        var discount = request.Discount < 0 ? 0 : request.Discount;
        if (discount > subtotal)
        {
            discount = subtotal;
        }

        var baseTotal = subtotal - discount;
        CustomersApiClient.CustomerSnapshotResponse? customerSnapshot = null;
        if (order.CustomerId is int customerId && customerId > 0)
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
            OrderID = order.OrderId,
            BillCode = billCode,
            OrderCodeSnapshot = order.OrderCode,
            TableIdSnapshot = order.TableId,
            TableNameSnapshot = order.TableName,
            BranchIdSnapshot = order.BranchId,
            BranchNameSnapshot = order.BranchName,
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
            CustomerID = order.CustomerId,
            IsActive = true,
        };

        _db.Bills.Add(bill);
        await _db.SaveChangesAsync(cancellationToken);
        var earnedPoints = 0;
        var customerPointsAfter = customerSnapshot?.LoyaltyPoints ?? 0;
        var customerName = customerSnapshot?.Name;
        if (order.CustomerId is int settlementCustomerId && settlementCustomerId > 0)
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

        await _eventPublisher.PublishAsync(new IntegrationEventEnvelope(
            EventName: "payment.completed.v1",
            OccurredAtUtc: DateTime.UtcNow,
            Source: "Billing.Api",
            CorrelationId: HttpContext.Response.Headers["X-Correlation-Id"].FirstOrDefault() ?? HttpContext.TraceIdentifier,
            Payload: new
            {
                orderId = order.OrderId,
                billCode,
                tableId = order.TableId,
                customerId = order.CustomerId,
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

    [HttpPost("api/dev/reset-test-state")]
    public async Task<ActionResult<object>> ResetDevTestState(CancellationToken cancellationToken)
    {
        if (!_environment.IsDevelopment())
        {
            return NotFound();
        }

        var bills = await _db.Bills.ToListAsync(cancellationToken);
        var snapshots = await _db.OrderContextSnapshots.ToListAsync(cancellationToken);
        var outboxEvents = await _db.OutboxEvents.ToListAsync(cancellationToken);

        if (bills.Count > 0)
        {
            _db.Bills.RemoveRange(bills);
        }

        if (snapshots.Count > 0)
        {
            _db.OrderContextSnapshots.RemoveRange(snapshots);
        }

        if (outboxEvents.Count > 0)
        {
            _db.OutboxEvents.RemoveRange(outboxEvents);
        }

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            success = true,
            clearedBills = bills.Count,
            clearedOrderSnapshots = snapshots.Count,
            clearedOutboxEvents = outboxEvents.Count
        });
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
