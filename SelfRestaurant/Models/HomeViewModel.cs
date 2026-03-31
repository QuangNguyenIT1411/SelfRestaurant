using System;
using System.Collections.Generic;

namespace SelfRestaurant.Models
{
    // ViewModel cho trang chủ
    public class HomeViewModel
    {
        public List<BranchViewModel> Branches { get; set; }

        public HomeViewModel()
        {
            Branches = new List<BranchViewModel>();
        }
    }

    // ViewModel cho chi nhánh
    public class BranchViewModel
    {
        public int BranchID { get; set; }
        public string Name { get; set; }
        public string Location { get; set; }
    }

    // ViewModel cho danh mục món ăn
    public class CategoryViewModel
    {
        public int CategoryID { get; set; }
        public string CategoryName { get; set; }
        public List<DishViewModel> Dishes { get; set; }

        public CategoryViewModel()
        {
            Dishes = new List<DishViewModel>();
        }
    }

    // ViewModel cho món ăn
    public class DishViewModel
    {
        public int DishID { get; set; }
        public string Name { get; set; }
        public decimal Price { get; set; }
        public string Image { get; set; }
        public string Description { get; set; }
        public string Unit { get; set; }
        public bool? IsVegetarian { get; set; }
        public bool? IsDailySpecial { get; set; }
    }

    // ViewModel cho bàn
    public class TableViewModel
    {
        public int TableID { get; set; }
        public int NumberOfSeats { get; set; }
        public string StatusCode { get; set; }
        public string StatusName { get; set; }
        public string QRCode { get; set; }
        public bool IsAvailable { get; set; }
    }

    // ViewModel cho đơn hàng
    public class OrderViewModel
    {
        public int OrderID { get; set; }
        public string OrderCode { get; set; }
        public DateTime OrderTime { get; set; }
        public int? TableID { get; set; }
        public int? CustomerID { get; set; }
        public string Note { get; set; }
        public List<OrderItemViewModel> Items { get; set; }
        public decimal TotalAmount { get; set; }

        public OrderViewModel()
        {
            Items = new List<OrderItemViewModel>();
        }
    }

    // ViewModel cho chi tiết đơn hàng
    public class OrderItemViewModel
    {
        public int DishID { get; set; }
        public string DishName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal LineTotal { get; set; }
        public string Note { get; set; }
    }

    // Request model cho tạo đơn hàng
    public class CreateOrderRequest
    {
        public int BranchID { get; set; }
        public int TableID { get; set; }
        public int? CustomerID { get; set; }
        public string Note { get; set; }
        public List<OrderItemRequest> Items { get; set; }

        public CreateOrderRequest()
        {
            Items = new List<OrderItemRequest>();
        }
    }

    // Request model cho món trong đơn hàng
    public class OrderItemRequest
    {
        public int DishID { get; set; }
        public int Quantity { get; set; }
        public string Note { get; set; }
    }
}