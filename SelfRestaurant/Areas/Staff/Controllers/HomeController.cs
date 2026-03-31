using System.Web.Mvc;

namespace SelfRestaurant.Areas.Staff.Controllers
{
    public class HomeController : Controller
    {
        /// <summary>
        /// Khi truy cập /Staff/Home.
        /// - Nếu chưa đăng nhập nhân viên: chuyển sang trang đăng nhập nhân viên.
        /// - Nếu đã đăng nhập: chuyển tới dashboard phù hợp với role.
        /// </summary>
        public ActionResult Index()
        {
            // Chưa đăng nhập nhân viên -> tới trang đăng nhập trong area Staff
            if (!User.Identity.IsAuthenticated)
            {
                return RedirectToAction("LogIn", "Account", new { area = "Staff" });
            }

            // Đã đăng nhập -> điều hướng theo role (copy logic từ AccountController)
            var roleCode = Session["RoleCode"] as string;

            string url;
            switch (roleCode)
            {
                case "ADMIN":
                    url = Url.Action("Index", "Dashboard", new { area = "Admin" });
                    break;
                case "MANAGER":
                    url = Url.Action("Index", "Home", new { area = "" });
                    break;
                case "CASHIER":
                    url = Url.Action("Index", "Cashier", new { area = "Staff" });
                    break;
                case "WAITER":
                    url = Url.Action("Index", "Table", new { area = "Staff" });
                    break;
                case "CHEF":
                case "KITCHEN_STAFF":
                    url = Url.Action("Index", "Chef", new { area = "Staff" });
                    break;
                default:
                    url = Url.Action("Index", "Home", new { area = "" });
                    break;
            }

            return Redirect(url);
        }
    }
}

