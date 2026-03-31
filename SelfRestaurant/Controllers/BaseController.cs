using System.Web.Mvc;
using System.Web.Routing;

namespace SelfRestaurant.Controllers
{
    /// <summary>
    /// Base Controller cho tất cả controllers cần kiểm tra quyền
    /// </summary>
    public class BaseController : Controller
    {
        protected override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            // Kiểm tra xem user đã đăng nhập chưa
            if (!User.Identity.IsAuthenticated)
            {
                filterContext.Result = RedirectToAction("LogIn", "Account");
                return;
            }

            // Kiểm tra Session có tồn tại không
            if (Session["EmployeeID"] == null || Session["RoleCode"] == null)
            {
                // Session hết hạn, yêu cầu đăng nhập lại
                filterContext.Result = RedirectToAction("LogIn", "Account");
                return;
            }

            base.OnActionExecuting(filterContext);
        }

        /// <summary>
        /// Kiểm tra user có role được phép không
        /// </summary>
        protected bool HasRole(params string[] allowedRoles)
        {
            if (Session["RoleCode"] == null) return false;

            string userRole = Session["RoleCode"].ToString();

            foreach (string role in allowedRoles)
            {
                if (userRole == role)
                    return true;
            }

            return false;
        }

        /// <summary>
        /// Redirect đến trang Access Denied
        /// </summary>
        protected ActionResult AccessDenied()
        {
            return View("~/Views/Shared/AccessDenied.cshtml");
        }

        /// <summary>
        /// Lấy thông tin nhân viên hiện tại
        /// </summary>
        protected int? CurrentEmployeeId
        {
            get
            {
                if (Session["EmployeeID"] != null)
                {
                    int id;
                    if (int.TryParse(Session["EmployeeID"].ToString(), out id))
                    {
                        return id;
                    }
                }
                return null;
            }
        }

        protected string CurrentRoleCode
        {
            get
            {
                return Session["RoleCode"]?.ToString();
            }
        }

        protected string CurrentEmployeeName
        {
            get
            {
                return Session["EmployeeName"]?.ToString();
            }
        }

        protected int? CurrentBranchId
        {
            get
            {
                if (Session["BranchID"] != null)
                {
                    int id;
                    if (int.TryParse(Session["BranchID"].ToString(), out id))
                    {
                        return id;
                    }
                }
                return null;
            }
        }
    }
}
