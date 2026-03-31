using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;

public sealed class CashierReportViewModel
{
    public DateOnly Date { get; init; }
    public int BillCount { get; init; }
    public decimal TotalRevenue { get; init; }
    public IReadOnlyList<CashierBillSummaryDto> Bills { get; init; } = Array.Empty<CashierBillSummaryDto>();

    public string EmployeeName { get; init; } = "";
    public string BranchName { get; init; } = "";
}
