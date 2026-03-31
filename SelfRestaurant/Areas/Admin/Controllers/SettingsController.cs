using System;
using System.Web.Mvc;
using SelfRestaurant;
using SelfRestaurant.Areas.Admin.Models;
using SelfRestaurant.Controllers;
using SelfRestaurant.Filters;

namespace SelfRestaurant.Areas.Admin.Controllers
{
    [Authorize]
    [AdminOnly]
    public class SettingsController : BaseController
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        // GET: Admin/Settings
        public ActionResult Index()
        {
            ViewBag.ActiveNav = "settings";

            if (!CurrentEmployeeId.HasValue)
            {
                return RedirectToAction("LogIn", "Account", new { area = "Staff" });
            }

            var emp = db.Employees.Find(CurrentEmployeeId.Value);
            if (emp == null)
            {
                return RedirectToAction("LogIn", "Account", new { area = "Staff" });
            }

            var model = new AdminSettingsViewModel
            {
                Name = emp.Name,
                Username = emp.Username,
                Phone = emp.Phone,
                Email = emp.Email
            };

            ViewBag.EmployeeName = emp.Name;
            ViewBag.BranchName = Session["BranchName"];
            ViewBag.RoleName = Session["RoleName"];
            ViewBag.SuccessMessage = TempData["SuccessMessage"];
            ViewBag.ErrorMessage = TempData["ErrorMessage"];

            return View(model);
        }

        // POST: Admin/Settings
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Index(AdminSettingsViewModel model)
        {
            ViewBag.ActiveNav = "settings";

            if (!CurrentEmployeeId.HasValue)
            {
                return RedirectToAction("LogIn", "Account", new { area = "Staff" });
            }

            var emp = db.Employees.Find(CurrentEmployeeId.Value);
            if (emp == null)
            {
                TempData["ErrorMessage"] = "Không tìm thấy tài khoản.";
                return RedirectToAction("Index");
            }

            if (!ModelState.IsValid)
            {
                return View(model);
            }

            // Đổi mật khẩu nếu có nhập
            if (!string.IsNullOrWhiteSpace(model.NewPassword))
            {
                if (string.IsNullOrWhiteSpace(model.CurrentPassword) || emp.Password != model.CurrentPassword)
                {
                    ModelState.AddModelError("CurrentPassword", "Mật khẩu hiện tại không đúng.");
                    return View(model);
                }

                if (model.NewPassword != model.ConfirmPassword)
                {
                    ModelState.AddModelError("ConfirmPassword", "Mật khẩu xác nhận không khớp.");
                    return View(model);
                }

                emp.Password = model.NewPassword;
            }

            emp.Name = model.Name;
            emp.Phone = model.Phone;
            emp.Email = model.Email;
            emp.UpdatedAt = DateTime.Now;

            db.SaveChanges();

            Session["EmployeeName"] = emp.Name;
            TempData["SuccessMessage"] = "Cập nhật thông tin thành công.";

            return RedirectToAction("Index");
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

