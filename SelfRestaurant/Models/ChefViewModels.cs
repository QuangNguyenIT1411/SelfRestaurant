using System;
using System.Collections.Generic;

namespace SelfRestaurant.Models
{
    /// <summary>
    /// ViewModel chính cho Dashboard của Chef
    /// </summary>
    public class ChefDashboardViewModel
    {
        public List<ChefOrderViewModel> PendingOrders { get; set; }
        public List<ChefOrderViewModel> PreparingOrders { get; set; }
        public List<ChefOrderViewModel> ReadyOrders { get; set; }

        public int PendingOrdersCount { get; set; }
        public int PreparingOrdersCount { get; set; }
        public int ReadyOrdersCount { get; set; }

        public ChefMenuViewModel TodayMenu { get; set; }

        // Lịch sử các đơn/món đã chế biến
        public List<ChefWorkHistoryViewModel> History { get; set; }

        // Thông tin tài khoản của nhân viên bếp hiện tại
        public ChefAccountViewModel Account { get; set; }

        public ChefDashboardViewModel()
        {
            PendingOrders = new List<ChefOrderViewModel>();
            PreparingOrders = new List<ChefOrderViewModel>();
            ReadyOrders = new List<ChefOrderViewModel>();
            TodayMenu = new ChefMenuViewModel();
            History = new List<ChefWorkHistoryViewModel>();
            Account = new ChefAccountViewModel();
        }
    }

    /// <summary>
    /// ViewModel cho Đơn hàng
    /// </summary>
    public class ChefOrderViewModel
    {
        public int OrderID { get; set; }
        public string OrderCode { get; set; }
        public DateTime OrderTime { get; set; }
        public string TableName { get; set; }
        public int TableSeats { get; set; }
        public string BranchName { get; set; }
        public string StatusCode { get; set; }
        public string StatusName { get; set; }
        public List<ChefOrderItemViewModel> Items { get; set; }

        public ChefOrderViewModel()
        {
            Items = new List<ChefOrderItemViewModel>();
        }
    }

    /// <summary>
    /// ViewModel cho Chi tiết Đơn hàng
    /// </summary>
    public class ChefOrderItemViewModel
    {
        public int ItemID { get; set; }
        public int DishID { get; set; }
        public string DishName { get; set; }
        public int Quantity { get; set; }
        public string Unit { get; set; }
        public string Note { get; set; }
        public bool IsVegetarian { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    /// <summary>
    /// ViewModel cho Thực đơn hôm nay
    /// </summary>
    public class ChefMenuViewModel
    {
        public int MenuID { get; set; }
        public string MenuName { get; set; }
        public DateTime MenuDate { get; set; }
        public int BranchID { get; set; }
        public string BranchName { get; set; }
        public List<ChefDishViewModel> Dishes { get; set; }

        public ChefMenuViewModel()
        {
            Dishes = new List<ChefDishViewModel>();
        }
    }

    /// <summary>
    /// ViewModel cho Món ăn
    /// </summary>
    public class ChefDishViewModel
    {
        public int DishID { get; set; }
        public string Name { get; set; }
        public decimal Price { get; set; }
        public string Unit { get; set; }
        public int CategoryID { get; set; }
        public string CategoryName { get; set; }
        public string Image { get; set; }
        public string Description { get; set; }
        public bool Available { get; set; }
        public bool IsVegetarian { get; set; }
        public bool IsDailySpecial { get; set; }
    }

    /// <summary>
    /// ViewModel cho lịch sử làm việc (các món/đơn đã chế biến)
    /// </summary>
    public class ChefWorkHistoryViewModel
    {
        public int OrderID { get; set; }
        public string OrderCode { get; set; }
        public DateTime OrderTime { get; set; }
        public DateTime? CompletedTime { get; set; }
        public string TableName { get; set; }
        public string BranchName { get; set; }
        public string StatusCode { get; set; }
        public string StatusName { get; set; }
        public string DishesSummary { get; set; }

        /// <summary>
        /// Badge màu cho trạng thái (để hiển thị trong lịch sử).
        /// </summary>
        public string StatusBadgeClass
        {
            get
            {
                switch (StatusCode)
                {
                    case "PENDING":
                    case "CONFIRMED":
                        return "badge bg-warning text-dark";
                    case "PREPARING":
                    case "SERVING":
                        return "badge bg-primary";
                    case "READY":
                    case "COMPLETED":
                        return "badge bg-success";
                    case "CANCELLED":
                        return "badge bg-danger";
                    default:
                        return "badge bg-secondary";
                }
            }
        }
    }

    /// <summary>
    /// ViewModel cho thông tin tài khoản của nhân viên bếp
    /// </summary>
    public class ChefAccountViewModel
    {
        public int EmployeeID { get; set; }
        public string Name { get; set; }
        public string Username { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string BranchName { get; set; }
        public string RoleName { get; set; }
    }
}
