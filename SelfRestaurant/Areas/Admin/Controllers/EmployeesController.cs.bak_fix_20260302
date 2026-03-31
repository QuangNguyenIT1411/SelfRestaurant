using System;
using System.Data.Entity;
using System.Linq;
using System.Net;
using System.Web.Mvc;
using SelfRestaurant.Areas.Admin.Models;
using SelfRestaurant.Controllers;
using SelfRestaurant.Filters;
using SelfRestaurant.Models;

namespace SelfRestaurant.Areas.Admin.Controllers
{
    [Authorize]
    [AdminOnly]
    public class EmployeesController : BaseController
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        // GET: Admin/Employees
        public ActionResult Index(string search, int? branchId, int? roleId, int page = 1)
        {
            ViewBag.ActiveNav = "Employees";
            var query = db.Employees
                .Include(e => e.Branches)
                .Include(e => e.EmployeeRoles);

            if (!string.IsNullOrWhiteSpace(search))
            {
                query = query.Where(e =>
                    e.Name.Contains(search) ||
                    e.Username.Contains(search) ||
                    (e.Phone != null && e.Phone.Contains(search)) ||
                    (e.Email != null && e.Email.Contains(search)));
            }

            if (branchId.HasValue)
            {
                query = query.Where(e => e.BranchID == branchId.Value);
            }

            if (roleId.HasValue)
            {
                query = query.Where(e => e.RoleID == roleId.Value);
            }

            const int pageSize = 10;
            if (page < 1) page = 1;

            var ordered = query
                .OrderByDescending(e => e.CreatedAt ?? e.UpdatedAt ?? DateTime.MinValue)
                .ThenBy(e => e.Name);

            var totalItems = ordered.Count();
            var employees = ordered
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToList();

            PopulateDropdowns(branchId, roleId);
            ViewBag.SearchTerm = search;
            ViewBag.Page = page;
            ViewBag.TotalPages = (int)Math.Ceiling(totalItems / (double)pageSize);
            ViewBag.SuccessMessage = TempData["SuccessMessage"];
            ViewBag.ErrorMessage = TempData["ErrorMessage"];

            return View(employees);
        }

        // GET: Admin/Employees/Create
        public ActionResult Create()
        {
            ViewBag.ActiveNav = "Employees";
            PopulateDropdowns();
            var model = new Employees
            {
                IsActive = true
            };
            return View(model);
        }

        // POST: Admin/Employees/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Create([Bind(Include = "Name,Username,Password,Phone,Email,Salary,Shift,IsActive,BranchID,RoleID")] Employees employee)
        {
            ViewBag.ActiveNav = "Employees";
            ValidateEmployee(employee, null);

            if (ModelState.IsValid)
            {
                employee.CreatedAt = DateTime.Now;
                employee.UpdatedAt = DateTime.Now;

                if (!employee.IsActive.HasValue)
                {
                    employee.IsActive = true;
                }

                db.Employees.Add(employee);
                db.SaveChanges();

                TempData["SuccessMessage"] = "Thêm nhân viên mới thành công.";
                return RedirectToAction("Index");
            }

            PopulateDropdowns(employee.BranchID, employee.RoleID);
            return View(employee);
        }

        // GET: Admin/Employees/Edit/5
        public ActionResult Edit(int? id)
        {
            ViewBag.ActiveNav = "Employees";
            if (id == null)
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            }

            var employee = db.Employees.Find(id);
            if (employee == null)
            {
                return HttpNotFound();
            }

            PopulateDropdowns(employee.BranchID, employee.RoleID);
            return View(employee);
        }

        // POST: Admin/Employees/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Edit([Bind(Include = "EmployeeID,Name,Username,Password,Phone,Email,Salary,Shift,IsActive,BranchID,RoleID")] Employees employee)
        {
            ViewBag.ActiveNav = "Employees";
            ValidateEmployee(employee, employee.EmployeeID);

            var existing = db.Employees.Find(employee.EmployeeID);
            if (existing == null)
            {
                return HttpNotFound();
            }

            if (ModelState.IsValid)
            {
                existing.Name = employee.Name;
                existing.Username = employee.Username;

                if (!string.IsNullOrWhiteSpace(employee.Password))
                {
                    existing.Password = employee.Password;
                }

                existing.Phone = employee.Phone;
                existing.Email = employee.Email;
                existing.Salary = employee.Salary;
                existing.Shift = employee.Shift;
                existing.IsActive = employee.IsActive ?? false;
                existing.BranchID = employee.BranchID;
                existing.RoleID = employee.RoleID;
                existing.UpdatedAt = DateTime.Now;

                db.SaveChanges();

                TempData["SuccessMessage"] = "Cập nhật nhân viên thành công.";
                return RedirectToAction("Index");
            }

            PopulateDropdowns(employee.BranchID, employee.RoleID);
            return View(employee);
        }

        // POST: Admin/Employees/Delete/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Delete(int id)
        {
            var employee = db.Employees.Find(id);
            if (employee == null)
            {
                return HttpNotFound();
            }

            employee.IsActive = false;
            employee.UpdatedAt = DateTime.Now;
            db.SaveChanges();

            TempData["SuccessMessage"] = "Đã vô hiệu hóa nhân viên.";
            return RedirectToAction("Index");
        }

        private void PopulateDropdowns(int? branchId = null, int? roleId = null)
        {
            ViewBag.BranchID = new SelectList(
                db.Branches.OrderBy(b => b.Name).ToList(),
                "BranchID",
                "Name",
                branchId);

            ViewBag.RoleID = new SelectList(
                db.EmployeeRoles.OrderBy(r => r.RoleName).ToList(),
                "RoleID",
                "RoleName",
                roleId);
        }

        private void ValidateEmployee(Employees employee, int? currentEmployeeId)
        {
            if (string.IsNullOrWhiteSpace(employee.Username))
            {
                ModelState.AddModelError("Username", "Vui lòng nhập tên đăng nhập.");
            }

            var usernameExists = db.Employees.Any(e => e.Username == employee.Username && e.EmployeeID != currentEmployeeId);
            if (usernameExists)
            {
                ModelState.AddModelError("Username", "Tên đăng nhập đã tồn tại.");
            }

            if (!currentEmployeeId.HasValue && string.IsNullOrWhiteSpace(employee.Password))
            {
                ModelState.AddModelError("Password", "Vui lòng nhập mật khẩu.");
            }

            if (employee.BranchID <= 0)
            {
                ModelState.AddModelError("BranchID", "Vui lòng chọn chi nhánh.");
            }

            if (employee.RoleID <= 0)
            {
                ModelState.AddModelError("RoleID", "Vui lòng chọn vai trò.");
            }
        }

        // GET: Admin/Employees/History/5
        public ActionResult History(int? id)
        {
            ViewBag.ActiveNav = "Employees";
            if (id == null)
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            }

            var employee = db.Employees
                .Include(e => e.EmployeeRoles)
                .Include(e => e.Branches)
                .FirstOrDefault(e => e.EmployeeID == id.Value);

            if (employee == null)
            {
                return HttpNotFound();
            }

            var vm = new EmployeeWorkHistoryViewModel
            {
                Employee = employee
            };

            var roleCode = employee.EmployeeRoles != null
                ? employee.EmployeeRoles.RoleCode
                : null;

            // Lịch sử cho nhân viên bếp (CHEF / KITCHEN_STAFF)
            if (roleCode == "CHEF" || roleCode == "KITCHEN_STAFF")
            {
                var fromDate = DateTime.Today.AddDays(-90);

                var historyQuery = db.Orders
                    .Include(o => o.DiningTables.Branches)
                    .Include(o => o.OrderStatus)
                    .Include(o => o.OrderItems.Select(oi => oi.Dishes))
                    .Where(o => o.IsActive == true
                                && o.OrderTime >= fromDate);

                // Lọc theo chi nhánh nhân viên (nếu có)
                if (employee.BranchID > 0)
                {
                    historyQuery = historyQuery.Where(o => o.DiningTables.Branches.BranchID == employee.BranchID);
                }

                var historyOrders = historyQuery
                    .OrderByDescending(o => o.CompletedTime ?? o.OrderTime)
                    .Take(200)
                    .ToList();

                foreach (var order in historyOrders)
                {
                    var dishesSummary = string.Join(", ",
                        order.OrderItems.Select(oi =>
                            string.Format("{0}x {1}", oi.Quantity, oi.Dishes != null ? oi.Dishes.Name : "Món")));

                    vm.ChefHistory.Add(new ChefWorkHistoryViewModel
                    {
                        OrderID = order.OrderID,
                        OrderCode = order.OrderCode,
                        OrderTime = order.OrderTime,
                        CompletedTime = order.CompletedTime,
                        TableName = order.DiningTables != null
                            ? (order.DiningTables.QRCode ?? ("Bàn " + order.DiningTables.TableID))
                            : null,
                        BranchName = order.DiningTables != null && order.DiningTables.Branches != null
                            ? order.DiningTables.Branches.Name
                            : null,
                        StatusCode = order.OrderStatus != null ? order.OrderStatus.StatusCode : null,
                        StatusName = order.OrderStatus != null ? order.OrderStatus.StatusName : null,
                        DishesSummary = dishesSummary
                    });
                }
            }

            // Lịch sử cho nhân viên thu ngân (CASHIER)
            if (roleCode == "CASHIER")
            {
                var fromDate = DateTime.Today.AddDays(-90);

                var billsQuery = from b in db.Bills
                                 join o in db.Orders on b.OrderID equals o.OrderID into oj
                                 from o in oj.DefaultIfEmpty()
                                 join c in db.Customers on b.CustomerID equals c.CustomerID into cj
                                 from c in cj.DefaultIfEmpty()
                                 where b.IsActive == true
                                       && b.EmployeeID == employee.EmployeeID
                                       && b.BillTime >= fromDate
                                 orderby b.BillTime descending
                                 select new
                                 {
                                     Bill = b,
                                     Order = o,
                                     Customer = c,
                                     Table = o.DiningTables
                                 };

                var billList = billsQuery.Take(200).ToList();

                foreach (var x in billList)
                {
                    vm.CashierHistory.Add(new CashierBillHistoryViewModel
                    {
                        BillID = x.Bill.BillID,
                        BillCode = x.Bill.BillCode,
                        BillTime = x.Bill.BillTime,
                        OrderCode = x.Order != null ? x.Order.OrderCode : null,
                        TableName = x.Table != null
                            ? (x.Table.QRCode ?? ("Bàn " + x.Table.TableID))
                            : null,
                        Subtotal = x.Bill.Subtotal,
                        Discount = x.Bill.Discount,
                        PointsDiscount = x.Bill.PointsDiscount,
                        PointsUsed = x.Bill.PointsUsed,
                        TotalAmount = x.Bill.TotalAmount,
                        PaymentMethod = x.Bill.PaymentMethod,
                        PaymentAmount = x.Bill.PaymentAmount,
                        ChangeAmount = x.Bill.ChangeAmount,
                        CustomerName = x.Customer != null ? x.Customer.Name : null
                    });
                }
            }

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
