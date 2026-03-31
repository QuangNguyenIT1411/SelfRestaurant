using System.Collections.Generic;
using SelfRestaurant;

namespace SelfRestaurant.Areas.Admin.Models
{
    public class AdminDashboardViewModel
    {
        public int TotalEmployees { get; set; }
        public int ActiveEmployees { get; set; }
        public int BranchCount { get; set; }
        public int TodayOrders { get; set; }
        public int PendingOrders { get; set; }
        public decimal TodayRevenue { get; set; }
        public List<Employees> LatestEmployees { get; set; }
    }
}
