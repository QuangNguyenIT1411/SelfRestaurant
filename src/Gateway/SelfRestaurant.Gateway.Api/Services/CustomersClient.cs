using SelfRestaurant.Gateway.Api.Models;

namespace SelfRestaurant.Gateway.Api.Services;

public sealed class CustomersClient : ApiClientBase
{
    private readonly HttpClient _identityFallbackHttp;

    public CustomersClient(HttpClient http, IHttpClientFactory httpClientFactory) : base(http)
    {
        _identityFallbackHttp = httpClientFactory.CreateClient("CustomersFallbackIdentity");
    }

    public Task<CustomerProfileResponse?> GetCustomerAsync(int customerId, CancellationToken cancellationToken) =>
        GetAsync<CustomerProfileResponse>($"/api/customers/{customerId}", cancellationToken);

    public async Task<IReadOnlyList<ReadyDishNotificationDto>> GetReadyNotificationsAsync(
        int customerId,
        int? tableId,
        CancellationToken cancellationToken)
    {
        var qs = new List<string> { "status=OPEN" };
        if (tableId is > 0)
        {
            qs.Add($"tableId={tableId.Value}");
        }

        var list = await GetAsync<IReadOnlyList<ReadyDishNotificationDto>>(
            $"/api/customers/{customerId}/ready-notifications?{string.Join("&", qs)}",
            cancellationToken);
        return list ?? Array.Empty<ReadyDishNotificationDto>();
    }

    public Task ResolveReadyNotificationAsync(long notificationId, int customerId, CancellationToken cancellationToken) =>
        PostAsync<object>($"/api/customers/{customerId}/ready-notifications/{notificationId}/resolve", new { }, cancellationToken);

    public Task ResetDevTestStateAsync(CancellationToken cancellationToken) =>
        PostAsync<object>("/api/dev/reset-test-state", new { }, cancellationToken);

    public async Task<IReadOnlyList<CustomerOrderHistoryDto>> GetOrdersAsync(int customerId, int take, CancellationToken cancellationToken)
    {
        var list = await GetAsync<IReadOnlyList<CustomerOrderHistoryDto>>(
            $"/api/customers/{customerId}/orders?take={take}",
            cancellationToken);
        return list ?? Array.Empty<CustomerOrderHistoryDto>();
    }

    public Task UpdateProfileAsync(int customerId, UpdateCustomerProfileRequest request, CancellationToken cancellationToken) =>
        PutAsync($"/api/customers/{customerId}/profile", request, cancellationToken);

    public Task<AdminCustomerPagedResponse?> GetAdminCustomersAsync(
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken) =>
        GetAdminCustomersCompatAsync(search, page, pageSize, cancellationToken);

    private Task<AdminCustomerPagedResponse?> GetAdminCustomersCompatAsync(
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var qs = new List<string>
        {
            $"page={Math.Max(1, page)}",
            $"pageSize={Math.Clamp(pageSize, 1, 100)}",
        };

        if (!string.IsNullOrWhiteSpace(search))
        {
            qs.Add($"search={Uri.EscapeDataString(search.Trim())}");
        }

        return ExecuteWithFallbackAsync(
            () => GetAsync<AdminCustomerPagedResponse>($"/api/customers/admin/customers?{string.Join("&", qs)}", cancellationToken),
            () => GetAsync<AdminCustomerPagedResponse>($"/api/identity/admin/customers?{string.Join("&", qs)}", cancellationToken, _identityFallbackHttp));
    }

    public Task<AdminCustomerDto?> GetAdminCustomerByIdAsync(int customerId, CancellationToken cancellationToken) =>
        ExecuteWithFallbackAsync(
            () => GetAsync<AdminCustomerDto>($"/api/customers/admin/customers/{customerId}", cancellationToken),
            () => GetAsync<AdminCustomerDto>($"/api/identity/admin/customers/{customerId}", cancellationToken, _identityFallbackHttp));

    public Task CreateAdminCustomerAsync(AdminUpsertCustomerRequest request, CancellationToken cancellationToken) =>
        ExecuteWithFallbackAsync(
            () => PostAsync("/api/customers/admin/customers", request, cancellationToken),
            () => PostAsync("/api/identity/admin/customers", request, cancellationToken, _identityFallbackHttp));

    public Task UpdateAdminCustomerAsync(int customerId, AdminUpsertCustomerRequest request, CancellationToken cancellationToken) =>
        ExecuteWithFallbackAsync(
            () => PutAsync($"/api/customers/admin/customers/{customerId}", request, cancellationToken),
            () => PutAsync($"/api/identity/admin/customers/{customerId}", request, cancellationToken, _identityFallbackHttp));

    public Task DeactivateAdminCustomerAsync(int customerId, CancellationToken cancellationToken) =>
        ExecuteWithFallbackAsync(
            () => PostAsync<object>($"/api/customers/admin/customers/{customerId}/deactivate", new { }, cancellationToken),
            () => PostAsync<object>($"/api/identity/admin/customers/{customerId}/deactivate", new { }, cancellationToken, _identityFallbackHttp));

    private static async Task<TResponse?> ExecuteWithFallbackAsync<TResponse>(Func<Task<TResponse?>> primaryCall, params Func<Task<TResponse?>>[] fallbackCalls)
    {
        try
        {
            var primaryResponse = await primaryCall();
            if (primaryResponse is not null)
            {
                return primaryResponse;
            }
        }
        catch (Exception primaryException)
        {
            var lastException = primaryException;
            foreach (var fallbackCall in fallbackCalls)
            {
                try
                {
                    var fallbackResponse = await fallbackCall();
                    if (fallbackResponse is not null)
                    {
                        return fallbackResponse;
                    }
                }
                catch (Exception fallbackException)
                {
                    lastException = fallbackException;
                }
            }

            throw lastException;
        }

        foreach (var fallbackCall in fallbackCalls)
        {
            var fallbackResponse = await fallbackCall();
            if (fallbackResponse is not null)
            {
                return fallbackResponse;
            }
        }

        return default;
    }

    private static async Task ExecuteWithFallbackAsync(Func<Task> primaryCall, params Func<Task>[] fallbackCalls)
    {
        try
        {
            await primaryCall();
            return;
        }
        catch (Exception primaryException)
        {
            var lastException = primaryException;
            foreach (var fallbackCall in fallbackCalls)
            {
                try
                {
                    await fallbackCall();
                    return;
                }
                catch (Exception fallbackException)
                {
                    lastException = fallbackException;
                }
            }

            throw lastException;
        }
    }
}
