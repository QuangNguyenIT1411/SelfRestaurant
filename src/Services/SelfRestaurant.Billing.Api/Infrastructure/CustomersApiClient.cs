using System.Net.Http.Json;

namespace SelfRestaurant.Billing.Api.Infrastructure;

public sealed class CustomersApiClient
{
    private readonly HttpClient _http;

    public CustomersApiClient(HttpClient http)
    {
        _http = http;
    }

    public Task<CustomerSnapshotResponse?> GetCustomerAsync(int customerId, CancellationToken cancellationToken) =>
        _http.GetFromJsonAsync<CustomerSnapshotResponse>($"/api/customers/{customerId}", cancellationToken);

    public async Task<LoyaltySettlementResponse?> SettleLoyaltyAsync(
        int customerId,
        LoyaltySettlementRequest request,
        CancellationToken cancellationToken)
    {
        using var response = await _http.PostAsJsonAsync($"/api/customers/{customerId}/loyalty/settle", request, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        return await response.Content.ReadFromJsonAsync<LoyaltySettlementResponse>(cancellationToken: cancellationToken);
    }

    public sealed record CustomerSnapshotResponse(
        int CustomerId,
        string Username,
        string Name,
        string PhoneNumber,
        string? Email,
        string? Gender,
        DateOnly? DateOfBirth,
        string? Address,
        int LoyaltyPoints);

    public sealed record LoyaltySettlementRequest(int PointsUsed, decimal AmountPaid);

    public sealed record LoyaltySettlementResponse(
        int CustomerId,
        string CustomerName,
        int PointsBefore,
        int PointsUsed,
        int PointsEarned,
        int CustomerPoints);
}
