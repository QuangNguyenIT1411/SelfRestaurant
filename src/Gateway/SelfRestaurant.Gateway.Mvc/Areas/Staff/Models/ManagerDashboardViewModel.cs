using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;

public sealed class ManagerDashboardViewModel
{
    public string EmployeeName { get; init; } = "";
    public string RoleName { get; init; } = "";
    public string BranchName { get; init; } = "";
    public int BranchId { get; init; }

    public int PendingKitchenCount { get; init; }
    public int PreparingKitchenCount { get; init; }
    public int ReadyKitchenCount { get; init; }
    public int ActiveCashierOrdersCount { get; init; }

    public int TodayBillCount { get; init; }
    public decimal TodayRevenue { get; init; }

    public IReadOnlyList<ManagerTopDishItem> TopDishes { get; init; } = Array.Empty<ManagerTopDishItem>();
}

public sealed record ManagerTopDishItem(int DishId, string Name);
