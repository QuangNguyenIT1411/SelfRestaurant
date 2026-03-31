namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;

public sealed class ChefDashboardViewModel
{
    public List<ChefOrderViewModel> PendingOrders { get; set; } = new();
    public List<ChefOrderViewModel> PreparingOrders { get; set; } = new();
    public List<ChefOrderViewModel> ReadyOrders { get; set; } = new();

    public int PendingOrdersCount { get; set; }
    public int PreparingOrdersCount { get; set; }
    public int ReadyOrdersCount { get; set; }

    public ChefMenuViewModel TodayMenu { get; set; } = new();
    public List<ChefWorkHistoryViewModel> History { get; set; } = new();
    public ChefAccountViewModel Account { get; set; } = new();
}

public sealed class ChefOrderViewModel
{
    public int OrderID { get; set; }
    public string OrderCode { get; set; } = "";
    public DateTime OrderTime { get; set; }
    public string TableName { get; set; } = "";
    public int TableSeats { get; set; }
    public string BranchName { get; set; } = "";
    public string StatusCode { get; set; } = "";
    public string StatusName { get; set; } = "";
    public List<ChefOrderItemViewModel> Items { get; set; } = new();
}

public sealed class ChefOrderItemViewModel
{
    public int ItemID { get; set; }
    public int DishID { get; set; }
    public string DishName { get; set; } = "";
    public int Quantity { get; set; }
    public string Unit { get; set; } = "";
    public string Note { get; set; } = "";
    public bool IsVegetarian { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class ChefMenuViewModel
{
    public int MenuID { get; set; }
    public string MenuName { get; set; } = "";
    public DateTime MenuDate { get; set; }
    public int BranchID { get; set; }
    public string BranchName { get; set; } = "";
    public List<ChefDishViewModel> Dishes { get; set; } = new();
}

public sealed class ChefDishViewModel
{
    public int DishID { get; set; }
    public string Name { get; set; } = "";
    public decimal Price { get; set; }
    public string Unit { get; set; } = "";
    public int CategoryID { get; set; }
    public string CategoryName { get; set; } = "";
    public string Image { get; set; } = "";
    public string Description { get; set; } = "";
    public bool Available { get; set; }
    public bool IsVegetarian { get; set; }
    public bool IsDailySpecial { get; set; }
}

public sealed class ChefWorkHistoryViewModel
{
    public int OrderID { get; set; }
    public string OrderCode { get; set; } = "";
    public DateTime OrderTime { get; set; }
    public DateTime? CompletedTime { get; set; }
    public string TableName { get; set; } = "";
    public string BranchName { get; set; } = "";
    public string StatusCode { get; set; } = "";
    public string StatusName { get; set; } = "";
    public string DishesSummary { get; set; } = "";

    public string StatusBadgeClass =>
        StatusCode switch
        {
            "PENDING" => "badge bg-warning text-dark",
            "CONFIRMED" => "badge bg-warning text-dark",
            "PREPARING" => "badge bg-primary",
            "SERVING" => "badge bg-primary",
            "READY" => "badge bg-success",
            "COMPLETED" => "badge bg-success",
            "CANCELLED" => "badge bg-danger",
            _ => "badge bg-secondary"
        };
}

public sealed class ChefAccountViewModel
{
    public int EmployeeID { get; set; }
    public string Name { get; set; } = "";
    public string Username { get; set; } = "";
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public string BranchName { get; set; } = "";
    public string RoleName { get; set; } = "";
}
