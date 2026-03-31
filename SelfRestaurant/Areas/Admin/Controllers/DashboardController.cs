using System;
using System.Data.Entity;
using System.Linq;
using System.Web.Mvc;
using SelfRestaurant.Areas.Admin.Models;
using SelfRestaurant.Controllers;
using SelfRestaurant.Filters;

namespace SelfRestaurant.Areas.Admin.Controllers
{
    [Authorize]
    [AdminOnly]
    public class DashboardController : BaseController
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        // GET: Admin/Dashboard
        public ActionResult Index()
        {
            ViewBag.ActiveNav = "Dashboard";
            var today = DateTime.Today;
            var pendingCodes = new[] { "PENDING", "CONFIRMED", "PREPARING" };

            var vm = new AdminDashboardViewModel
            {
                TotalEmployees = db.Employees.Count(),
                ActiveEmployees = db.Employees.Count(e => e.IsActive ?? false),
                BranchCount = db.Branches.Count(b => b.IsActive ?? false),
                TodayOrders = db.Orders.Count(o => DbFunctions.TruncateTime(o.OrderTime) == today && (o.IsActive ?? false)),
                PendingOrders = db.Orders.Count(o => (o.IsActive ?? false) && pendingCodes.Contains(o.OrderStatus.StatusCode)),
                TodayRevenue = db.OrderItems
                    .Where(oi => oi.Orders != null
                                 && DbFunctions.TruncateTime(oi.Orders.OrderTime) == today
                                 && (oi.Orders.IsActive ?? false))
                    .Select(oi => (decimal?)oi.LineTotal)
                    .DefaultIfEmpty(0)
                    .Sum() ?? 0,
                LatestEmployees = db.Employees
                    .Include(e => e.EmployeeRoles)
                    .Include(e => e.Branches)
                    .OrderByDescending(e => e.UpdatedAt ?? e.CreatedAt ?? DateTime.MinValue)
                    .Take(5)
                    .ToList()
            };

            ViewBag.EmployeeName = CurrentEmployeeName;
            ViewBag.BranchName = Session["BranchName"];
            ViewBag.RoleName = Session["RoleName"];

            return View(vm);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                db.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
