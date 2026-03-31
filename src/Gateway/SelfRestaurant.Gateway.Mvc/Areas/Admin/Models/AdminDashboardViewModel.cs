namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;

public sealed class AdminDashboardViewModel
{
    public int TotalEmployees { get; set; }
    public int ActiveEmployees { get; set; }
    public int BranchCount { get; set; }
    public int TodayOrders { get; set; }
    public int PendingOrders { get; set; }
    public decimal TodayRevenue { get; set; }
    public List<AdminDashboardEmployeeViewModel> LatestEmployees { get; set; } = new();
}

public sealed class AdminDashboardEmployeeViewModel
{
    public int EmployeeID { get; set; }
    public string Name { get; set; } = "";
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public bool IsActive { get; set; }
    public AdminDashboardEmployeeRoleViewModel? EmployeeRoles { get; set; }
    public AdminDashboardBranchViewModel? Branches { get; set; }
}

public sealed class AdminDashboardEmployeeRoleViewModel
{
    public string RoleCode { get; set; } = "";
    public string RoleName { get; set; } = "";
}

public sealed class AdminDashboardBranchViewModel
{
    public string Name { get; set; } = "";
    public string? Location { get; set; }
}
