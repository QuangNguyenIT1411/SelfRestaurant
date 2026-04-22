using SelfRestaurant.Gateway.Api.Models;

namespace SelfRestaurant.Gateway.Api.Services;

public sealed class OrdersClient : ApiClientBase
{
    public OrdersClient(HttpClient http) : base(http)
    {
    }

    public Task OccupyTableAsync(int tableId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/tables/{tableId}/occupy", new { }, cancellationToken);

    public Task ResetTableAsync(int tableId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/tables/{tableId}/reset", new { }, cancellationToken);

    public Task<ActiveOrderResponse?> GetActiveOrderAsync(int tableId, CancellationToken cancellationToken) =>
        GetAsync<ActiveOrderResponse>($"/api/tables/{tableId}/order", cancellationToken);

    public async Task<IReadOnlyList<ActiveOrderResponse>> GetActiveOrdersAsync(int tableId, CancellationToken cancellationToken)
    {
        var list = await GetAsync<IReadOnlyList<ActiveOrderResponse>>($"/api/tables/{tableId}/orders/active", cancellationToken);
        return list ?? Array.Empty<ActiveOrderResponse>();
    }

    public Task<ActiveOrderResponse?> GetOrderByIdAsync(int orderId, CancellationToken cancellationToken) =>
        GetAsync<ActiveOrderResponse>($"/api/orders/{orderId}", cancellationToken);

    public Task<CustomerActiveOrderContextDto?> GetCustomerActiveOrderContextAsync(int customerId, CancellationToken cancellationToken) =>
        GetAsync<CustomerActiveOrderContextDto>($"/api/internal/customers/{customerId}/active-order-context", cancellationToken);

    public Task<ActiveOrderResponse?> AddItemAsync(int tableId, int dishId, int quantity, string? note, string? expectedDiningSessionCode, CancellationToken cancellationToken) =>
        PostForAsync<object, ActiveOrderResponse>(
            $"/api/tables/{tableId}/order/items",
            new { dishId, quantity, note, expectedDiningSessionCode },
            cancellationToken);

    public Task UpdateQuantityAsync(int tableId, int itemId, int quantity, CancellationToken cancellationToken) =>
        PutAsync($"/api/tables/{tableId}/order/items/{itemId}", new { quantity }, cancellationToken);

    public Task UpdateItemNoteAsync(int tableId, int itemId, string? note, CancellationToken cancellationToken) =>
        PutAsync($"/api/tables/{tableId}/order/items/{itemId}/note", new { note }, cancellationToken);

    public Task RemoveItemAsync(int tableId, int itemId, CancellationToken cancellationToken) =>
        DeleteAsync($"/api/tables/{tableId}/order/items/{itemId}", cancellationToken);

    public Task SubmitOrderAsync(int tableId, string idempotencyKey, string? expectedDiningSessionCode, CancellationToken cancellationToken) =>
        PostAsync($"/api/tables/{tableId}/order/submit", new { idempotencyKey, expectedDiningSessionCode }, cancellationToken);

    public Task<ActiveOrderResponse?> SubmitOrderBatchAsync(
        int tableId,
        IReadOnlyList<AddOrderItemPayload> items,
        string? customerPhoneNumber,
        string idempotencyKey,
        string? expectedDiningSessionCode,
        CancellationToken cancellationToken) =>
        PostForAsync<object, ActiveOrderResponse>(
            $"/api/tables/{tableId}/order/submit-batch",
            new
            {
                items = items.Select(item => new
                {
                    dishId = item.DishId,
                    quantity = item.Quantity,
                    note = item.Note,
                }).ToArray(),
                customerPhoneNumber,
                idempotencyKey,
                expectedDiningSessionCode,
            },
            cancellationToken);

    public Task ConfirmOrderReceivedAsync(int orderId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/confirm-received", new { }, cancellationToken);

    public Task ResetDevTestStateAsync(CancellationToken cancellationToken) =>
        PostAsync<object>("/api/dev/reset-test-state", new { }, cancellationToken);

    public Task<LoyaltyScanResponse?> ScanLoyaltyCardAsync(int tableId, string phoneNumber, CancellationToken cancellationToken) =>
        PostForAsync<object, LoyaltyScanResponse>(
            $"/api/tables/{tableId}/order/scan-loyalty-card",
            new { phoneNumber },
            cancellationToken);

    public Task<IReadOnlyList<int>?> GetTopDishIdsAsync(int branchId, int count, CancellationToken cancellationToken) =>
        GetAsync<IReadOnlyList<int>>($"/api/branches/{branchId}/top-dishes?count={count}", cancellationToken);

    public Task<AdminOrderStatsResponse?> GetAdminStatsAsync(DateOnly? date, CancellationToken cancellationToken)
    {
        var query = date is null ? "" : $"?date={date:yyyy-MM-dd}";
        return GetAsync<AdminOrderStatsResponse>($"/api/admin/stats{query}", cancellationToken);
    }

    public Task<AdminRevenueReportDto?> GetAdminRevenueReportAsync(int days, CancellationToken cancellationToken) =>
        GetAsync<AdminRevenueReportDto>($"/api/admin/reports/revenue?days={Math.Clamp(days, 1, 365)}", cancellationToken);

    public Task<AdminTopDishReportDto?> GetAdminTopDishesReportAsync(int days, int take, CancellationToken cancellationToken) =>
        GetAsync<AdminTopDishReportDto>(
            $"/api/admin/reports/top-dishes?days={Math.Clamp(days, 1, 365)}&take={Math.Clamp(take, 1, 50)}",
            cancellationToken);

    public async Task<IReadOnlyList<ChefOrderDto>> GetChefOrdersAsync(int branchId, string? status, CancellationToken cancellationToken)
    {
        var qs = string.IsNullOrWhiteSpace(status) ? "" : $"?status={Uri.EscapeDataString(status)}";
        var list = await GetAsync<IReadOnlyList<ChefOrderDto>>($"/api/branches/{branchId}/chef/orders{qs}", cancellationToken);
        return list ?? Array.Empty<ChefOrderDto>();
    }

    public Task ChefStartAsync(int orderId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/chef/start", new { }, cancellationToken);

    public Task ChefReadyAsync(int orderId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/chef/ready", new { }, cancellationToken);

    public Task ChefStartItemAsync(int orderId, int itemId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/items/{itemId}/chef/start", new { }, cancellationToken);

    public Task ChefReadyItemAsync(int orderId, int itemId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/items/{itemId}/chef/ready", new { }, cancellationToken);

    public Task ChefCancelItemAsync(int orderId, int itemId, string? reason, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/items/{itemId}/cancel", new { reason }, cancellationToken);

    public Task ChefServeAsync(int orderId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/chef/serve", new { }, cancellationToken);

    public Task ChefUpdateStatusAsync(int orderId, string statusCode, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/status", new { statusCode }, cancellationToken);

    public Task ChefCancelAsync(int orderId, string? reason, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/orders/{orderId}/cancel", new { reason }, cancellationToken);

    public Task ChefUpdateItemNoteAsync(int orderId, int itemId, string? note, bool append, CancellationToken cancellationToken) =>
        PutAsync($"/api/orders/{orderId}/items/{itemId}/chef-note", new { note, append }, cancellationToken);

    public async Task<IReadOnlyList<ChefHistoryDto>> GetChefHistoryAsync(int branchId, int take, CancellationToken cancellationToken)
    {
        var list = await GetAsync<IReadOnlyList<ChefHistoryDto>>($"/api/branches/{branchId}/chef/history?take={take}", cancellationToken);
        return list ?? Array.Empty<ChefHistoryDto>();
    }
}

public sealed record LoyaltyScanCustomerResponse(
    string Name,
    string Phone,
    int CurrentPoints,
    int CardPoints);

public sealed record LoyaltyScanResponse(
    bool Success,
    string Message,
    LoyaltyScanCustomerResponse? Customer);

public sealed record AddOrderItemPayload(
    int DishId,
    int Quantity,
    string? Note);
