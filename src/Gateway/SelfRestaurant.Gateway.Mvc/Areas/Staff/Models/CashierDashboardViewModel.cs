namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Models;

public sealed class CashierDashboardViewModel
{
    public List<CashierTableViewModel> Tables { get; set; } = new();
    public List<CashierOrderViewModel> Orders { get; set; } = new();
    public int TodayOrders { get; set; }
    public decimal TodayRevenue { get; set; }
    public List<CashierBillHistoryViewModel> Bills { get; set; } = new();
    public CashierAccountViewModel Account { get; set; } = new();
}

public sealed class CashierTableViewModel
{
    public int TableID { get; set; }
    public string Number { get; set; } = "";
    public int Seats { get; set; }
    public string Status { get; set; } = "";
    public int? OrderID { get; set; }
}

public sealed class CashierOrderViewModel
{
    public int OrderID { get; set; }
    public string OrderCode { get; set; } = "";
    public string StatusCode { get; set; } = "";
    public string StatusName { get; set; } = "";
    public int? CustomerID { get; set; }
    public string CustomerName { get; set; } = "";
    public int CustomerCreditPoints { get; set; }
    public List<CashierOrderItemViewModel> Items { get; set; } = new();
}

public sealed class CashierOrderItemViewModel
{
    public string DishName { get; set; } = "";
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
    public string Image { get; set; } = "";
}

public sealed class CashierBillHistoryViewModel
{
    public int BillID { get; set; }
    public string BillCode { get; set; } = "";
    public DateTime BillTime { get; set; }
    public string OrderCode { get; set; } = "";
    public string TableName { get; set; } = "";
    public decimal Subtotal { get; set; }
    public decimal Discount { get; set; }
    public decimal PointsDiscount { get; set; }
    public int? PointsUsed { get; set; }
    public decimal TotalAmount { get; set; }
    public string PaymentMethod { get; set; } = "";
    public decimal? PaymentAmount { get; set; }
    public decimal? ChangeAmount { get; set; }
    public string CustomerName { get; set; } = "";
}

public sealed class CashierAccountViewModel
{
    public int EmployeeID { get; set; }
    public string Name { get; set; } = "";
    public string Username { get; set; } = "";
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public string BranchName { get; set; } = "";
    public string RoleName { get; set; } = "";
}
