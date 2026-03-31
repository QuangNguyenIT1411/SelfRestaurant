using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace SelfRestaurant.Gateway.Mvc.Infrastructure;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class StaffAuthorizeAttribute : Attribute, IAuthorizationFilter
{
    public string[] AllowedRoles { get; set; } = Array.Empty<string>();

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var session = context.HttpContext.Session;
        var employeeId = session.GetInt32(SessionKeys.EmployeeId);
        if (employeeId is null)
        {
            context.Result = new RedirectToActionResult("Login", "Account", new { area = "Staff" });
            return;
        }

        if (AllowedRoles.Length == 0)
        {
            return;
        }

        var roleCode = session.GetString(SessionKeys.EmployeeRoleCode);
        if (string.IsNullOrWhiteSpace(roleCode) || !AllowedRoles.Contains(roleCode, StringComparer.OrdinalIgnoreCase))
        {
            context.Result = new RedirectToActionResult("AccessDenied", "Home", new { area = "" });
        }
    }
}
