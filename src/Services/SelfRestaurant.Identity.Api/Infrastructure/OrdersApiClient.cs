using System.Net.Http.Json;

namespace SelfRestaurant.Identity.Api.Infrastructure;

public sealed class OrdersApiClient
{
    private readonly HttpClient _http;

    public OrdersApiClient(HttpClient http)
    {
        _http = http;
    }

    public async Task<IReadOnlyList<ChefHistoryAggregateResponse>> GetChefHistoryAsync(
        int branchId,
        int days,
        int take,
        CancellationToken cancellationToken)
    {
        var list = await _http.GetFromJsonAsync<IReadOnlyList<ChefHistoryAggregateResponse>>(
            $"/api/internal/branches/{branchId}/chef/history?days={days}&take={take}",
            cancellationToken);

        return list ?? Array.Empty<ChefHistoryAggregateResponse>();
    }
}
