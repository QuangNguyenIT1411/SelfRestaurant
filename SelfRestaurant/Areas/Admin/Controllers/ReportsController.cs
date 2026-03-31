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
    public class ReportsController : BaseController
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        // GET: Admin/Reports/Revenue
        public ActionResult Revenue()
        {
            ViewBag.ActiveNav = "reports-revenue";
            ViewBag.EmployeeName = CurrentEmployeeName;
            ViewBag.BranchName = Session["BranchName"];
            ViewBag.RoleName = Session["RoleName"];

            var totalRevenue = db.OrderItems
                .Select(oi => (decimal?)oi.LineTotal)
                .DefaultIfEmpty(0)
                .Sum() ?? 0;

            var revenueRows = db.BranchRevenue
                .OrderByDescending(r => r.OrderDate)
                .ThenBy(r => r.BranchName)
                .Take(50)
                .ToList()
                .Select(r => new RevenueReportRow
                {
                    BranchName = r.BranchName,
                    OrderDate = r.OrderDate,
                    TotalOrders = r.TotalOrders ?? 0,
                    TotalRevenue = r.TotalRevenue ?? 0
                })
                .ToList();

            var vm = new RevenueReportViewModel
            {
                TotalRevenue = totalRevenue,
                RevenueByBranchDate = revenueRows
            };

            return View(vm);
        }

        // GET: Admin/Reports/TopDishes
        public ActionResult TopDishes()
        {
            ViewBag.ActiveNav = "reports-topdishes";
            ViewBag.EmployeeName = CurrentEmployeeName;
            ViewBag.BranchName = Session["BranchName"];
            ViewBag.RoleName = Session["RoleName"];

            var topDishes = db.OrderItems
                .Include(oi => oi.Dishes)
                .Include(oi => oi.Dishes.Categories)
                .Include(oi => oi.Orders)
                .Where(oi => oi.Orders == null || (oi.Orders.IsActive ?? false))
                .GroupBy(oi => new
                {
                    DishName = oi.Dishes != null ? oi.Dishes.Name : "Không rõ",
                    CategoryName = oi.Dishes != null && oi.Dishes.Categories != null ? oi.Dishes.Categories.Name : "Khác"
                })
                .Select(g => new TopDishRow
                {
                    DishName = g.Key.DishName,
                    CategoryName = g.Key.CategoryName,
                    TotalQuantity = g.Sum(x => (int?)x.Quantity ?? 0),
                    TotalRevenue = g.Sum(x => (decimal?)x.LineTotal ?? 0)
                })
                .OrderByDescending(x => x.TotalQuantity)
                .ThenByDescending(x => x.TotalRevenue)
                .Take(10)
                .ToList();

            var vm = new TopDishReportViewModel
            {
                Items = topDishes
            };

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
