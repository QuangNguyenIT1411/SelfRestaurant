using System.Net.Http.Json;

namespace SelfRestaurant.Identity.Api.Infrastructure;

public sealed class BillingApiClient
{
    private readonly HttpClient _http;

    public BillingApiClient(HttpClient http)
    {
        _http = http;
    }

    public async Task<IReadOnlyList<CashierHistoryAggregateResponse>> GetCashierHistoryAsync(
        int employeeId,
        int days,
        int take,
        CancellationToken cancellationToken)
    {
        var list = await _http.GetFromJsonAsync<IReadOnlyList<CashierHistoryAggregateResponse>>(
            $"/api/internal/employees/{employeeId}/cashier/history?days={days}&take={take}",
            cancellationToken);

        return list ?? Array.Empty<CashierHistoryAggregateResponse>();
    }
}
