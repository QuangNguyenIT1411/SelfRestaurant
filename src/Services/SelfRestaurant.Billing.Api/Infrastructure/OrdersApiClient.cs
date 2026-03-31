using System.Net.Http.Json;

namespace SelfRestaurant.Billing.Api.Infrastructure;

public sealed class OrdersApiClient
{
    private readonly HttpClient _http;

    public OrdersApiClient(HttpClient http)
    {
        _http = http;
    }

    public async Task<bool> CompleteCheckoutAsync(int orderId, int cashierId, CancellationToken cancellationToken)
    {
        using var response = await _http.PostAsJsonAsync(
            $"/api/orders/{orderId}/billing/complete",
            new CompleteCheckoutRequest(cashierId),
            cancellationToken);

        return response.IsSuccessStatusCode;
    }

    public sealed record CompleteCheckoutRequest(int CashierId);
}
