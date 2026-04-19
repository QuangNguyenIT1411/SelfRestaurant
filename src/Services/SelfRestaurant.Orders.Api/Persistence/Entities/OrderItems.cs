namespace SelfRestaurant.Orders.Api.Persistence.Entities;

public sealed class OrderItems
{
    public int ItemID { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
    public string? Note { get; set; }
    public int OrderID { get; set; }
    public int DishID { get; set; }
}
