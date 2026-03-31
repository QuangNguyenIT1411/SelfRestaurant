using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;

public sealed class AdminRevenueReportViewModel
{
    public int Days { get; init; } = 30;
    public decimal TotalRevenue { get; init; }
    public IReadOnlyList<AdminRevenueReportRowDto> Rows { get; init; } = Array.Empty<AdminRevenueReportRowDto>();
}

public sealed class AdminTopDishesReportViewModel
{
    public int Days { get; init; } = 30;
    public int Take { get; init; } = 10;
    public IReadOnlyList<AdminTopDishReportItemDto> Items { get; init; } = Array.Empty<AdminTopDishReportItemDto>();
}
