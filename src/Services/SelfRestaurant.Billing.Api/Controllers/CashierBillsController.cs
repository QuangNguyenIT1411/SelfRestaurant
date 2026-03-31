using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Billing.Api.Persistence;

namespace SelfRestaurant.Billing.Api.Controllers;

[ApiController]
public sealed class CashierBillsController : ControllerBase
{
    private readonly BillingDbContext _db;

    public CashierBillsController(BillingDbContext db)
    {
        _db = db;
    }

    [HttpGet("api/employees/{employeeId:int}/cashier/bills")]
    public async Task<ActionResult<IReadOnlyList<BillSummaryResponse>>> GetBills(
        int employeeId,
        [FromQuery] int branchId,
        [FromQuery] DateOnly? date,
        [FromQuery] int take = 50,
        CancellationToken cancellationToken = default)
    {
        if (employeeId <= 0)
        {
            return BadRequest(new { message = "EmployeeId is required." });
        }

        if (branchId <= 0)
        {
            return BadRequest(new { message = "BranchId is required." });
        }

        take = Math.Clamp(take, 1, 200);

        DateTime? start = null;
        DateTime? end = null;
        if (date is not null)
        {
            start = date.Value.ToDateTime(TimeOnly.MinValue);
            end = start.Value.AddDays(1);
        }

        var bills = await _db.Bills
            .AsNoTracking()
            .Include(b => b.Order)
            .ThenInclude(o => o.Table)
            .Include(b => b.Customer)
            .Where(b =>
                b.IsActive
                && b.EmployeeID == employeeId
                && b.Order != null
                && b.Order.Table != null
                && b.Order.Table.BranchID == branchId
                && (start == null || (b.BillTime >= start && b.BillTime < end)))
            .OrderByDescending(b => b.BillTime)
            .Take(take)
            .Select(b => new BillSummaryResponse(
                b.BillID,
                b.BillCode,
                b.BillTime,
                b.OrderID,
                b.Order!.OrderCode,
                b.Order.Table!.QRCode ?? ("Bàn " + b.Order.TableID),
                b.Customer != null ? b.Customer.Name : null,
                b.Subtotal,
                b.Discount,
                b.PointsDiscount,
                b.PointsUsed,
                b.TotalAmount,
                b.PaymentMethod,
                b.PaymentAmount,
                b.ChangeAmount))
            .ToListAsync(cancellationToken);

        return Ok(bills);
    }

    [HttpGet("api/employees/{employeeId:int}/cashier/report")]
    public async Task<ActionResult<CashierReportResponse>> GetReport(
        int employeeId,
        [FromQuery] int branchId,
        [FromQuery] DateOnly? date,
        CancellationToken cancellationToken = default)
    {
        var target = date ?? DateOnly.FromDateTime(DateTime.Today);

        var bills = await GetBills(employeeId, branchId, target, take: 200, cancellationToken);
        if (bills.Result is ObjectResult { StatusCode: >= 400 } bad)
        {
            return bad;
        }

        var list = bills.Value ?? Array.Empty<BillSummaryResponse>();
        var revenue = list.Sum(b => b.TotalAmount);

        return Ok(new CashierReportResponse(
            Date: target,
            EmployeeId: employeeId,
            BranchId: branchId,
            BillCount: list.Count,
            TotalRevenue: revenue,
            Bills: list));
    }

    [HttpGet("api/branches/{branchId:int}/cashier/report")]
    public async Task<ActionResult<BranchCashierReportResponse>> GetBranchReport(
        int branchId,
        [FromQuery] DateOnly? date,
        CancellationToken cancellationToken = default)
    {
        if (branchId <= 0)
        {
            return BadRequest(new { message = "BranchId is required." });
        }

        var target = date ?? DateOnly.FromDateTime(DateTime.Today);
        var start = target.ToDateTime(TimeOnly.MinValue);
        var end = start.AddDays(1);

        var bills = await _db.Bills
            .AsNoTracking()
            .Include(b => b.Order)
            .ThenInclude(o => o.Table)
            .Where(b =>
                b.IsActive
                && b.Order != null
                && b.Order.Table != null
                && b.Order.Table.BranchID == branchId
                && b.BillTime >= start
                && b.BillTime < end)
            .Select(b => b.TotalAmount)
            .ToListAsync(cancellationToken);

        return Ok(new BranchCashierReportResponse(
            Date: target,
            BranchId: branchId,
            BillCount: bills.Count,
            TotalRevenue: bills.Sum()));
    }

    public sealed record BillSummaryResponse(
        int BillId,
        string BillCode,
        DateTime BillTime,
        int OrderId,
        string? OrderCode,
        string TableName,
        string? CustomerName,
        decimal Subtotal,
        decimal Discount,
        decimal PointsDiscount,
        int? PointsUsed,
        decimal TotalAmount,
        string PaymentMethod,
        decimal? PaymentAmount,
        decimal? ChangeAmount);

    public sealed record CashierReportResponse(
        DateOnly Date,
        int EmployeeId,
        int BranchId,
        int BillCount,
        decimal TotalRevenue,
        IReadOnlyList<BillSummaryResponse> Bills);

    public sealed record BranchCashierReportResponse(
        DateOnly Date,
        int BranchId,
        int BillCount,
        decimal TotalRevenue);
}



