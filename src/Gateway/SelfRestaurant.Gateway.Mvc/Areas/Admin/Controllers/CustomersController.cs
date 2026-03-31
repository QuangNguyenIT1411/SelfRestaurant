using Microsoft.AspNetCore.Mvc;
using SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;
using SelfRestaurant.Gateway.Mvc.Infrastructure;
using SelfRestaurant.Gateway.Mvc.Models;
using SelfRestaurant.Gateway.Mvc.Services;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Controllers;

[Area("Admin")]
[StaffAuthorize(AllowedRoles = new[] { "ADMIN", "MANAGER" })]
public sealed class CustomersController : Controller
{
    private readonly CustomersClient _customersClient;

    public CustomersController(CustomersClient customersClient)
    {
        _customersClient = customersClient;
    }

    [HttpGet]
    public async Task<IActionResult> Index([FromQuery] string? search, [FromQuery] int page = 1, CancellationToken cancellationToken = default)
    {
        FillCommonViewData("customers");
        page = Math.Max(1, page);
        var data = await _customersClient.GetAdminCustomersAsync(search, page, 10, cancellationToken);
        ViewBag.SearchTerm = search;
        ViewBag.Page = data?.Page ?? page;
        ViewBag.TotalPages = data?.TotalPages ?? 0;

        return View(new AdminCustomersIndexViewModel
        {
            Items = data?.Items ?? Array.Empty<AdminCustomerDto>(),
            Search = search,
            Page = data?.Page ?? page,
            TotalPages = data?.TotalPages ?? 0,
            TotalItems = data?.TotalItems ?? 0,
        });
    }

    [HttpGet]
    public IActionResult Create()
    {
        FillCommonViewData("customers");
        return View(new AdminCustomerFormViewModel { IsActive = true });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AdminCustomerFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _customersClient.CreateAdminCustomerAsync(
                new AdminUpsertCustomerRequest(
                    model.Name,
                    model.Username,
                    model.Password,
                    model.PhoneNumber,
                    model.Email,
                    model.Gender,
                    model.DateOfBirth,
                    model.Address,
                    model.LoyaltyPoints,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã thêm khách hàng.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("customers");
            return View(model);
        }
    }

    [HttpGet]
    public async Task<IActionResult> Edit(int id, CancellationToken cancellationToken)
    {
        FillCommonViewData("customers");
        var customer = await _customersClient.GetAdminCustomerByIdAsync(id, cancellationToken);
        if (customer is null)
        {
            TempData["Error"] = "Không tìm thấy khách hàng.";
            TempData["ErrorMessage"] = TempData["Error"];
            return RedirectToAction(nameof(Index));
        }

        return View(new AdminCustomerFormViewModel
        {
            CustomerId = customer.CustomerId,
            Name = customer.Name,
            Username = customer.Username,
            PhoneNumber = customer.PhoneNumber,
            Email = customer.Email,
            Gender = customer.Gender,
            DateOfBirth = customer.DateOfBirth,
            Address = customer.Address,
            LoyaltyPoints = customer.LoyaltyPoints,
            IsActive = customer.IsActive,
        });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, AdminCustomerFormViewModel model, CancellationToken cancellationToken)
    {
        try
        {
            await _customersClient.UpdateAdminCustomerAsync(
                id,
                new AdminUpsertCustomerRequest(
                    model.Name,
                    model.Username,
                    model.Password,
                    model.PhoneNumber,
                    model.Email,
                    model.Gender,
                    model.DateOfBirth,
                    model.Address,
                    model.LoyaltyPoints,
                    model.IsActive),
                cancellationToken);

            TempData["Success"] = "Đã cập nhật khách hàng.";
            TempData["SuccessMessage"] = TempData["Success"];
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
            FillCommonViewData("customers");
            return View(model);
        }
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Deactivate(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _customersClient.DeactivateAdminCustomerAsync(id, cancellationToken);
            TempData["Success"] = "Đã vô hiệu hóa khách hàng.";
            TempData["SuccessMessage"] = TempData["Success"];
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            TempData["ErrorMessage"] = TempData["Error"];
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> Delete(int id, CancellationToken cancellationToken) =>
        Deactivate(id, cancellationToken);

    private void FillCommonViewData(string activeNav)
    {
        ViewBag.ActiveNav = activeNav;
        ViewBag.EmployeeName = HttpContext.Session.GetString(SessionKeys.EmployeeName);
        ViewBag.RoleName = HttpContext.Session.GetString(SessionKeys.EmployeeRoleName);
        ViewBag.BranchName = HttpContext.Session.GetString(SessionKeys.EmployeeBranchName);
        ViewBag.SuccessMessage = TempData["Success"] ?? TempData["SuccessMessage"];
        ViewBag.ErrorMessage = TempData["Error"] ?? TempData["ErrorMessage"];
    }
}
