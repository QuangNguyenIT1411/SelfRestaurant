using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Services;

public sealed class BillingClient : ApiClientBase
{
    public BillingClient(HttpClient http) : base(http)
    {
    }

    public async Task<IReadOnlyList<CashierOrderDto>> GetCashierOrdersAsync(int branchId, CancellationToken cancellationToken)
    {
        var list = await GetAsync<IReadOnlyList<CashierOrderDto>>($"/api/branches/{branchId}/cashier/orders", cancellationToken);
        return list ?? Array.Empty<CashierOrderDto>();
    }

    public Task<CashierCheckoutResponse?> CheckoutAsync(int orderId, CashierCheckoutRequest request, CancellationToken cancellationToken) =>
        PostForAsync<CashierCheckoutRequest, CashierCheckoutResponse>($"/api/orders/{orderId}/checkout", request, cancellationToken);

    public async Task<IReadOnlyList<CashierBillSummaryDto>> GetBillsAsync(
        int employeeId,
        int branchId,
        DateOnly? date,
        int take,
        CancellationToken cancellationToken)
    {
        var dateQs = date is null ? "" : $"&date={date:yyyy-MM-dd}";
        var list = await GetAsync<IReadOnlyList<CashierBillSummaryDto>>(
            $"/api/employees/{employeeId}/cashier/bills?branchId={branchId}&take={take}{dateQs}",
            cancellationToken);
        return list ?? Array.Empty<CashierBillSummaryDto>();
    }

    public Task<CashierReportDto?> GetReportAsync(
        int employeeId,
        int branchId,
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var dateQs = date is null ? "" : $"&date={date:yyyy-MM-dd}";
        return GetAsync<CashierReportDto>(
            $"/api/employees/{employeeId}/cashier/report?branchId={branchId}{dateQs}",
            cancellationToken);
    }

    public Task<BranchCashierReportDto?> GetBranchReportAsync(
        int branchId,
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var dateQs = date is null ? "" : $"?date={date:yyyy-MM-dd}";
        return GetAsync<BranchCashierReportDto>(
            $"/api/branches/{branchId}/cashier/report{dateQs}",
            cancellationToken);
    }
}
