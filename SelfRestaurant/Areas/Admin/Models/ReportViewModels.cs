using System;
using System.Collections.Generic;

namespace SelfRestaurant.Areas.Admin.Models
{
    public class RevenueReportRow
    {
        public DateTime? OrderDate { get; set; }
        public string BranchName { get; set; }
        public int TotalOrders { get; set; }
        public decimal TotalRevenue { get; set; }
    }

    public class RevenueReportViewModel
    {
        public decimal TotalRevenue { get; set; }
        public List<RevenueReportRow> RevenueByBranchDate { get; set; }

        public RevenueReportViewModel()
        {
            RevenueByBranchDate = new List<RevenueReportRow>();
        }
    }

    public class TopDishRow
    {
        public string DishName { get; set; }
        public string CategoryName { get; set; }
        public int TotalQuantity { get; set; }
        public decimal TotalRevenue { get; set; }
    }

    public class TopDishReportViewModel
    {
        public List<TopDishRow> Items { get; set; }

        public TopDishReportViewModel()
        {
            Items = new List<TopDishRow>();
        }
    }
}
