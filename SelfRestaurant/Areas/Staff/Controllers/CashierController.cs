using System;
using System.Linq;
using System.Web.Mvc;
using System.Data.Entity;
using Newtonsoft.Json;
using SelfRestaurant.Controllers;
using SelfRestaurant.Models;

namespace SelfRestaurant.Areas.Staff.Controllers
{
    [Authorize]
    public class CashierController : BaseController
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        // GET: Staff/Cashier/Index
        public ActionResult Index()
        {
            if (!HasRole("CASHIER", "ADMIN", "MANAGER"))
            {
                TempData["ErrorMessage"] = "Bạn không có quyền truy cập trang Thu Ngân.";
                return AccessDenied();
            }

            ViewBag.EmployeeName = CurrentEmployeeName;
            ViewBag.RoleName = Session["RoleName"];
            ViewBag.BranchName = Session["BranchName"];

            var model = BuildDashboard();

            ViewBag.CashierTablesJson = JsonConvert.SerializeObject(model.Tables);

            var ordersDict = model.Orders.ToDictionary(
                o => o.OrderID,
                o => new
                {
                    orderCode = o.OrderCode,
                    statusCode = o.StatusCode,
                    customerID = o.CustomerID,
                    // ✅ Truyền cả điểm thưởng hiện tại sang client
                    customerCreditPoints = o.CustomerCreditPoints,
                    items = o.Items.Select(i => new
                    {
                        name = i.DishName,
                        quantity = i.Quantity,
                        unitPrice = i.UnitPrice,
                        lineTotal = i.LineTotal,
                        image = i.Image
                    }).ToList()
                });
            ViewBag.CashierOrdersJson = JsonConvert.SerializeObject(ordersDict);
            ViewBag.TodayOrders = model.TodayOrders;
            ViewBag.TodayRevenue = model.TodayRevenue;

            return View(model);
        }

        // GET: Staff/Cashier/History
        public ActionResult History()
        {
            if (!HasRole("CASHIER", "ADMIN", "MANAGER"))
            {
                TempData["ErrorMessage"] = "Bạn không có quyền truy cập trang Thu Ngân.";
                return AccessDenied();
            }

            ViewBag.EmployeeName = CurrentEmployeeName;
            ViewBag.RoleName = Session["RoleName"];
            ViewBag.BranchName = Session["BranchName"];

            var model = BuildDashboard();
            return View(model);
        }

        // GET: Staff/Cashier/Report (báo cáo doanh thu theo ngày)
        public ActionResult Report(DateTime? date)
        {
            if (!HasRole("CASHIER", "ADMIN", "MANAGER"))
            {
                TempData["ErrorMessage"] = "Bạn không có quyền truy cập trang Thu Ngân.";
                return AccessDenied();
            }

            ViewBag.EmployeeName = CurrentEmployeeName;
            ViewBag.RoleName = Session["RoleName"];
            ViewBag.BranchName = Session["BranchName"];

            var model = new CashierDashboardViewModel();

            if (CurrentEmployeeId.HasValue)
            {
                int employeeId = CurrentEmployeeId.Value;
                DateTime targetDate = date?.Date ?? DateTime.Today;

                var dayBills = (from b in db.Bills
                                join o in db.Orders on b.OrderID equals o.OrderID into oj
                                from o in oj.DefaultIfEmpty()
                                join c in db.Customers on b.CustomerID equals c.CustomerID into cj
                                from c in cj.DefaultIfEmpty()
                                where b.IsActive == true
                                      && b.EmployeeID == employeeId
                                      && DbFunctions.TruncateTime(b.BillTime) == targetDate
                                orderby b.BillTime
                                select new
                                {
                                    Bill = b,
                                    Order = o,
                                    Customer = c,
                                    Table = o.DiningTables
                                }).ToList();

                foreach (var x in dayBills)
                {
                    model.Bills.Add(new CashierBillHistoryViewModel
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

            return View(model);
        }

        private CashierDashboardViewModel BuildDashboard()
        {
            var vm = new CashierDashboardViewModel();
            int? branchId = CurrentBranchId;

            // ✅ LẤY TẤT CẢ BÀN THUỘC CHI NHÁNH (nếu không có bàn cho chi nhánh đó thì lấy tất cả bàn)
            var baseTablesQuery = db.DiningTables
                .Include(t => t.TableStatus)
                .Where(t => t.IsActive == true);

            var tablesQuery = baseTablesQuery;

            if (branchId.HasValue)
            {
                tablesQuery = tablesQuery.Where(t => t.BranchID == branchId.Value);
            }

            var tablesList = tablesQuery
                .OrderBy(t => t.TableID)
                .ToList();

            // Trường hợp chi nhánh hiện tại chưa có bàn nào, fallback lấy tất cả bàn
            if (!tablesList.Any())
            {
                tablesList = baseTablesQuery
                    .OrderBy(t => t.TableID)
                    .ToList();
            }

            vm.Tables = tablesList
                .Select(t => new CashierTableViewModel
                {
                    TableID = t.TableID,
                    Number = t.QRCode ?? ("Bàn " + t.TableID),
                    Seats = t.NumberOfSeats,
                    Status = t.TableStatus != null ? t.TableStatus.StatusCode : "AVAILABLE",
                    OrderID = t.CurrentOrderID
                })
                .ToList();

            // ✅ LẤY TẤT CẢ ĐƠN HÀNG ĐANG HOẠT ĐỘNG CHO CÁC BÀN (PENDING/CONFIRMED/PREPARING/READY/SERVING/COMPLETED)
            var ordersQuery = db.Orders
                .Include(o => o.OrderStatus)
                .Include(o => o.OrderItems)
                .Include(o => o.Customers)
                .Where(o => o.IsActive == true
                    && (o.OrderStatus.StatusCode == "PENDING"
                        || o.OrderStatus.StatusCode == "CONFIRMED"
                        || o.OrderStatus.StatusCode == "PREPARING"
                        || o.OrderStatus.StatusCode == "READY"
                        || o.OrderStatus.StatusCode == "SERVING"
                        || o.OrderStatus.StatusCode == "COMPLETED"));

            if (branchId.HasValue)
            {
                ordersQuery = ordersQuery.Where(o => o.DiningTables.BranchID == branchId.Value);
            }

            // ✅ SỬA: Bỏ ép kiểu phức tạp trong query, lấy về List trước
            var orders = ordersQuery
                .Select(o => new
                {
                    o.OrderID,
                    o.OrderCode,
                    o.OrderTime,
                    o.CustomerID,
                    StatusCode = o.OrderStatus.StatusCode,
                    StatusName = o.OrderStatus.StatusName,
                    Items = o.OrderItems.Select(oi => new
                    {
                        DishName = oi.Dishes.Name,
                        Quantity = oi.Quantity,
                        UnitPrice = oi.UnitPrice,
                        LineTotal = oi.LineTotal,
                        Image = oi.Dishes.Image
                    }).ToList()
                })
                .ToList(); // ✅ ToList() ở đây để chuyển sang LINQ to Objects

            // ✅ Xử lý trong bộ nhớ (LINQ to Objects)
            foreach (var order in orders)
            {
                int currentPoints = 0;
                if (order.CustomerID.HasValue)
                {
                    // Lấy điểm thưởng mới nhất từ bảng Customers dựa theo CustomerID trong Bill/Order
                    currentPoints = db.Customers
                        .Where(c => c.CustomerID == order.CustomerID.Value)
                        .Select(c => c.LoyaltyPoints ?? 0)
                        .FirstOrDefault();
                }

                var orderVm = new CashierOrderViewModel
                {
                    OrderID = order.OrderID,
                    OrderCode = order.OrderCode,
                    StatusCode = order.StatusCode,
                    StatusName = order.StatusName,
                    CustomerID = order.CustomerID,
                    // ✅ Điểm thưởng (LoyaltyPoints) mới nhất của khách
                    CustomerCreditPoints = currentPoints
                };

                foreach (var item in order.Items)
                {
                    orderVm.Items.Add(new CashierOrderItemViewModel
                    {
                        DishName = item.DishName,
                        Quantity = item.Quantity,
                        UnitPrice = item.UnitPrice,
                        LineTotal = item.LineTotal,
                        Image = item.Image
                    });
                }

                vm.Orders.Add(orderVm);
            }

            // ✅ THỐNG KÊ CHỈ TÍNH ĐƠN ĐÃ HOÀN THÀNH (COMPLETED - StatusID = 6)
            var today = DateTime.Today;
            var todayCompletedOrders = db.Orders
                .Where(o => o.IsActive == true
                    && o.StatusID == 6
                    && DbFunctions.TruncateTime(o.OrderTime) == today);

            if (branchId.HasValue)
            {
                todayCompletedOrders = todayCompletedOrders.Where(o => o.DiningTables.BranchID == branchId.Value);
            }

            var todayOrdersList = todayCompletedOrders
                .Select(o => new
                {
                    Items = o.OrderItems.Select(oi => new { oi.LineTotal }).ToList()
                })
                .ToList();

            vm.TodayOrders = todayOrdersList.Count;
            vm.TodayRevenue = todayOrdersList.Sum(o => o.Items.Sum(i => i.LineTotal));

            // Lịch sử bill của thu ngân hiện tại (tối đa 50 bill gần nhất)
            if (CurrentEmployeeId.HasValue)
            {
                var employeeId = CurrentEmployeeId.Value;

                var recentBills = (from b in db.Bills
                                   join o in db.Orders.Include(o => o.DiningTables)
                                       on b.OrderID equals o.OrderID into oj
                                   from o in oj.DefaultIfEmpty()
                                   join c in db.Customers
                                       on b.CustomerID equals c.CustomerID into cj
                                   from c in cj.DefaultIfEmpty()
                                   where b.IsActive == true && b.EmployeeID == employeeId
                                   orderby b.BillTime descending
                                   select new
                                   {
                                       Bill = b,
                                       Order = o,
                                       Customer = c,
                                       Table = o.DiningTables
                                   })
                                   .Take(50)
                                   .ToList();

                foreach (var x in recentBills)
                {
                    vm.Bills.Add(new CashierBillHistoryViewModel
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

                // Thông tin tài khoản thu ngân
                var emp = db.Employees.Find(employeeId);
                if (emp != null)
                {
                    vm.Account = new CashierAccountViewModel
                    {
                        EmployeeID = emp.EmployeeID,
                        Name = emp.Name,
                        Username = emp.Username,
                        Email = emp.Email,
                        Phone = emp.Phone,
                        BranchName = Session["BranchName"]?.ToString(),
                        RoleName = Session["RoleName"]?.ToString()
                    };
                }
            }

            return vm;
        }

        // POST: Staff/Cashier/ProcessPayment
        [HttpPost]
        public JsonResult ProcessPayment(PaymentRequestModel model)
        {
            try
            {
                // Kiểm tra đơn hàng có tồn tại
                var order = db.Orders
                    .Include(o => o.DiningTables)
                    .Include(o => o.Customers)
                    .FirstOrDefault(o => o.OrderID == model.OrderID && o.IsActive == true);

                if (order == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy đơn hàng!" });
                }

                // Tính toán các giá trị cơ bản
                decimal subtotal = order.OrderItems.Sum(oi => oi.LineTotal);
                decimal discount = model.Discount < 0 ? 0 : model.Discount;

                if (discount > subtotal)
                {
                    discount = subtotal;
                }

                decimal baseTotal = subtotal - discount;

                // Xử lý điểm tín dụng: 1 điểm = 1 đ, nhưng không vượt quá 10% hóa đơn hiện tại
                int requestedPoints = model.PointsUsed < 0 ? 0 : model.PointsUsed;
                int usedPoints = 0;
                decimal maxPointsByPercent = Math.Floor(baseTotal * 0.10m); // 10% hóa đơn

                Customers customer = null;
                if (order.CustomerID.HasValue)
                {
                    customer = db.Customers.Find(order.CustomerID.Value);
                }

                if (requestedPoints > 0)
                {
                    if (customer == null)
                    {
                        return Json(new { success = false, message = "Đơn hàng không có thông tin khách hàng, không thể dùng điểm." });
                    }

                    int currentPoints = customer.LoyaltyPoints ?? 0;
                    int maxByCustomerBalance = currentPoints;
                    int maxByPercentInt = (int)maxPointsByPercent;
                    int maxUsable = Math.Min(requestedPoints, Math.Min(maxByCustomerBalance, maxByPercentInt));

                    if (maxUsable <= 0)
                    {
                        return Json(new { success = false, message = "Số điểm sử dụng vượt quá 10% giá trị hóa đơn hoặc lớn hơn số điểm hiện có." });
                    }

                    usedPoints = maxUsable;

                    // Trừ điểm thưởng đã sử dụng
                    currentPoints -= usedPoints;
                    if (currentPoints < 0) currentPoints = 0;
                    customer.LoyaltyPoints = currentPoints;
                }

                decimal pointsDiscount = usedPoints;
                decimal totalAmount = baseTotal - pointsDiscount;

                // Kiểm tra thanh toán tiền mặt
                if (model.PaymentMethod == "CASH" && model.PaymentAmount < totalAmount)
                {
                    return Json(new { success = false, message = "Không đủ tiền thanh toán hóa đơn." });
                }

                // Tạo Bill Code
                string billCode = "BILL" + DateTime.Now.ToString("yyyyMMddHHmmss");

                // Tạo Bills mới
                var bill = new Bills
                {
                    OrderID = order.OrderID,
                    BillCode = billCode,
                    BillTime = DateTime.Now,
                    Subtotal = subtotal,
                    Discount = discount,
                    PointsDiscount = pointsDiscount,
                    PointsUsed = usedPoints > 0 ? (int?)usedPoints : null,
                    TotalAmount = totalAmount,
                    PaymentMethod = model.PaymentMethod,
                    PaymentAmount = model.PaymentMethod == "CASH" ? model.PaymentAmount : totalAmount,
                    ChangeAmount = model.PaymentMethod == "CASH" ? model.PaymentAmount - totalAmount : 0,
                    EmployeeID = CurrentEmployeeId,
                    CustomerID = order.CustomerID,
                    IsActive = true
                };

                db.Bills.Add(bill);

                // Cộng điểm thưởng: 1% trên tổng tiền phải trả (sau giảm giá & dùng điểm)
                if (customer != null && totalAmount > 0)
                {
                    int earnedPoints = (int)Math.Floor(totalAmount * 0.01m);
                    if (earnedPoints > 0)
                    {
                        int currentPoints = customer.LoyaltyPoints ?? 0;
                        currentPoints += earnedPoints;
                        customer.LoyaltyPoints = currentPoints;
                    }
                }

                // Cập nhật trạng thái đơn hàng sang COMPLETED (StatusID = 6)
                order.StatusID = 6;

                // Cập nhật trạng thái bàn về AVAILABLE
                if (order.DiningTables != null)
                {
                    var availableStatus = db.TableStatus.FirstOrDefault(s => s.StatusCode == "AVAILABLE");
                    if (availableStatus != null)
                    {
                        order.DiningTables.StatusID = availableStatus.StatusID;
                        order.DiningTables.CurrentOrderID = null;
                    }
                }

                db.SaveChanges();

                return Json(new
                {
                    success = true,
                    message = "Thanh toán thành công!",
                    billCode = billCode,
                    changeAmount = bill.ChangeAmount
                });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // POST: Staff/Cashier/UpdateAccount
        [HttpPost]
        public JsonResult UpdateAccount(CashierAccountViewModel model)
        {
            try
            {
                if (!CurrentEmployeeId.HasValue)
                {
                    return Json(new { success = false, message = "Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại." });
                }

                var employee = db.Employees.Find(CurrentEmployeeId.Value);
                if (employee == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy tài khoản nhân viên." });
                }

                if (string.IsNullOrWhiteSpace(model.Name) ||
                    string.IsNullOrWhiteSpace(model.Email) ||
                    string.IsNullOrWhiteSpace(model.Phone))
                {
                    return Json(new { success = false, message = "Vui lòng điền đầy đủ họ tên, email và số điện thoại." });
                }

                employee.Name = model.Name.Trim();
                employee.Email = model.Email.Trim();
                employee.Phone = model.Phone.Trim();
                employee.UpdatedAt = DateTime.Now;

                db.SaveChanges();

                // Cập nhật lại Session hiển thị tên
                Session["EmployeeName"] = employee.Name;

                return Json(new { success = true, message = "Cập nhật thông tin tài khoản thành công." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // POST: Staff/Cashier/ChangePassword
        [HttpPost]
        public JsonResult ChangePassword(string currentPassword, string newPassword, string confirmPassword)
        {
            try
            {
                if (!CurrentEmployeeId.HasValue)
                {
                    return Json(new { success = false, message = "Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại." });
                }

                if (string.IsNullOrWhiteSpace(currentPassword) ||
                    string.IsNullOrWhiteSpace(newPassword) ||
                    string.IsNullOrWhiteSpace(confirmPassword))
                {
                    return Json(new { success = false, message = "Vui lòng điền đầy đủ thông tin mật khẩu." });
                }

                if (newPassword.Length < 6)
                {
                    return Json(new { success = false, message = "Mật khẩu mới phải có ít nhất 6 ký tự." });
                }

                if (newPassword != confirmPassword)
                {
                    return Json(new { success = false, message = "Mật khẩu mới và xác nhận không khớp." });
                }

                var employee = db.Employees.Find(CurrentEmployeeId.Value);
                if (employee == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy tài khoản nhân viên." });
                }

                if (employee.Password != currentPassword)
                {
                    return Json(new { success = false, message = "Mật khẩu hiện tại không đúng." });
                }

                employee.Password = newPassword;
                employee.UpdatedAt = DateTime.Now;
                db.SaveChanges();

                return Json(new { success = true, message = "Đổi mật khẩu thành công." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
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

    // Model cho Payment Request
    public class PaymentRequestModel
    {
        public int OrderID { get; set; }
        public decimal Discount { get; set; }
        public int PointsUsed { get; set; }
        public string PaymentMethod { get; set; }
        public decimal PaymentAmount { get; set; }
    }
}
