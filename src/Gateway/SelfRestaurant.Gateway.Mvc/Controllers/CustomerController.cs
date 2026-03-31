using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Controllers;

public sealed class CustomerController : Controller
{
    private readonly IdentityClient _identityClient;
    private readonly CustomersClient _customersClient;

    public CustomerController(IdentityClient identityClient, CustomersClient customersClient)
    {
        _identityClient = identityClient;
        _customersClient = customersClient;
    }

    private bool IsAjaxRequest()
    {
        if (string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var accept = Request.Headers.Accept.ToString();
        return accept.Contains("application/json", StringComparison.OrdinalIgnoreCase);
    }

    [HttpGet]
    public IActionResult Login(string? returnUrl = null, bool force = false, string mode = "login")
    {
        if (!force && HttpContext.Session.GetInt32(SessionKeys.CustomerId) is not null)
        {
            return RedirectToLocal(returnUrl) ?? RedirectToAction("Index", "Home")!;
        }

        ViewBag.ReturnUrl = returnUrl;
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(
        CustomerLoginViewModel model,
        [FromForm] string? mode,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(model.Username))
        {
            model.Username = Request.Form["Login.Username"].ToString();
        }

        if (string.IsNullOrWhiteSpace(model.Password))
        {
            model.Password = Request.Form["Login.Password"].ToString();
        }

        if (string.IsNullOrWhiteSpace(model.ReturnUrl))
        {
            model.ReturnUrl = Request.Form["Login.ReturnUrl"].ToString();
        }

        if (!model.RememberMe && bool.TryParse(Request.Form["Login.RememberMe"], out var rememberMe))
        {
            model.RememberMe = rememberMe;
        }

        ModelState.Clear();
        TryValidateModel(model);

        var isAjax = IsAjaxRequest();

        if (!ModelState.IsValid)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = "Vui lòng nhập đầy đủ thông tin." });
            }

            ViewBag.ReturnUrl = model.ReturnUrl;
            ViewBag.RememberMe = model.RememberMe;
            return View("Login", model);
        }

        LoginResponse? login;
        try
        {
            login = await _identityClient.LoginAsync(new LoginRequest(model.Username, model.Password), cancellationToken);
        }
        catch (Exception ex)
        {
            var loginErrorMessage = BuildLoginServiceErrorMessage(ex);
            if (isAjax)
            {
                return Json(new { success = false, message = loginErrorMessage });
            }

            ModelState.AddModelError(string.Empty, loginErrorMessage);
            ViewBag.ReturnUrl = model.ReturnUrl;
            ViewBag.RememberMe = model.RememberMe;
            return View("Login", model);
        }

        if (login is null)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = "Sai tài khoản hoặc mật khẩu." });
            }

            ModelState.AddModelError(string.Empty, "Sai tài khoản hoặc mật khẩu.");
            ViewBag.ReturnUrl = model.ReturnUrl;
            ViewBag.RememberMe = model.RememberMe;
            return View("Login", model);
        }

        HttpContext.Session.SetInt32(SessionKeys.CustomerId, login.CustomerId);
        HttpContext.Session.SetString(SessionKeys.CustomerUsername, login.Username);
        HttpContext.Session.SetString(SessionKeys.CustomerName, login.Name);
        HttpContext.Session.SetString(SessionKeys.CustomerPhoneNumber, login.PhoneNumber);
        if (!string.IsNullOrWhiteSpace(login.Email))
        {
            HttpContext.Session.SetString(SessionKeys.CustomerEmail, login.Email);
        }

        HttpContext.Session.SetInt32(SessionKeys.CustomerLoyaltyPoints, login.LoyaltyPoints);

        var redirectUrl = (RedirectToLocal(model.ReturnUrl) as RedirectResult)?.Url;
        if (string.IsNullOrWhiteSpace(redirectUrl))
        {
            var currentTableId = HttpContext.Session.GetInt32(SessionKeys.CurrentTableId);
            var currentBranchId = HttpContext.Session.GetInt32(SessionKeys.CurrentBranchId);
            var currentTableNumber = HttpContext.Session.GetInt32(SessionKeys.CurrentTableNumber);
            if (currentTableId is not null && currentBranchId is not null)
            {
                redirectUrl = Url.Action(
                    "Index",
                    "Menu",
                    new
                    {
                        tableId = currentTableId.Value,
                        branchId = currentBranchId.Value,
                        tableNumber = currentTableNumber
                    });
            }
        }

        redirectUrl ??= Url.Action("Index", "Home") ?? "/";

        if (isAjax)
        {
            return Json(new { success = true, message = "Đăng nhập thành công!", redirectUrl });
        }

        return Redirect(redirectUrl);
    }

    [HttpGet]
    public IActionResult Register()
    {
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(
        CustomerRegisterViewModel model,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(model.Name))
        {
            model.Name = Request.Form["Register.Name"].ToString();
        }

        if (string.IsNullOrWhiteSpace(model.PhoneNumber))
        {
            model.PhoneNumber = Request.Form["Register.PhoneNumber"].ToString();
        }

        if (string.IsNullOrWhiteSpace(model.Email))
        {
            model.Email = Request.Form["Register.Email"].ToString();
        }

        if (string.IsNullOrWhiteSpace(model.Username))
        {
            model.Username = Request.Form["Register.Username"].ToString();
        }

        if (string.IsNullOrWhiteSpace(model.Password))
        {
            model.Password = Request.Form["Register.Password"].ToString();
        }

        if (string.IsNullOrWhiteSpace(model.ConfirmPassword))
        {
            model.ConfirmPassword = Request.Form["Register.ConfirmPassword"].ToString();
        }

        var isAjax = IsAjaxRequest();

        ModelState.Clear();
        TryValidateModel(model);

        if (!ModelState.IsValid)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = "Vui lòng kiểm tra lại thông tin." });
            }

            ViewBag.Form = model;
            return View(model);
        }

        try
        {
            await _identityClient.RegisterAsync(
                new RegisterRequest(
                    Name: model.Name,
                    Username: model.Username,
                    Password: model.Password,
                    PhoneNumber: model.PhoneNumber,
                    Email: model.Email,
                    Gender: model.Gender,
                    DateOfBirth: model.DateOfBirth,
                    Address: model.Address),
                cancellationToken);
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            ModelState.AddModelError(string.Empty, ex.Message);
            ViewBag.Form = model;
            return View(model);
        }

        if (isAjax)
        {
            return Json(new
            {
                success = true,
                message = "Đăng ký thành công! Vui lòng đăng nhập.",
                redirectUrl = Url.Action(nameof(Login), new { mode = "login" })
            });
        }

        TempData["Success"] = "Đăng ký thành công! Vui lòng đăng nhập.";
        return RedirectToAction(nameof(Login))!;
    }

    [HttpGet]
    public async Task<IActionResult> Dashboard(CancellationToken cancellationToken)
    {
        var customerId = HttpContext.Session.GetInt32(SessionKeys.CustomerId);
        if (customerId is null)
        {
            return RedirectToAction(nameof(Login))!;
        }

        var profile = await _customersClient.GetCustomerAsync(customerId.Value, cancellationToken);
        if (profile is null)
        {
            ClearCustomerSession(preserveTableContext: false);
            return RedirectToAction(nameof(Login))!;
        }

        var orders = await _customersClient.GetOrdersAsync(customerId.Value, take: 10, cancellationToken);
        var dashboardModel = new CustomerDashboardViewModel
        {
            CustomerID = profile.CustomerId,
            Username = profile.Username,
            CustomerName = profile.Name,
            CustomerPhone = profile.PhoneNumber,
            CustomerEmail = profile.Email,
            CustomerAddress = profile.Address,
            Gender = profile.Gender,
            DateOfBirth = profile.DateOfBirth,
            LoyaltyPoints = profile.LoyaltyPoints,
            Orders = orders.Select(order => new CustomerDashboardOrderSummaryViewModel
            {
                OrderID = order.OrderId,
                OrderCode = order.OrderCode,
                OrderTime = order.OrderTime,
                StatusCode = order.StatusCode,
                StatusName = order.OrderStatus,
                TotalAmount = order.TotalAmount,
                ItemCount = order.ItemCount,
            }).ToList()
        };

        dashboardModel.TotalOrders = dashboardModel.Orders.Count;
        dashboardModel.TotalSpent = dashboardModel.Orders.Sum(x => x.TotalAmount);
        dashboardModel.PendingOrders = dashboardModel.Orders.Count(x =>
            string.Equals(x.StatusCode, "PENDING", StringComparison.OrdinalIgnoreCase)
            || string.Equals(x.StatusCode, "CONFIRMED", StringComparison.OrdinalIgnoreCase));
        dashboardModel.CompletedOrders = dashboardModel.Orders.Count(x =>
            string.Equals(x.StatusCode, "COMPLETED", StringComparison.OrdinalIgnoreCase));

        return View(dashboardModel);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateProfile(
        [FromForm] string username,
        [FromForm] string name,
        [FromForm] string email,
        [FromForm] string phoneNumber,
        [FromForm] string? gender,
        [FromForm] string? address,
        [FromForm] DateOnly? dateOfBirth,
        CancellationToken cancellationToken)
    {
        var customerId = HttpContext.Session.GetInt32(SessionKeys.CustomerId);
        if (customerId is null)
        {
            return RedirectToAction(nameof(Login))!;
        }

        try
        {
            await _customersClient.UpdateProfileAsync(
                customerId.Value,
                new UpdateCustomerProfileRequest(
                    Username: username,
                    Name: name,
                    PhoneNumber: phoneNumber,
                    Email: email,
                    Gender: gender,
                    DateOfBirth: dateOfBirth,
                    Address: address),
                cancellationToken);

            HttpContext.Session.SetString(SessionKeys.CustomerUsername, username);
            HttpContext.Session.SetString(SessionKeys.CustomerName, name);
            HttpContext.Session.SetString(SessionKeys.CustomerPhoneNumber, phoneNumber);
            if (!string.IsNullOrWhiteSpace(email))
            {
                HttpContext.Session.SetString(SessionKeys.CustomerEmail, email);
            }

            TempData["Success"] = "Cập nhật thông tin thành công!";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Dashboard))!;
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangePassword(
        [FromForm] string currentPassword,
        [FromForm] string newPassword,
        [FromForm] string confirmPassword,
        CancellationToken cancellationToken)
    {
        var customerId = HttpContext.Session.GetInt32(SessionKeys.CustomerId);
        if (customerId is null)
        {
            return RedirectToAction(nameof(Login))!;
        }

        if (!string.Equals(newPassword, confirmPassword, StringComparison.Ordinal))
        {
            TempData["Error"] = "Mật khẩu xác nhận không khớp.";
            return RedirectToAction(nameof(Dashboard))!;
        }

        try
        {
            await _identityClient.ChangePasswordAsync(
                new ChangePasswordRequest(customerId.Value, currentPassword, newPassword),
                cancellationToken);
            TempData["Success"] = "Đổi mật khẩu thành công!";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Dashboard))!;
    }

    [HttpGet]
    public IActionResult ForgotPassword()
    {
        ViewBag.Title = "Quên mật khẩu";
        return View(new CustomerForgotPasswordViewModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ForgotPassword(CustomerForgotPasswordViewModel model, CancellationToken cancellationToken)
    {
        var isAjax = IsAjaxRequest();

        if (!ModelState.IsValid)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = "Vui lòng nhập Username/Email/SĐT." });
            }

            return View(model);
        }

        try
        {
            var result = await _identityClient.ForgotPasswordAsync(
                new ForgotPasswordRequest(model.UsernameOrEmailOrPhone),
                cancellationToken);

            if (result is null)
            {
                throw new Exception("Không nhận được phản hồi từ dịch vụ xác thực.");
            }

            var resetUrl = string.IsNullOrWhiteSpace(result.ResetToken)
                ? null
                : Url.Action(nameof(ResetPassword), "Customer", new { token = result.ResetToken }, Request.Scheme);

            if (isAjax)
            {
                return Json(new
                {
                    success = true,
                    message = result.Message,
                    resetUrl,
                });
            }

            TempData["Success"] = result.Message;
            if (resetUrl is not null)
            {
                TempData["ResetUrl"] = resetUrl;
            }

            return RedirectToAction(nameof(ForgotPassword))!;
        }
        catch (Exception ex)
        {
            var message = "Không thể gửi yêu cầu quên mật khẩu lúc này. Vui lòng thử lại sau ít phút.";
            if (ex.Message.Contains("actively refused", StringComparison.OrdinalIgnoreCase)
                || ex.Message.Contains("No connection could be made", StringComparison.OrdinalIgnoreCase))
            {
                message = "Dịch vụ xác thực đang tạm thời gián đoạn. Vui lòng thử lại sau ít phút.";
            }

            if (isAjax)
            {
                return Json(new { success = false, message });
            }

            TempData["Error"] = message;
            return View(model);
        }
    }

    [HttpGet]
    public IActionResult ResetPassword([FromQuery] string? token)
    {
        ViewBag.Title = "Đặt lại mật khẩu";
        ViewBag.Token = token ?? "";
        return View(new CustomerResetPasswordViewModel { Token = token ?? "" });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetPassword(CustomerResetPasswordViewModel model, CancellationToken cancellationToken)
    {
        var isAjax = IsAjaxRequest();

        if (!ModelState.IsValid)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = "Vui lòng kiểm tra lại thông tin." });
            }

            ViewBag.Token = model.Token;
            return View(model);
        }

        try
        {
            await _identityClient.ResetPasswordAsync(
                new ResetPasswordRequest(model.Token, model.NewPassword),
                cancellationToken);

            var redirectUrl = Url.Action(nameof(Login), "Customer") ?? "/";
            if (isAjax)
            {
                return Json(new { success = true, message = "Đặt lại mật khẩu thành công. Vui lòng đăng nhập.", redirectUrl });
            }

            TempData["Success"] = "Đặt lại mật khẩu thành công. Vui lòng đăng nhập.";
            return RedirectToAction(nameof(Login))!;
        }
        catch (Exception ex)
        {
            if (isAjax)
            {
                return Json(new { success = false, message = ex.Message });
            }

            TempData["Error"] = ex.Message;
            ViewBag.Token = model.Token;
            return View(model);
        }
    }

    public IActionResult Logout()
    {
        ClearCustomerSession(preserveTableContext: true);
        return RedirectToAction("Index", "Home")!;
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult LogoutPost()
    {
        ClearCustomerSession(preserveTableContext: true);
        return RedirectToAction("Index", "Home")!;
    }

    private void ClearCustomerSession(bool preserveTableContext)
    {
        HttpContext.Session.Remove(SessionKeys.CustomerId);
        HttpContext.Session.Remove(SessionKeys.CustomerUsername);
        HttpContext.Session.Remove(SessionKeys.CustomerName);
        HttpContext.Session.Remove(SessionKeys.CustomerPhoneNumber);
        HttpContext.Session.Remove(SessionKeys.CustomerEmail);
        HttpContext.Session.Remove(SessionKeys.CustomerLoyaltyPoints);

        if (!preserveTableContext)
        {
            HttpContext.Session.Remove(SessionKeys.CurrentTableId);
            HttpContext.Session.Remove(SessionKeys.CurrentBranchId);
            HttpContext.Session.Remove(SessionKeys.CurrentBranchName);
            HttpContext.Session.Remove(SessionKeys.CurrentTableNumber);
        }
    }

    private IActionResult? RedirectToLocal(string? returnUrl)
    {
        if (!string.IsNullOrWhiteSpace(returnUrl) && Url.IsLocalUrl(returnUrl))
        {
            return Redirect(returnUrl);
        }

        return null;
    }

    private static string BuildLoginServiceErrorMessage(Exception ex)
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
            return "Không thể kết nối dịch vụ đăng nhập. Vui lòng chạy đủ microservice: Gateway + Customers + Identity.";
        }

        if (string.IsNullOrWhiteSpace(rootMessage))
        {
            return "Không thể kết nối dịch vụ đăng nhập.";
        }

        return $"Không thể kết nối dịch vụ đăng nhập. {rootMessage}";
    }

}
