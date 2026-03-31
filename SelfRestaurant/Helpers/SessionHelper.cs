using System;
using System.Web;

namespace SelfRestaurant.Helpers
{
    /// <summary>
    /// Helper class để làm việc với Session và thông tin user hiện tại
    /// </summary>
    public static class SessionHelper
    {
        // Keys cho session
        private const string EMPLOYEE_ID_KEY = "EmployeeID";
        private const string ROLE_ID_KEY = "RoleID";
        private const string BRANCH_ID_KEY = "BranchID";
        private const string ROLE_CODE_KEY = "RoleCode";
        private const string USERNAME_KEY = "Username";

        /// <summary>
        /// Lấy Employee ID của user hiện tại
        /// </summary>
        public static int? GetEmployeeID()
        {
            var value = HttpContext.Current.Session[EMPLOYEE_ID_KEY];
            if (value != null && int.TryParse(value.ToString(), out int result))
            {
                return result;
            }
            return null;
        }

        /// <summary>
        /// Lấy Role ID của user hiện tại
        /// </summary>
        public static int? GetRoleID()
        {
            var value = HttpContext.Current.Session[ROLE_ID_KEY];
            if (value != null && int.TryParse(value.ToString(), out int result))
            {
                return result;
            }
            return null;
        }

        /// <summary>
        /// Lấy Branch ID của user hiện tại
        /// </summary>
        public static int? GetBranchID()
        {
            var value = HttpContext.Current.Session[BRANCH_ID_KEY];
            if (value != null && int.TryParse(value.ToString(), out int result))
            {
                return result;
            }
            return null;
        }

        /// <summary>
        /// Lấy Role Code của user hiện tại
        /// </summary>
        public static string GetRoleCode()
        {
            return HttpContext.Current.Session[ROLE_CODE_KEY]?.ToString();
        }

        /// <summary>
        /// Lấy Username của user hiện tại
        /// </summary>
        public static string GetUsername()
        {
            return HttpContext.Current.Session[USERNAME_KEY]?.ToString();
        }

        /// <summary>
        /// Kiểm tra user có role cụ thể không
        /// </summary>
        public static bool HasRole(string roleCode)
        {
            var currentRole = GetRoleCode();
            return !string.IsNullOrEmpty(currentRole) &&
                   currentRole.Equals(roleCode, StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Kiểm tra user có một trong các role được chỉ định không
        /// </summary>
        public static bool HasAnyRole(params string[] roleCodes)
        {
            var currentRole = GetRoleCode();
            if (string.IsNullOrEmpty(currentRole))
                return false;

            foreach (var role in roleCodes)
            {
                if (currentRole.Equals(role, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        /// <summary>
        /// Kiểm tra user có phải là Admin không
        /// </summary>
        public static bool IsAdmin()
        {
            return HasRole("ADMIN");
        }

        /// <summary>
        /// Kiểm tra user có phải là Manager hoặc Admin không
        /// </summary>
        public static bool IsManagerOrAdmin()
        {
            return HasAnyRole("ADMIN", "MANAGER");
        }

        /// <summary>
        /// Set thông tin employee vào session
        /// </summary>
        public static void SetEmployeeInfo(int employeeId, int roleId, int branchId, string roleCode, string username)
        {
            HttpContext.Current.Session[EMPLOYEE_ID_KEY] = employeeId.ToString();
            HttpContext.Current.Session[ROLE_ID_KEY] = roleId.ToString();
            HttpContext.Current.Session[BRANCH_ID_KEY] = branchId.ToString();
            HttpContext.Current.Session[ROLE_CODE_KEY] = roleCode;
            HttpContext.Current.Session[USERNAME_KEY] = username;
        }

        /// <summary>
        /// Xóa tất cả thông tin session
        /// </summary>
        public static void ClearSession()
        {
            HttpContext.Current.Session.Clear();
            HttpContext.Current.Session.Abandon();
        }
    }

    /// <summary>
    /// Constants cho các role codes
    /// </summary>
    public static class RoleCodes
    {
        public const string ADMIN = "ADMIN";
        public const string MANAGER = "MANAGER";
        public const string CASHIER = "CASHIER";
        public const string WAITER = "WAITER";
        public const string CHEF = "CHEF";
        public const string KITCHEN_STAFF = "KITCHEN_STAFF";
    }
}