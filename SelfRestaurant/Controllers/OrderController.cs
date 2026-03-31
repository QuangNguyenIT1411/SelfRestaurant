using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Web.Mvc;
using SelfRestaurant.Models;

namespace SelfRestaurant.Controllers
{
    public class OrderController : Controller
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        // GET: Order/Index?tableId=12
        public ActionResult Index(int? tableId)
        {
            if (tableId == null)
            {
                return RedirectToAction("Index", "Menu");
            }

            try
            {
                // Lấy thông tin bàn
                var table = db.DiningTables
                    .Include(t => t.Branches)
                    .Include(t => t.TableStatus)
                    .FirstOrDefault(t => t.TableID == tableId);

                if (table == null)
                {
                    TempData["Error"] = "Không tìm thấy bàn";
                    return RedirectToAction("Index", "Menu");
                }

                // FIX: Lấy order đang active của bàn này với AsNoTracking để tránh lỗi
                var currentOrder = db.Orders
                    .AsNoTracking()
                    .Include(o => o.OrderStatus)
                    .Include(o => o.Customers)
                    .Include(o => o.OrderItems.Select(oi => oi.Dishes))
                    .Where(o => o.TableID == tableId && o.IsActive == true)
                    .FirstOrDefault();

                // FIX: Đảm bảo OrderItems không bao giờ null
                if (currentOrder != null && currentOrder.OrderItems == null)
                {
                    currentOrder.OrderItems = new HashSet<OrderItems>();
                }

                ViewBag.TableNumber = tableId;
                ViewBag.TableInfo = table;
                ViewBag.CurrentOrder = currentOrder;
                ViewBag.BranchId = table.BranchID;

                return View();
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Có lỗi xảy ra: " + ex.Message;
                return RedirectToAction("Index", "Menu");
            }
        }

        // GET: Order/GetOrderItems?tableId=12
        [HttpGet]
        public JsonResult GetOrderItems(int tableId)
        {
            try
            {
                var order = db.Orders
                    .Include(o => o.OrderItems.Select(oi => oi.Dishes))
                    .Include(o => o.OrderStatus)
                    .FirstOrDefault(o => o.TableID == tableId && o.IsActive == true);

                if (order == null)
                {
                    return Json(new { success = false, message = "Không có đơn hàng" }, JsonRequestBehavior.AllowGet);
                }

                var items = order.OrderItems.Select(oi => new
                {
                    itemId = oi.ItemID,
                    dishId = oi.DishID,
                    dishName = oi.Dishes.Name,
                    quantity = oi.Quantity,
                    unitPrice = oi.UnitPrice,
                    lineTotal = oi.LineTotal,
                    note = oi.Note,
                    status = GetItemStatus(order.StatusID)
                }).ToList();

                var totalQuantity = order.OrderItems.Sum(oi => oi.Quantity);
                var totalAmount = order.OrderItems.Sum(oi => oi.LineTotal);

                var summary = new
                {
                    totalItems = totalQuantity,
                    subtotal = totalAmount,
                    orderStatus = order.OrderStatus.StatusName,
                    statusCode = order.OrderStatus.StatusCode
                };

                return Json(new
                {
                    success = true,
                    items = items,
                    summary = summary
                }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message }, JsonRequestBehavior.AllowGet);
            }
        }

        // POST: Order/AddItem
        [HttpPost]
        public JsonResult AddItem(int tableId, int dishId, int quantity = 1, string note = "")
        {
            try
            {
                // Lấy thông tin món ăn
                var dish = db.Dishes.Find(dishId);
                if (dish == null || dish.Available != true)
                {
                    return Json(new { success = false, message = "Món ăn không khả dụng" });
                }

                // Kiểm tra hoặc tạo order mới
                var order = db.Orders
                    .Include(o => o.OrderItems) // FIX: Include OrderItems
                    .FirstOrDefault(o => o.TableID == tableId && o.IsActive == true);

                if (order == null)
                {
                    // Tạo order mới với status PENDING
                    var pendingStatus = db.OrderStatus.FirstOrDefault(s => s.StatusCode == "PENDING");

                    order = new Orders
                    {
                        OrderCode = GenerateOrderCode(),
                        OrderTime = DateTime.Now,
                        TableID = tableId,
                        StatusID = pendingStatus.StatusID,
                        IsActive = true
                    };
                    db.Orders.Add(order);
                    db.SaveChanges();

                    // Cập nhật trạng thái bàn
                    var table = db.DiningTables.Find(tableId);
                    if (table != null)
                    {
                        var occupiedStatus = db.TableStatus.FirstOrDefault(s => s.StatusCode == "OCCUPIED");
                        table.StatusID = occupiedStatus.StatusID;
                        table.CurrentOrderID = order.OrderID;
                        db.SaveChanges();
                    }

                    // FIX: Reload order để có OrderItems collection
                    order = db.Orders
                        .Include(o => o.OrderItems)
                        .FirstOrDefault(o => o.OrderID == order.OrderID);
                }

                // Kiểm tra món đã có trong order chưa (chỉ với món chưa note hoặc note giống nhau)
                var existingItem = order.OrderItems
                    .FirstOrDefault(oi => oi.DishID == dishId &&
                                         (string.IsNullOrEmpty(note) || oi.Note == note));

                if (existingItem != null)
                {
                    // Cập nhật số lượng
                    existingItem.Quantity += quantity;
                    existingItem.LineTotal = existingItem.Quantity * existingItem.UnitPrice;
                }
                else
                {
                    // Thêm món mới
                    var newItem = new OrderItems
                    {
                        OrderID = order.OrderID,
                        DishID = dishId,
                        Quantity = quantity,
                        UnitPrice = dish.Price,
                        LineTotal = quantity * dish.Price, // FIX: Tính LineTotal ngay
                        Note = string.IsNullOrEmpty(note) ? null : note
                    };
                    db.OrderItems.Add(newItem);
                }

                db.SaveChanges();

                return Json(new
                {
                    success = true,
                    message = "Đã thêm món vào giỏ hàng",
                    orderId = order.OrderID
                });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // POST: Order/RemoveItem
        [HttpPost]
        public JsonResult RemoveItem(int itemId)
        {
            try
            {
                var item = db.OrderItems.Find(itemId);
                if (item == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy món" });
                }

                var orderId = item.OrderID;
                var order = db.Orders.Find(orderId);

                if (order == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy đơn hàng" });
                }

                // Chỉ cho phép xóa món ở trạng thái PENDING
                var orderStatus = db.OrderStatus.Find(order.StatusID);
                if (orderStatus.StatusCode != "PENDING")
                {
                    return Json(new { success = false, message = "Không thể xóa món đã gửi bếp" });
                }

                db.OrderItems.Remove(item);
                db.SaveChanges();

                // Kiểm tra nếu order không còn món nào thì xóa order và reset bàn
                var remainingItems = db.OrderItems.Count(oi => oi.OrderID == orderId);

                if (remainingItems == 0)
                {
                    var table = db.DiningTables.FirstOrDefault(t => t.TableID == order.TableID);
                    if (table != null)
                    {
                        var availableStatus = db.TableStatus.FirstOrDefault(s => s.StatusCode == "AVAILABLE");
                        table.StatusID = availableStatus.StatusID;
                        table.CurrentOrderID = null;
                    }

                    order.IsActive = false;
                    db.SaveChanges();

                    return Json(new
                    {
                        success = true,
                        message = "Đã xóa món",
                        orderEmpty = true // FIX: Thêm flag để biết order đã rỗng
                    });
                }

                return Json(new
                {
                    success = true,
                    message = "Đã xóa món",
                    orderEmpty = false
                });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // POST: Order/UpdateQuantity
        [HttpPost]
        public JsonResult UpdateQuantity(int itemId, int quantity)
        {
            try
            {
                if (quantity <= 0)
                {
                    return Json(new { success = false, message = "Số lượng phải lớn hơn 0" });
                }

                var item = db.OrderItems.Find(itemId);
                if (item == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy món" });
                }

                var order = db.Orders.Find(item.OrderID);
                if (order == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy đơn hàng" });
                }

                // Chỉ cho phép cập nhật ở trạng thái PENDING
                var orderStatus = db.OrderStatus.Find(order.StatusID);
                if (orderStatus.StatusCode != "PENDING")
                {
                    return Json(new { success = false, message = "Không thể cập nhật món đã gửi bếp" });
                }

                item.Quantity = quantity;
                item.LineTotal = item.Quantity * item.UnitPrice;
                db.SaveChanges();

                return Json(new
                {
                    success = true,
                    message = "Đã cập nhật số lượng",
                    newLineTotal = item.LineTotal
                });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // POST: Order/SendToKitchen
        [HttpPost]
        public JsonResult SendToKitchen(int tableId)
        {
            try
            {
                var order = db.Orders
                    .Include(o => o.OrderItems)
                    .Include(o => o.OrderStatus)
                    .FirstOrDefault(o => o.TableID == tableId && o.IsActive == true);

                if (order == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy đơn hàng" });
                }

                if (order.OrderStatus.StatusCode != "PENDING")
                {
                    return Json(new { success = false, message = "Đơn hàng đã được gửi" });
                }

                var itemCount = order.OrderItems.Count();
                if (itemCount == 0)
                {
                    return Json(new { success = false, message = "Đơn hàng trống" });
                }

                // Cập nhật trạng thái đơn hàng sang CONFIRMED
                var confirmedStatus = db.OrderStatus.FirstOrDefault(s => s.StatusCode == "CONFIRMED");
                if (confirmedStatus == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy trạng thái CONFIRMED" });
                }

                order.StatusID = confirmedStatus.StatusID;
                db.SaveChanges();

                return Json(new { success = true, message = "Đã gửi yêu cầu đến bếp" });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // POST: Order/ScanLoyaltyCard
        [HttpPost]
        public JsonResult ScanLoyaltyCard(int tableId, string phoneNumber)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(phoneNumber))
                {
                    return Json(new { success = false, message = "Vui lòng nhập số điện thoại" });
                }

                var customer = db.Customers
                    .Include(c => c.LoyaltyCards)
                    .FirstOrDefault(c => c.PhoneNumber == phoneNumber.Trim() && c.IsActive == true);

                if (customer == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy khách hàng với số điện thoại này" });
                }

                var order = db.Orders.FirstOrDefault(o => o.TableID == tableId && o.IsActive == true);
                if (order == null)
                {
                    return Json(new { success = false, message = "Không tìm thấy đơn hàng" });
                }

                // Gắn khách hàng vào đơn hàng
                order.CustomerID = customer.CustomerID;
                db.SaveChanges();

                var loyaltyCard = customer.LoyaltyCards
                    .Where(lc => lc.IsActive == true)
                    .OrderByDescending(lc => lc.IssueDate)
                    .FirstOrDefault();

                return Json(new
                {
                    success = true,
                    message = "Đã quét thẻ thành công",
                    customer = new
                    {
                        name = customer.Name,
                        phone = customer.PhoneNumber,
                        currentPoints = customer.LoyaltyPoints ?? 0,
                        cardPoints = loyaltyCard != null ? (loyaltyCard.Points ?? 0) : 0
                    }
                });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Lỗi: " + ex.Message });
            }
        }

        // Helper Methods
        private string GenerateOrderCode()
        {
            var dateCode = DateTime.Now.ToString("yyyyMMdd");
            var random = new Random().Next(1000, 9999);
            var code = $"ORD-{dateCode}-{random}";

            // FIX: Đảm bảo code là unique
            while (db.Orders.Any(o => o.OrderCode == code))
            {
                random = new Random().Next(1000, 9999);
                code = $"ORD-{dateCode}-{random}";
            }

            return code;
        }

        private string GetItemStatus(int orderStatusId)
        {
            var status = db.OrderStatus.Find(orderStatusId);
            if (status == null) return "pending";

            switch (status.StatusCode)
            {
                case "PENDING":
                    return "pending";
                case "CONFIRMED":
                case "PREPARING":
                    return "preparing";
                case "READY":
                case "SERVING":
                case "COMPLETED":
                    return "ready";
                default:
                    return "pending";
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