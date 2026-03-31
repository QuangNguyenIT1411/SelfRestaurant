using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Data.Entity;
using SelfRestaurant.Models;

namespace SelfRestaurant.Controllers
{
    public class MenuController : Controller
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        /// <summary>
        /// Truy cập menu từ mã QR bàn.
        /// Khách quét mã QR -> nếu chưa đăng nhập sẽ chuyển tới trang đăng nhập,
        /// đăng nhập xong quay lại đây và tự vào Menu/Index đúng bàn/chi nhánh.
        /// </summary>
        public ActionResult FromQr(string code)
        {
            if (string.IsNullOrWhiteSpace(code))
            {
                TempData["Error"] = "Mã QR không hợp lệ.";
                return RedirectToAction("Index", "Home");
            }

            try
            {
                var table = db.DiningTables
                    .Include(t => t.Branches)
                    .FirstOrDefault(t => t.QRCode == code && (t.IsActive ?? true));

                if (table == null)
                {
                    TempData["Error"] = "Không tìm thấy bàn tương ứng với mã QR.";
                    return RedirectToAction("Index", "Home");
                }

                // Nếu chưa đăng nhập khách hàng => chuyển sang Customer/Login với returnUrl
                if (Session["CustomerID"] == null)
                {
                    var returnUrl = Url.Action("FromQr", "Menu", new { code = code });
                    return RedirectToAction("Login", "Customer", new { returnUrl = returnUrl });
                }

                // Đã đăng nhập => đi thẳng vào menu
                return RedirectToAction("Index", new { tableId = table.TableID, branchId = table.BranchID });
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Có lỗi xảy ra: " + ex.Message;
                return RedirectToAction("Index", "Home");
            }
        }

        // GET: Menu/Index?tableId=12&branchId=1
        public ActionResult Index(int? tableId, int? branchId)
        {
            if (tableId == null || branchId == null)
            {
                TempData["Error"] = "Vui lòng chọn bàn";
                return RedirectToAction("Index", "Home");
            }

            // Bắt buộc khách hàng phải đăng nhập trước khi đặt món
            if (Session["CustomerID"] == null)
            {
                TempData["Error"] = "Vui lòng đăng nhập tài khoản khách hàng trước khi đặt món.";
                return RedirectToAction("Login", "Customer");
            }

            try
            {
                // Lấy thông tin bàn
                var table = db.DiningTables
                    .Include(t => t.Branches)
                    .Include(t => t.TableStatus)
                    .FirstOrDefault(t => t.TableID == tableId && t.BranchID == branchId);

                if (table == null)
                {
                    TempData["Error"] = "Không tìm thấy bàn";
                    return RedirectToAction("Index", "Home");
                }

                // Lấy menu của chi nhánh
                var today = DateTime.Today;
                var menu = db.Menus
                    .Where(m => m.BranchID == branchId && m.IsActive == true)
                    .OrderByDescending(m => m.Date)
                    .FirstOrDefault();

                // Nếu không có menu, tạo mới
                if (menu == null || menu.Date != today)
                {
                    menu = CreateDailyMenu(branchId.Value, table.Branches.Name, today);
                }

                // Lấy các categories và dishes
                var categories = db.MenuCategory
                    .Where(mc => mc.MenuID == menu.MenuID && mc.IsActive == true)
                    .OrderBy(mc => mc.Categories.DisplayOrder)
                    .Select(mc => new CategoryViewModel
                    {
                        CategoryID = mc.CategoryID,
                        CategoryName = mc.Categories.Name,
                        Dishes = db.CategoryDish
                            .Where(cd => cd.MenuCategoryID == mc.MenuCategoryID && cd.IsAvailable == true)
                            .OrderBy(cd => cd.DisplayOrder)
                            .Select(cd => new DishViewModel
                            {
                                DishID = cd.Dishes.DishID,
                                Name = cd.Dishes.Name,
                                Price = cd.Dishes.Price,
                                Image = cd.Dishes.Image,
                                Description = cd.Dishes.Description,
                                Unit = cd.Dishes.Unit,
                                IsVegetarian = cd.Dishes.IsVegetarian
                            })
                            .ToList()
                    })
                    .ToList();

                // Chuẩn bị dữ liệu thành phần cho từng món trong menu hiện tại
                var dishIds = categories
                    .SelectMany(c => c.Dishes)
                    .Select(d => d.DishID)
                    .Distinct()
                    .ToList();

                // Gửi danh sách thành phần dạng list để dễ serialize sang JSON
                var dishIngredientsList = db.DishIngredients
                    .Where(di => dishIds.Contains(di.DishID))
                    .Select(di => new
                    {
                        dishId = di.DishID,
                        name = di.Ingredients.Name,
                        unit = di.Ingredients.Unit,
                        quantity = di.QuantityPerDish
                    })
                    .ToList();

                ViewBag.DishIngredients = dishIngredientsList;

                // Tính các món bán chạy trong chi nhánh (top 5)
                var topDishIds = db.OrderItems
                    .Include(oi => oi.Orders)
                    .Where(oi => oi.Orders != null
                                 && oi.Orders.DiningTables != null
                                 && oi.Orders.DiningTables.BranchID == branchId)
                    .GroupBy(oi => oi.DishID)
                    .Select(g => new
                    {
                        DishID = g.Key,
                        TotalQuantity = g.Sum(x => (int?)x.Quantity ?? 0)
                    })
                    .OrderByDescending(x => x.TotalQuantity)
                    .Take(5)
                    .ToList()
                    .Select(x => x.DishID)
                    .ToList();

                ViewBag.TopDishIds = topDishIds;

                // Tính display table number (bàn số bắt đầu từ 1)
                var allTablesInBranch = db.DiningTables
                    .Where(t => t.BranchID == branchId && t.IsActive == true)
                    .OrderBy(t => t.TableID)
                    .ToList();

                var displayTableNumber = allTablesInBranch
                    .FindIndex(t => t.TableID == tableId) + 1;

                // ===== LƯU THÔNG TIN BÀN VÀO SESSION =====
                Session["CurrentTableID"] = tableId;
                Session["CurrentBranchID"] = branchId;
                Session["CurrentBranchName"] = table.Branches.Name;
                Session["CurrentTableNumber"] = displayTableNumber;

                // Lấy thông tin khách hàng từ Session (nếu đã đăng nhập)
                var isCustomerLoggedIn = Session["CustomerID"] != null;
                var customerName = isCustomerLoggedIn ? Session["CustomerName"]?.ToString() : "";
                var customerEmail = isCustomerLoggedIn ? Session["CustomerEmail"]?.ToString() : "";
                var customerPhone = isCustomerLoggedIn ? Session["CustomerPhoneNumber"]?.ToString() : "";
                var loyaltyPoints = isCustomerLoggedIn ? (Session["CustomerLoyaltyPoints"] ?? 0) : 0;

                // Tìm đơn hàng hiện tại (nếu đã tồn tại) để khách tiếp tục theo dõi trạng thái
                var activeOrder = db.Orders
                    .Include(o => o.OrderStatus)
                    .FirstOrDefault(o => o.TableID == tableId
                        && o.IsActive == true
                        && (o.OrderStatus.StatusCode == "PENDING"
                            || o.OrderStatus.StatusCode == "CONFIRMED"
                            || o.OrderStatus.StatusCode == "PREPARING"
                            || o.OrderStatus.StatusCode == "READY"
                            || o.OrderStatus.StatusCode == "SERVING"));

                // Truyền dữ liệu vào View
                ViewBag.TableNumber = displayTableNumber;
                ViewBag.TableID = tableId;
                ViewBag.BranchId = branchId;
                ViewBag.BranchName = table.Branches.Name;
                ViewBag.TableSeats = table.NumberOfSeats;
                ViewBag.Categories = categories;

                ViewBag.IsCustomerLoggedIn = isCustomerLoggedIn;
                ViewBag.CustomerName = customerName;
                ViewBag.CustomerEmail = customerEmail;
                ViewBag.CustomerPhone = customerPhone;
                ViewBag.LoyaltyPoints = loyaltyPoints;
                ViewBag.CurrentOrderId = activeOrder != null ? (int?)activeOrder.OrderID : null;

                return View();
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Có lỗi xảy ra: " + ex.Message;
                return RedirectToAction("Index", "Home");
            }
        }

        // ===== API ENDPOINT GỬI ĐƠN CHO BẾP =====
        [HttpPost]
        [ValidateAntiForgeryToken]
        public JsonResult SendOrderToKitchen(int tableId, int branchId, string items)
        {
            // Yêu cầu khách hàng phải đăng nhập
            if (Session["CustomerID"] == null)
            {
                return Json(new
                {
                    success = false,
                    requiresLogin = true,
                    loginUrl = Url.Action("Login", "Customer")
                });
            }

            System.Diagnostics.Debug.WriteLine($"=== SendOrderToKitchen START ===");
            System.Diagnostics.Debug.WriteLine($"TableId: {tableId}, BranchId: {branchId}, Items JSON: {items}");

            try
            {
                // Parse JSON items
                List<OrderItemModel> orderItems = new List<OrderItemModel>();
                if (!string.IsNullOrEmpty(items))
                {
                    try
                    {
                        orderItems = Newtonsoft.Json.JsonConvert.DeserializeObject<List<OrderItemModel>>(items);
                        System.Diagnostics.Debug.WriteLine($"Parsed {orderItems.Count} items");
                    }
                    catch (Exception parseEx)
                    {
                        System.Diagnostics.Debug.WriteLine($"JSON Parse Error: {parseEx.Message}");
                        return Json(new { success = false, message = "Dữ liệu không hợp lệ: " + parseEx.Message });
                    }
                }

                if (orderItems == null || orderItems.Count == 0)
                {
                    System.Diagnostics.Debug.WriteLine("ERROR: No items");
                    return Json(new { success = false, message = "Không có món nào để gửi" });
                }

                // Kiểm tra bàn
                var table = db.DiningTables
                    .Include(t => t.TableStatus)
                    .FirstOrDefault(t => t.TableID == tableId && t.BranchID == branchId && t.IsActive == true);

                if (table == null)
                {
                    System.Diagnostics.Debug.WriteLine($"Table not found: {tableId}");
                    return Json(new { success = false, message = "Bàn không tồn tại" });
                }

                System.Diagnostics.Debug.WriteLine($"Table found: {table.TableID}");

                // LUÔN tạo đơn hàng mới cho mỗi lần gửi bếp
                var pendingStatus = db.OrderStatus.FirstOrDefault(s => s.StatusCode == "PENDING");
                if (pendingStatus == null)
                {
                    System.Diagnostics.Debug.WriteLine("ERROR: PENDING status not found");
                    return Json(new { success = false, message = "Không tìm thấy trạng thái PENDING" });
                }

                var order = new Orders
                {
                    OrderCode = "ORD-" + DateTime.Now.ToString("yyyyMMddHHmmss"),
                    OrderTime = DateTime.Now,
                    TableID = tableId,
                    CustomerID = Session["CustomerID"] != null ? (int?)int.Parse(Session["CustomerID"].ToString()) : null,
                    StatusID = pendingStatus.StatusID,
                    IsActive = true
                };

                db.Orders.Add(order);
                db.SaveChanges();
                System.Diagnostics.Debug.WriteLine($"Created new order: {order.OrderID}");

                // Cập nhật trạng thái bàn và gán CurrentOrderID cho đơn mới nhất
                var occupiedStatusCode = db.TableStatus.FirstOrDefault(s => s.StatusCode == "OCCUPIED");
                if (occupiedStatusCode != null)
                {
                    table.StatusID = occupiedStatusCode.StatusID;
                }
                table.CurrentOrderID = order.OrderID;
                db.SaveChanges();
                System.Diagnostics.Debug.WriteLine("Updated table status/CurrentOrderID for new order.");

                // Thêm các món vào đơn
                decimal totalAmount = 0;
                int successCount = 0;

                foreach (var itemModel in orderItems)
                {
                    var dish = db.Dishes.Find(itemModel.DishID);
                    if (dish == null)
                    {
                        System.Diagnostics.Debug.WriteLine($"Dish not found: {itemModel.DishID}");
                        continue;
                    }

                    // Kiểm tra xem item này đã có trong đơn không
                    var existingItem = db.OrderItems
                        .FirstOrDefault(oi => oi.OrderID == order.OrderID && oi.DishID == itemModel.DishID);

                    if (existingItem != null)
                    {
                        // Cập nhật số lượng
                        existingItem.Quantity += itemModel.Quantity;
                        existingItem.LineTotal = existingItem.UnitPrice * existingItem.Quantity;
                        System.Diagnostics.Debug.WriteLine($"Updated quantity for: {dish.Name}");
                    }
                    else
                    {
                        // Thêm item mới
                        var orderItem = new OrderItems
                        {
                            OrderID = order.OrderID,
                            DishID = itemModel.DishID,
                            Quantity = itemModel.Quantity,
                            UnitPrice = dish.Price,
                            LineTotal = dish.Price * itemModel.Quantity,
                            Note = itemModel.Note
                        };
                        db.OrderItems.Add(orderItem);
                        System.Diagnostics.Debug.WriteLine($"Added new item: {dish.Name} x{itemModel.Quantity}");
                    }

                    totalAmount += (dish.Price * itemModel.Quantity);
                    successCount++;
                }

                db.SaveChanges();
                System.Diagnostics.Debug.WriteLine($"Order saved successfully. Total: {totalAmount}đ");

                return Json(new
                {
                    success = true,
                    message = $"✓ Đã gửi {successCount} món cho bếp",
                    orderID = order.OrderID,
                    orderCode = order.OrderCode,
                    totalAmount = totalAmount
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"ERROR: {ex.Message}");
                System.Diagnostics.Debug.WriteLine($"StackTrace: {ex.StackTrace}");
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // ===== ACTION RESET BÀN =====
        [HttpPost]
        public ActionResult ResetTable(int tableId, int branchId)
        {
            try
            {
                var table = db.DiningTables.Find(tableId);
                if (table == null)
                {
                    TempData["Error"] = "Không tìm thấy bàn";
                    return RedirectToAction("Index", "Home");
                }

                var order = db.Orders
                    .Include(o => o.OrderStatus)
                    .FirstOrDefault(o => o.TableID == tableId && o.IsActive == true);

                if (order != null && order.OrderStatus.StatusCode == "PENDING")
                {
                    var orderItems = db.OrderItems.Where(oi => oi.OrderID == order.OrderID).ToList();
                    foreach (var item in orderItems)
                    {
                        db.OrderItems.Remove(item);
                    }

                    db.Orders.Remove(order);
                    db.SaveChanges();
                }

                var availableStatus = db.TableStatus.FirstOrDefault(s => s.StatusCode == "AVAILABLE");
                if (availableStatus != null)
                {
                    table.StatusID = availableStatus.StatusID;
                    table.CurrentOrderID = null;
                    db.SaveChanges();
                }

                // ===== CLEAR SESSION =====
                Session.Remove("CurrentTableID");
                Session.Remove("CurrentBranchID");
                Session.Remove("CurrentBranchName");
                Session.Remove("CurrentTableNumber");

                TempData["Success"] = "Đã reset bàn. Bạn có thể chọn bàn khác để tiếp tục đặt món.";
                return RedirectToAction("Index", "Home");
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Có lỗi xảy ra: " + ex.Message;
                return RedirectToAction("Index", "Home");
            }
        }

        // Helper method: Tạo menu tự động
        private Menus CreateDailyMenu(int branchId, string branchName, DateTime date)
        {
            try
            {
                var newMenu = new Menus
                {
                    MenuName = $"Menu {branchName} - {date:dd/MM/yyyy}",
                    Date = date,
                    IsActive = true,
                    CreatedAt = DateTime.Now,
                    UpdatedAt = DateTime.Now,
                    BranchID = branchId
                };

                db.Menus.Add(newMenu);
                db.SaveChanges();

                var allCategories = db.Categories.Where(c => c.IsActive == true).ToList();

                foreach (var category in allCategories)
                {
                    var menuCategory = new MenuCategory
                    {
                        MenuID = newMenu.MenuID,
                        CategoryID = category.CategoryID,
                        IsActive = true,
                        CreatedAt = DateTime.Now,
                        UpdatedAt = DateTime.Now
                    };

                    db.MenuCategory.Add(menuCategory);
                    db.SaveChanges();

                    var dishes = db.Dishes
                        .Where(d => d.CategoryID == category.CategoryID && d.IsActive == true && d.Available == true)
                        .OrderBy(d => d.Name)
                        .ToList();

                    int displayOrder = 1;
                    foreach (var dish in dishes)
                    {
                        var categoryDish = new CategoryDish
                        {
                            MenuCategoryID = menuCategory.MenuCategoryID,
                            DishID = dish.DishID,
                            DisplayOrder = displayOrder++,
                            IsAvailable = true,
                            CreatedAt = DateTime.Now,
                            UpdatedAt = DateTime.Now
                        };

                        db.CategoryDish.Add(categoryDish);
                    }

                    db.SaveChanges();
                }

                return newMenu;
            }
            catch (Exception)
            {
                return null;
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
}

// ===== MODEL CLASS =====
public class OrderItemModel
{
    public int DishID { get; set; }
    public int Quantity { get; set; }
    public string Note { get; set; }
}
