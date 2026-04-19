using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Orders.Api.Persistence;
using SelfRestaurant.Orders.Api.Persistence.Entities;

namespace SelfRestaurant.Orders.Api.Infrastructure.Eventing;

public sealed class PaymentCompletedConsumerService : BackgroundService
{
    private const string ConsumerName = "Orders.Api/payment-completed-consumer";
    private const int MaxRetries = 3;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PaymentCompletedConsumerService> _logger;
    private readonly IConfiguration _configuration;

    public PaymentCompletedConsumerService(
        IServiceScopeFactory scopeFactory,
        ILogger<PaymentCompletedConsumerService> logger,
        IConfiguration configuration)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _configuration = configuration;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!(_configuration.GetValue<bool?>("IntegrationEvents:Consumers:PaymentCompleted:Enabled") ?? true))
        {
            _logger.LogInformation("PaymentCompleted consumer is disabled.");
            return;
        }

        var interval = TimeSpan.FromSeconds(Math.Clamp(_configuration.GetValue<int?>("IntegrationEvents:Consumers:PaymentCompleted:PollIntervalSeconds") ?? 5, 2, 60));
        var take = Math.Clamp(_configuration.GetValue<int?>("IntegrationEvents:Consumers:PaymentCompleted:Take") ?? 20, 1, 100);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ConsumeBatchAsync(take, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "PaymentCompleted consumer iteration failed.");
            }

            try
            {
                await Task.Delay(interval, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }
    }

    private async Task ConsumeBatchAsync(int take, CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var billingEvents = scope.ServiceProvider.GetRequiredService<BillingEventsClient>();
        var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();
        var catalogApi = scope.ServiceProvider.GetRequiredService<ICatalogReadModel>();

        var events = await billingEvents.GetPendingPaymentCompletedAsync(take, cancellationToken);
        if (events.Count == 0)
        {
            return;
        }

        foreach (var item in events)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var existingInbox = await db.InboxEvents.FirstOrDefaultAsync(
                x => x.Source == item.Source && x.SourceEventId == item.OutboxEventId,
                cancellationToken);

            if (existingInbox is not null && string.Equals(existingInbox.Status, "PROCESSED", StringComparison.OrdinalIgnoreCase))
            {
                await billingEvents.AckAsync(item.OutboxEventId, ConsumerName, cancellationToken);
                continue;
            }

            if (existingInbox is not null && string.Equals(existingInbox.Status, "DEAD", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (existingInbox is not null &&
                string.Equals(existingInbox.Status, "RETRY", StringComparison.OrdinalIgnoreCase) &&
                existingInbox.NextRetryAtUtc is DateTime nextRetryAtUtc &&
                nextRetryAtUtc > DateTime.UtcNow)
            {
                continue;
            }

            try
            {
                var payload = item.Payload.Deserialize<PaymentCompletedPayload>(new JsonSerializerOptions(JsonSerializerDefaults.Web));
                if (payload is null)
                {
                    throw new InvalidOperationException($"Unable to deserialize payload for outbox event {item.OutboxEventId}.");
                }

                await ReconcileAsync(db, payload, catalogApi, cancellationToken);

                var inbox = existingInbox ?? new InboxEvents
                {
                    Source = item.Source,
                    SourceEventId = item.OutboxEventId,
                    EventName = item.EventName,
                    CorrelationId = item.CorrelationId,
                    ReceivedAtUtc = DateTime.UtcNow
                };
                inbox.PayloadJson = item.Payload.GetRawText();
                inbox.Status = "PROCESSED";
                inbox.RetryCount = existingInbox?.RetryCount ?? 0;
                inbox.NextRetryAtUtc = null;
                inbox.ProcessedAtUtc = DateTime.UtcNow;
                inbox.Error = null;
                if (existingInbox is null)
                {
                    db.InboxEvents.Add(inbox);
                }
                await db.SaveChangesAsync(cancellationToken);

                await billingEvents.AckAsync(item.OutboxEventId, ConsumerName, cancellationToken);
            }
            catch (Exception ex)
            {
                var inbox = existingInbox ?? new InboxEvents
                {
                    Source = item.Source,
                    SourceEventId = item.OutboxEventId,
                    EventName = item.EventName,
                    CorrelationId = item.CorrelationId,
                    ReceivedAtUtc = DateTime.UtcNow
                };
                inbox.PayloadJson = item.Payload.GetRawText();
                var retryCount = (existingInbox?.RetryCount ?? 0) + 1;
                inbox.RetryCount = retryCount;
                inbox.Status = retryCount >= MaxRetries ? "DEAD" : "RETRY";
                inbox.NextRetryAtUtc = retryCount >= MaxRetries ? null : DateTime.UtcNow.AddSeconds(Math.Min(15 * retryCount, 60));
                inbox.ProcessedAtUtc = DateTime.UtcNow;
                inbox.Error = ex.ToString();
                if (existingInbox is null)
                {
                    db.InboxEvents.Add(inbox);
                }
                await db.SaveChangesAsync(cancellationToken);
                _logger.LogWarning(ex, "Failed to process payment.completed event {OutboxEventId}", item.OutboxEventId);
            }
        }
    }

    private static async Task ReconcileAsync(
        OrdersDbContext db,
        PaymentCompletedPayload payload,
        ICatalogReadModel catalogApi,
        CancellationToken cancellationToken)
    {
        var order = await db.Orders.FirstOrDefaultAsync(x => x.OrderID == payload.OrderId, cancellationToken);
        if (order is null)
        {
            return;
        }

        var completedId = await db.OrderStatus
            .Where(x => x.StatusCode == "COMPLETED")
            .Select(x => (int?)x.StatusID)
            .FirstOrDefaultAsync(cancellationToken);

        if (completedId is int statusId)
        {
            order.StatusID = statusId;
        }

        order.IsActive = false;
        order.CompletedTime ??= DateTime.Now;
        order.CashierID = payload.EmployeeId > 0 ? payload.EmployeeId : order.CashierID;

        if (order.TableID is int tableId)
        {
            await catalogApi.ReleaseTableAsync(tableId, cancellationToken);
        }

        await db.SaveChangesAsync(cancellationToken);
    }

    private sealed record PaymentCompletedPayload(
        int OrderId,
        string BillCode,
        int? TableId,
        int? CustomerId,
        int EmployeeId,
        decimal Subtotal,
        decimal Discount,
        int PointsUsed,
        int PointsEarned,
        decimal TotalAmount,
        string PaymentMethod);
}
