namespace SelfRestaurant.Gateway.Mvc.Models;

public sealed class CustomerDashboardViewModel
{
    public int CustomerID { get; set; }
    public string Username { get; set; } = "";
    public string CustomerName { get; set; } = "";
    public string CustomerPhone { get; set; } = "";
    public string? CustomerEmail { get; set; }
    public string? CustomerAddress { get; set; }
    public string? Gender { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    public int LoyaltyPoints { get; set; }
    public List<CustomerDashboardOrderSummaryViewModel> Orders { get; set; } = new();
    public int TotalOrders { get; set; }
    public decimal TotalSpent { get; set; }
    public int PendingOrders { get; set; }
    public int CompletedOrders { get; set; }
}

public sealed class CustomerDashboardOrderSummaryViewModel
{
    public int OrderID { get; set; }
    public string? OrderCode { get; set; }
    public DateTime? OrderTime { get; set; }
    public DateTime? CompletedTime { get; set; }
    public string? StatusCode { get; set; }
    public string? StatusName { get; set; }
    public decimal TotalAmount { get; set; }
    public int ItemCount { get; set; }
    public string? TableNumber { get; set; }
    public string? Note { get; set; }

    public string FormattedOrderTime => OrderTime?.ToString("dd/MM/yyyy HH:mm") ?? "";
    public string FormattedTotalAmount => $"{TotalAmount:N0} ₫";

    public string StatusBadgeClass =>
        (StatusCode ?? string.Empty).ToUpperInvariant() switch
        {
            "PENDING" => "badge bg-warning text-dark",
            "CONFIRMED" => "badge bg-info",
            "PREPARING" => "badge bg-primary",
            "READY" => "badge bg-success",
            "SERVING" => "badge bg-primary",
            "COMPLETED" => "badge bg-success",
            "CANCELLED" => "badge bg-danger",
            _ => "badge bg-secondary"
        };
}
