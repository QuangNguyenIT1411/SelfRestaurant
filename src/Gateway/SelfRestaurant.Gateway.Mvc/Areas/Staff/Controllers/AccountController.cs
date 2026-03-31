using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Staff.Controllers;

[Area("Staff")]
public sealed class AccountController : Controller
{
    private readonly IdentityClient _identityClient;

    public AccountController(IdentityClient identityClient)
    {
        _identityClient = identityClient;
    }

    [HttpGet]
    public IActionResult Login()
    {
        if (HttpContext.Session.GetInt32(SessionKeys.EmployeeId) is > 0)
        {
            return Redirect(GetRedirectUrlByRole(HttpContext.Session.GetString(SessionKeys.EmployeeRoleCode)));
        }

        return View("Login");
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> Login(
        [FromForm] string username,
        [FromForm] string password,
        [FromForm] bool rememberMe,
        CancellationToken cancellationToken) =>
        HandleLoginAsync(username, password, rememberMe, cancellationToken);

    [HttpGet]
    public IActionResult Logout() => DoLogout();

    [HttpPost]
    [ValidateAntiForgeryToken]
    [ActionName("Logout")]
    public IActionResult LogoutPost() => DoLogout();

    [HttpGet]
    public IActionResult ForgotPassword()
    {
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ForgotPassword([FromForm] string email, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return Json(new { success = false, message = "Vui lòng nhập email." });
        }

        try
        {
            var result = await _identityClient.StaffForgotPasswordAsync(
                new StaffForgotPasswordRequest(email.Trim()),
                cancellationToken);

            var resetUrl = string.IsNullOrWhiteSpace(result?.ResetToken)
                ? null
                : Url.Action(nameof(ResetPassword), "Account", new { area = "Staff", token = result.ResetToken }, Request.Scheme);

            return Json(new
            {
                success = true,
                message = result?.Message ?? "Nếu email tồn tại trong hệ thống, bạn sẽ nhận được link đặt lại mật khẩu.",
                resetUrl
            });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    [HttpGet]
    public IActionResult ResetPassword([FromQuery] string? token)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            TempData["ErrorMessage"] = "Link không hợp lệ.";
            return RedirectToAction(nameof(Login));
        }

        ViewBag.Token = token;
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetPassword(
        [FromForm] string token,
        [FromForm] string newPassword,
        [FromForm] string confirmPassword,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            return Json(new { success = false, message = "Token không hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(newPassword) || string.IsNullOrWhiteSpace(confirmPassword))
        {
            return Json(new { success = false, message = "Vui lòng điền đầy đủ thông tin." });
        }

        if (newPassword.Length < 6)
        {
            return Json(new { success = false, message = "Mật khẩu phải có ít nhất 6 ký tự." });
        }

        if (!string.Equals(newPassword, confirmPassword, StringComparison.Ordinal))
        {
            return Json(new { success = false, message = "Mật khẩu xác nhận không khớp." });
        }

        try
        {
            await _identityClient.StaffResetPasswordAsync(
                new StaffResetPasswordRequest(token.Trim(), newPassword),
                cancellationToken);

            return Json(new
            {
                success = true,
                message = "Đặt lại mật khẩu thành công! Bạn có thể đăng nhập với mật khẩu mới.",
                redirectUrl = Url.Action(nameof(Login), "Account", new { area = "Staff" })
            });
        }
        catch (Exception ex)
        {
            return Json(new { success = false, message = ex.Message });
        }
    }

    private async Task<IActionResult> HandleLoginAsync(
        string username,
        string password,
        bool rememberMe,
        CancellationToken cancellationToken)
    {
        _ = rememberMe; // Keep parity with legacy payload; session auth does not persist cookie here.

        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
        {
            return LoginFailure("Vui lòng nhập đầy đủ thông tin.");
        }

        StaffLoginResponse? profile;
        try
        {
            profile = await _identityClient.StaffLoginAsync(new StaffLoginRequest(username.Trim(), password), cancellationToken);
        }
        catch (Exception ex)
        {
            return LoginFailure(BuildStaffLoginServiceErrorMessage(ex));
        }

        if (profile is null)
        {
            return LoginFailure("Tên đăng nhập hoặc mật khẩu không đúng.");
        }

        HttpContext.Session.SetInt32(SessionKeys.EmployeeId, profile.EmployeeId);
        HttpContext.Session.SetString(SessionKeys.EmployeeUsername, profile.Username);
        HttpContext.Session.SetString(SessionKeys.EmployeeName, profile.Name);
        HttpContext.Session.SetString(SessionKeys.EmployeePhone, profile.Phone ?? "");
        HttpContext.Session.SetString(SessionKeys.EmployeeEmail, profile.Email ?? "");
        HttpContext.Session.SetInt32(SessionKeys.EmployeeRoleId, profile.RoleId);
        HttpContext.Session.SetString(SessionKeys.EmployeeRoleCode, profile.RoleCode);
        HttpContext.Session.SetString(SessionKeys.EmployeeRoleName, profile.RoleName);
        HttpContext.Session.SetInt32(SessionKeys.EmployeeBranchId, profile.BranchId);
        HttpContext.Session.SetString(SessionKeys.EmployeeBranchName, profile.BranchName);

        var redirectUrl = GetRedirectUrlByRole(profile.RoleCode);
        if (IsAjaxRequest())
        {
            return Json(new
            {
                success = true,
                message = "Đăng nhập thành công!",
                redirectUrl,
                role = profile.RoleName,
                name = profile.Name
            });
        }

        return Redirect(redirectUrl);
    }

    private IActionResult LoginFailure(string message)
    {
        if (IsAjaxRequest())
        {
            return Json(new { success = false, message });
        }

        TempData["ErrorMessage"] = message;
        return View("Login");
    }

    private static string BuildStaffLoginServiceErrorMessage(Exception ex)
    {
        var root = ex.GetBaseException();
        var rootMessage = root.Message?.Trim() ?? string.Empty;

        var isConnectivityIssue =
            root is HttpRequestException
            || root is TaskCanceledException
            || rootMessage.Contains("No connection could be made", StringComparison.OrdinalIgnoreCase)
            || rootMessage.Contains("actively refused", StringComparison.OrdinalIgnoreCase)
            || rootMessage.Contains("Connection refused", StringComparison.OrdinalIgnoreCase)
            || rootMessage.Contains("timed out", StringComparison.OrdinalIgnoreCase)
            || rootMessage.Contains("Name or service not known", StringComparison.OrdinalIgnoreCase);

        if (isConnectivityIssue)
        {
            return "Không thể kết nối dịch vụ đăng nhập nhân viên. Vui lòng chạy đủ microservice: Gateway + Customers + Identity.";
        }

        if (string.IsNullOrWhiteSpace(rootMessage))
        {
            return "Không thể kết nối dịch vụ đăng nhập nhân viên.";
        }

        return rootMessage;
    }

    private IActionResult DoLogout()
    {
        var userName = HttpContext.Session.GetString(SessionKeys.EmployeeName) ?? "Người dùng";
        ClearStaffSession();
        TempData["SuccessMessage"] = $"Tạm biệt {userName}! Bạn đã đăng xuất thành công.";
        return RedirectToAction(nameof(Login));
    }

    private void ClearStaffSession()
    {
        HttpContext.Session.Remove(SessionKeys.EmployeeId);
        HttpContext.Session.Remove(SessionKeys.EmployeeUsername);
        HttpContext.Session.Remove(SessionKeys.EmployeeName);
        HttpContext.Session.Remove(SessionKeys.EmployeePhone);
        HttpContext.Session.Remove(SessionKeys.EmployeeEmail);
        HttpContext.Session.Remove(SessionKeys.EmployeeRoleId);
        HttpContext.Session.Remove(SessionKeys.EmployeeRoleCode);
        HttpContext.Session.Remove(SessionKeys.EmployeeRoleName);
        HttpContext.Session.Remove(SessionKeys.EmployeeBranchId);
        HttpContext.Session.Remove(SessionKeys.EmployeeBranchName);
    }

    private bool IsAjaxRequest() =>
        string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);

    private string GetRedirectUrlByRole(string? roleCode)
    {
        var role = (roleCode ?? string.Empty).Trim().ToUpperInvariant();
        return role switch
        {
            "ADMIN" => Url.Action("Index", "Dashboard", new { area = "Admin" }) ?? "/Admin/Dashboard/Index",
            "MANAGER" => Url.Action("Index", "Manager", new { area = "Staff" }) ?? "/Staff/Manager/Index",
            "CASHIER" => Url.Action("Index", "Cashier", new { area = "Staff" }) ?? "/Staff/Cashier/Index",
            "CHEF" or "KITCHEN_STAFF" => Url.Action("Index", "Chef", new { area = "Staff" }) ?? "/Staff/Chef/Index",
            _ => Url.Action("Index", "Home", new { area = "" }) ?? "/"
        };
    }
}
