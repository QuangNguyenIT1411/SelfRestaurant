using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;

public sealed class CashierHistoryViewModel
{
    public DateOnly Date { get; init; }
    public IReadOnlyList<CashierBillSummaryDto> Bills { get; init; } = Array.Empty<CashierBillSummaryDto>();

    public int EmployeeId { get; init; }
    public string EmployeeName { get; init; } = "";
    public string EmployeeUsername { get; init; } = "";
    public string? EmployeeEmail { get; init; }
    public string? EmployeePhone { get; init; }
    public string RoleName { get; init; } = "";
    public int BranchId { get; init; }
    public string BranchName { get; init; } = "";
}
