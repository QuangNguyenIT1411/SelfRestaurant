using SelfRestaurant.Gateway.Mvc.Models;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;

public sealed class AdminCustomersIndexViewModel
{
    public IReadOnlyList<AdminCustomerDto> Items { get; init; } = Array.Empty<AdminCustomerDto>();
    public string? Search { get; init; }
    public int Page { get; init; }
    public int TotalPages { get; init; }
    public int TotalItems { get; init; }
}

public sealed class AdminCustomerFormViewModel
{
    public int? CustomerId { get; init; }
    public string Name { get; init; } = "";
    public string Username { get; init; } = "";
    public string? Password { get; init; }
    public string PhoneNumber { get; init; } = "";
    public string? Email { get; init; }
    public string? Gender { get; init; }
    public DateOnly? DateOfBirth { get; init; }
    public string? Address { get; init; }
    public int LoyaltyPoints { get; init; }
    public bool IsActive { get; init; } = true;
}
