using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;

public sealed class AdminEmployeesIndexViewModel
{
    public IReadOnlyList<AdminEmployeeDto> Items { get; init; } = Array.Empty<AdminEmployeeDto>();
    public IReadOnlyList<BranchDto> Branches { get; init; } = Array.Empty<BranchDto>();
    public IReadOnlyList<EmployeeRoleDto> Roles { get; init; } = Array.Empty<EmployeeRoleDto>();

    public string? Search { get; init; }
    public int? BranchId { get; init; }
    public int? RoleId { get; init; }
    public int Page { get; init; }
    public int TotalPages { get; init; }
    public int TotalItems { get; init; }
}

public sealed class AdminEmployeeFormViewModel
{
    public int? EmployeeId { get; init; }
    public string Name { get; init; } = "";
    public string Username { get; init; } = "";
    public string? Password { get; init; }
    public string? Phone { get; init; }
    public string? Email { get; init; }
    public decimal? Salary { get; init; }
    public string? Shift { get; init; }
    public bool IsActive { get; init; } = true;
    public int BranchId { get; init; }
    public int RoleId { get; init; }

    public IReadOnlyList<BranchDto> Branches { get; init; } = Array.Empty<BranchDto>();
    public IReadOnlyList<EmployeeRoleDto> Roles { get; init; } = Array.Empty<EmployeeRoleDto>();
}

public sealed class AdminEmployeeHistoryViewModel
{
    public AdminEmployeeHistoryMetaDto Employee { get; init; } = new(0, "", "", "", 0, "");
    public IReadOnlyList<AdminChefHistoryItemDto> ChefHistory { get; init; } = Array.Empty<AdminChefHistoryItemDto>();
    public IReadOnlyList<AdminCashierHistoryItemDto> CashierHistory { get; init; } = Array.Empty<AdminCashierHistoryItemDto>();
}
