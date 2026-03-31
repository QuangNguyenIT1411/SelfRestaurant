using System;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using System.Web.Security;

namespace SelfRestaurant.Filters
{
    /// <summary>
    /// Custom Authorization Attribute để kiểm tra quyền truy cập theo role
    /// </summary>
    public class CustomAuthorizeAttribute : AuthorizeAttribute
    {
        public string[] AllowedRoles { get; set; }

        protected override bool AuthorizeCore(HttpContextBase httpContext)
        {
            // Kiểm tra user đã đăng nhập chưa
            if (!httpContext.User.Identity.IsAuthenticated)
            {
                return false;
            }

            // Nếu không chỉ định role nào cả, cho phép tất cả user đã đăng nhập
            if (AllowedRoles == null || AllowedRoles.Length == 0)
            {
                return true;
            }

            // Lấy thông tin user từ cookie
            var authCookie = httpContext.Request.Cookies[FormsAuthentication.FormsCookieName];
            if (authCookie == null)
            {
                return false;
            }

            try
            {
                var authTicket = FormsAuthentication.Decrypt(authCookie.Value);
                if (authTicket == null || authTicket.Expired)
                {
                    return false;
                }

                // Parse user data: "EmployeeID|RoleID|BranchID|RoleCode"
                var userData = authTicket.UserData.Split('|');
                if (userData.Length < 4)
                {
                    return false;
                }

                string roleCode = userData[3];

                // Lưu thông tin vào Session để sử dụng ở các nơi khác
                httpContext.Session["EmployeeID"] = userData[0];
                httpContext.Session["RoleID"] = userData[1];
                httpContext.Session["BranchID"] = userData[2];
                httpContext.Session["RoleCode"] = roleCode;
                httpContext.Session["Username"] = authTicket.Name;

                // Kiểm tra role có được phép không
                return AllowedRoles.Contains(roleCode, StringComparer.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        protected override void HandleUnauthorizedRequest(AuthorizationContext filterContext)
        {
            if (!filterContext.HttpContext.User.Identity.IsAuthenticated)
            {
                // Chưa đăng nhập -> chuyển đến trang login
                filterContext.Result = new RedirectToRouteResult(
                    new RouteValueDictionary(new
                    {
                        controller = "Account",
                        action = "LogIn",
                        returnUrl = filterContext.HttpContext.Request.RawUrl
                    })
                );
            }
            else
            {
                // Đã đăng nhập nhưng không có quyền -> hiện trang Access Denied
                filterContext.Result = new ViewResult
                {
                    ViewName = "~/Views/Shared/AccessDenied.cshtml"
                };
            }
        }
    }

    /// <summary>
    /// Attribute đơn giản hơn để chỉ kiểm tra đăng nhập
    /// </summary>
    public class RequireLoginAttribute : CustomAuthorizeAttribute
    {
        public RequireLoginAttribute()
        {
            AllowedRoles = null; // Chấp nhận tất cả các role đã đăng nhập
        }
    }

    /// <summary>
    /// Các attribute cho từng role cụ thể
    /// </summary>
    public class AdminOnlyAttribute : CustomAuthorizeAttribute
    {
        public AdminOnlyAttribute()
        {
            AllowedRoles = new[] { "ADMIN" };
        }
    }

    public class ManagerOnlyAttribute : CustomAuthorizeAttribute
    {
        public ManagerOnlyAttribute()
        {
            AllowedRoles = new[] { "ADMIN", "MANAGER" };
        }
    }

    public class CashierOnlyAttribute : CustomAuthorizeAttribute
    {
        public CashierOnlyAttribute()
        {
            AllowedRoles = new[] { "ADMIN", "MANAGER", "CASHIER" };
        }
    }

    public class KitchenOnlyAttribute : CustomAuthorizeAttribute
    {
        public KitchenOnlyAttribute()
        {
            AllowedRoles = new[] { "ADMIN", "MANAGER", "CHEF", "KITCHEN_STAFF" };
        }
    }

    public class WaiterOnlyAttribute : CustomAuthorizeAttribute
    {
        public WaiterOnlyAttribute()
        {
            AllowedRoles = new[] { "ADMIN", "MANAGER", "WAITER" };
        }
    }
}