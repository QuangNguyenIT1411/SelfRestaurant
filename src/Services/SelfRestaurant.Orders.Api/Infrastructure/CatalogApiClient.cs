using System.Net.Http.Json;

namespace SelfRestaurant.Orders.Api.Infrastructure;

public sealed class CatalogApiClient
{
    private readonly HttpClient _http;

    public CatalogApiClient(HttpClient http)
    {
        _http = http;
    }

    public Task<TableSnapshotResponse?> GetTableAsync(int tableId, CancellationToken cancellationToken) =>
        _http.GetFromJsonAsync<TableSnapshotResponse>($"/api/internal/tables/{tableId}", cancellationToken);

    public Task<DishSnapshotResponse?> GetDishAsync(int dishId, CancellationToken cancellationToken) =>
        _http.GetFromJsonAsync<DishSnapshotResponse>($"/api/internal/dishes/{dishId}", cancellationToken);

    public Task<TableStatusSnapshotResponse?> GetTableStatusAsync(string statusCode, CancellationToken cancellationToken) =>
        _http.GetFromJsonAsync<TableStatusSnapshotResponse>($"/api/internal/table-statuses/{Uri.EscapeDataString(statusCode)}", cancellationToken);

    public sealed record TableSnapshotResponse(
        int TableId,
        int BranchId,
        string? QrCode,
        bool IsActive,
        int StatusId,
        string? StatusCode,
        string? StatusName);

    public sealed record DishSnapshotResponse(
        int DishId,
        string Name,
        decimal Price,
        string? Unit,
        string? Image,
        bool IsActive,
        bool Available);

    public sealed record TableStatusSnapshotResponse(
        int StatusId,
        string StatusCode,
        string StatusName);
}
