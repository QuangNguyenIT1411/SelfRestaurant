using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Customers.Api.Persistence;
using SelfRestaurant.Customers.Api.Persistence.Entities;
using SelfRestaurant.Customers.Api.Infrastructure;
using SelfRestaurant.Customers.Api.Security;
using CustomerEntity = SelfRestaurant.Customers.Api.Persistence.Entities.Customers;

namespace SelfRestaurant.Customers.Api.Controllers;

[ApiController]
public sealed class CustomersController : ControllerBase
{
    private readonly CustomersDbContext _db;
    private readonly ILogger<CustomersController> _logger;
    private readonly PasswordResetEmailSender _passwordResetEmailSender;
    private readonly IConfiguration _configuration;
    private readonly IHostEnvironment _environment;

    public CustomersController(
        CustomersDbContext db,
        ILogger<CustomersController> logger,
        PasswordResetEmailSender passwordResetEmailSender,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        _db = db;
        _logger = logger;
        _passwordResetEmailSender = passwordResetEmailSender;
        _configuration = configuration;
        _environment = environment;
    }

    [HttpGet("api/customers/{customerId:int}")]
    public async Task<ActionResult<object>> GetCustomer(int customerId, CancellationToken cancellationToken)
    {
        var customer = await _db.Customers
            .AsNoTracking()
            .Where(x => x.CustomerID == customerId && (x.IsActive ?? true))
            .Select(x => new
            {
                customerId = x.CustomerID,
                username = x.Username,
                name = x.Name,
                phoneNumber = x.PhoneNumber,
                email = x.Email,
                gender = x.Gender,
                dateOfBirth = x.DateOfBirth,
                address = x.Address,
                loyaltyPoints = x.LoyaltyPoints ?? 0,
            })
            .FirstOrDefaultAsync(cancellationToken);

        return customer is null ? NotFound() : Ok(customer);
    }

    [HttpPost("api/customers/{customerId:int}/loyalty/settle")]
    public async Task<ActionResult<object>> SettleLoyalty(
        int customerId,
        [FromBody] LoyaltySettlementRequest request,
        CancellationToken cancellationToken)
    {
        var customer = await _db.Customers
            .FirstOrDefaultAsync(x => x.CustomerID == customerId && (x.IsActive ?? true), cancellationToken);
        if (customer is null)
        {
            return NotFound(new { message = "Customer not found." });
        }

        var pointsBefore = customer.LoyaltyPoints ?? 0;
        var pointsUsed = request.PointsUsed < 0 ? 0 : request.PointsUsed;
        pointsUsed = Math.Min(pointsUsed, pointsBefore);
        pointsUsed = (pointsUsed / 1000) * 1000;

        var updatedPoints = pointsBefore - pointsUsed;
        if (updatedPoints < 0)
        {
            updatedPoints = 0;
        }

        var amountPaid = request.AmountPaid < 0 ? 0 : request.AmountPaid;
        var pointsEarned = amountPaid > 0 ? (int)Math.Floor(amountPaid * 0.01m) : 0;

        customer.LoyaltyPoints = updatedPoints + pointsEarned;
        customer.UpdatedAt = DateTime.Now;

        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            customerId = customer.CustomerID,
            customerName = customer.Name,
            pointsBefore,
            pointsUsed,
            pointsEarned,
            customerPoints = customer.LoyaltyPoints ?? 0,
        });
    }

    [HttpPut("api/customers/{customerId:int}/profile")]
    public async Task<ActionResult> UpdateProfile(int customerId, [FromBody] UpdateProfileRequest request, CancellationToken cancellationToken)
    {
        var customer = await _db.Customers.FirstOrDefaultAsync(x => x.CustomerID == customerId && (x.IsActive ?? true), cancellationToken);
        if (customer is null)
        {
            return NotFound();
        }

        customer.Username = request.Username.Trim();
        customer.Name = request.Name.Trim();
        customer.PhoneNumber = request.PhoneNumber.Trim();
        customer.Email = request.Email;
        customer.Gender = request.Gender;
        customer.DateOfBirth = request.DateOfBirth;
        customer.Address = request.Address;
        customer.UpdatedAt = DateTime.Now;

        await _db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpGet("api/customers/admin/customers")]
    [HttpGet("api/identity/admin/customers")]
    public async Task<ActionResult<object>> GetAdminCustomers(
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _db.Customers.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(c =>
                c.Name.Contains(term)
                || c.Username.Contains(term)
                || (c.PhoneNumber != null && c.PhoneNumber.Contains(term))
                || (c.Email != null && c.Email.Contains(term)));
        }

        var totalItems = await query.CountAsync(cancellationToken);
        var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

        var items = await query
            .OrderByDescending(c => c.CreatedAt ?? c.UpdatedAt ?? DateTime.MinValue)
            .ThenBy(c => c.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(c => new
            {
                customerId = c.CustomerID,
                name = c.Name,
                username = c.Username,
                password = "",
                phoneNumber = c.PhoneNumber,
                email = c.Email,
                gender = c.Gender,
                dateOfBirth = c.DateOfBirth,
                address = c.Address,
                loyaltyPoints = c.LoyaltyPoints ?? 0,
                isActive = c.IsActive ?? false,
                createdAt = c.CreatedAt,
                updatedAt = c.UpdatedAt,
            })
            .ToListAsync(cancellationToken);

        return Ok(new
        {
            page,
            pageSize,
            totalItems,
            totalPages,
            items,
        });
    }

    [HttpGet("api/customers/admin/customers/{customerId:int}")]
    [HttpGet("api/identity/admin/customers/{customerId:int}")]
    public async Task<ActionResult<object>> GetAdminCustomerById(int customerId, CancellationToken cancellationToken)
    {
        var customer = await _db.Customers
            .AsNoTracking()
            .Where(c => c.CustomerID == customerId)
            .Select(c => new
            {
                customerId = c.CustomerID,
                name = c.Name,
                username = c.Username,
                password = "",
                phoneNumber = c.PhoneNumber,
                email = c.Email,
                gender = c.Gender,
                dateOfBirth = c.DateOfBirth,
                address = c.Address,
                loyaltyPoints = c.LoyaltyPoints ?? 0,
                isActive = c.IsActive ?? false,
            })
            .FirstOrDefaultAsync(cancellationToken);

        return customer is null ? NotFound(new { message = "Customer not found." }) : Ok(customer);
    }

    [HttpPost("api/customers/admin/customers")]
    [HttpPost("api/identity/admin/customers")]
    public async Task<ActionResult<object>> CreateAdminCustomer([FromBody] AdminUpsertCustomerRequest request, CancellationToken cancellationToken)
    {
        var error = await ValidateAdminCustomerRequestAsync(request, currentCustomerId: null, cancellationToken);
        if (!string.IsNullOrWhiteSpace(error))
        {
            return BadRequest(new { message = error });
        }

        var customer = new CustomerEntity
        {
            Name = request.Name.Trim(),
            Username = request.Username.Trim(),
            Password = PasswordHashing.HashPassword(request.Password!.Trim()),
            PhoneNumber = request.PhoneNumber.Trim(),
            Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim(),
            Gender = string.IsNullOrWhiteSpace(request.Gender) ? null : request.Gender.Trim(),
            DateOfBirth = request.DateOfBirth,
            Address = string.IsNullOrWhiteSpace(request.Address) ? null : request.Address.Trim(),
            LoyaltyPoints = request.LoyaltyPoints ?? 0,
            IsActive = request.IsActive ?? true,
            CreatedAt = DateTime.Now,
            UpdatedAt = DateTime.Now,
        };

        _db.Customers.Add(customer);
        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new { customerId = customer.CustomerID, message = "Created." });
    }

    [HttpPut("api/customers/admin/customers/{customerId:int}")]
    [HttpPut("api/identity/admin/customers/{customerId:int}")]
    public async Task<ActionResult<object>> UpdateAdminCustomer(
        int customerId,
        [FromBody] AdminUpsertCustomerRequest request,
        CancellationToken cancellationToken)
    {
        var customer = await _db.Customers.FirstOrDefaultAsync(c => c.CustomerID == customerId, cancellationToken);
        if (customer is null)
        {
            return NotFound(new { message = "Customer not found." });
        }

        var error = await ValidateAdminCustomerRequestAsync(request, currentCustomerId: customerId, cancellationToken);
        if (!string.IsNullOrWhiteSpace(error))
        {
            return BadRequest(new { message = error });
        }

        customer.Name = request.Name.Trim();
        customer.Username = request.Username.Trim();
        if (!string.IsNullOrWhiteSpace(request.Password))
        {
            customer.Password = PasswordHashing.HashPassword(request.Password.Trim());
        }

        customer.PhoneNumber = request.PhoneNumber.Trim();
        customer.Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim();
        customer.Gender = string.IsNullOrWhiteSpace(request.Gender) ? null : request.Gender.Trim();
        customer.DateOfBirth = request.DateOfBirth;
        customer.Address = string.IsNullOrWhiteSpace(request.Address) ? null : request.Address.Trim();
        customer.LoyaltyPoints = request.LoyaltyPoints ?? 0;
        customer.IsActive = request.IsActive ?? false;
        customer.UpdatedAt = DateTime.Now;

        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Updated." });
    }

    [HttpPost("api/customers/admin/customers/{customerId:int}/deactivate")]
    [HttpPost("api/identity/admin/customers/{customerId:int}/deactivate")]
    public async Task<ActionResult<object>> DeactivateAdminCustomer(int customerId, CancellationToken cancellationToken)
    {
        var customer = await _db.Customers.FirstOrDefaultAsync(c => c.CustomerID == customerId, cancellationToken);
        if (customer is null)
        {
            return NotFound(new { message = "Customer not found." });
        }

        customer.IsActive = false;
        customer.UpdatedAt = DateTime.Now;
        await _db.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "Deactivated." });
    }

    [HttpGet("api/customers/{customerId:int}/orders")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetOrders(int customerId, [FromQuery] int take = 10, CancellationToken cancellationToken = default)
    {
        take = Math.Clamp(take, 1, 50);
        var orders = await _db.Orders
            .AsNoTracking()
            .Where(x => x.CustomerID == customerId)
            .OrderByDescending(x => x.OrderTime)
            .Take(take)
            .Join(_db.OrderStatus.AsNoTracking(), o => o.StatusID, s => s.StatusID, (o, s) => new { o, s })
            .Select(x => new
            {
                orderId = x.o.OrderID,
                orderCode = x.o.OrderCode,
                orderTime = x.o.OrderTime,
                statusCode = x.s.StatusCode,
                orderStatus = x.s.StatusName,
                totalAmount = _db.Bills
                    .Where(b => b.OrderID == x.o.OrderID && b.IsActive)
                    .OrderByDescending(b => b.BillTime)
                    .Select(b => (decimal?)b.TotalAmount)
                    .FirstOrDefault()
                    ?? _db.OrderItems
                        .Where(oi => oi.OrderID == x.o.OrderID)
                        .Select(oi => (decimal?)oi.LineTotal)
                        .Sum()
                    ?? 0m,
                itemCount = _db.OrderItems
                    .Where(oi => oi.OrderID == x.o.OrderID)
                    .Select(oi => (int?)oi.Quantity)
                    .Sum()
                    ?? 0,
            })
            .ToListAsync(cancellationToken);

        return Ok(orders);
    }

    [HttpGet("api/customers/{customerId:int}/ready-notifications")]
    public async Task<ActionResult<IReadOnlyList<object>>> GetReadyNotifications(
        int customerId,
        [FromQuery] int? tableId = null,
        [FromQuery] string status = "OPEN",
        CancellationToken cancellationToken = default)
    {
        var normalizedStatus = string.IsNullOrWhiteSpace(status) ? "OPEN" : status.Trim().ToUpperInvariant();

        var query = _db.ReadyDishNotifications
            .AsNoTracking()
            .Where(x => x.Status == normalizedStatus)
            .AsQueryable();

        if (tableId is > 0)
        {
            query = query.Where(x => x.TableId == tableId.Value || x.CustomerId == customerId);
        }
        else
        {
            query = query.Where(x => x.CustomerId == customerId);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Select(x => new
            {
                readyDishNotificationId = x.ReadyDishNotificationId,
                orderId = x.OrderId,
                customerId = x.CustomerId,
                tableId = x.TableId,
                eventName = x.EventName,
                message = x.Message,
                status = x.Status,
                createdAtUtc = x.CreatedAtUtc,
            })
            .ToListAsync(cancellationToken);

        return Ok(items);
    }

    [HttpPost("api/customers/{customerId:int}/ready-notifications/{notificationId:long}/resolve")]
    public async Task<ActionResult<object>> ResolveReadyNotification(
        int customerId,
        long notificationId,
        CancellationToken cancellationToken)
    {
        var entity = await _db.ReadyDishNotifications
            .FirstOrDefaultAsync(
                x => x.ReadyDishNotificationId == notificationId
                     && (x.CustomerId == customerId || x.CustomerId == null),
                cancellationToken);

        if (entity is null)
        {
            return NotFound(new { message = "Notification not found." });
        }

        entity.Status = "RESOLVED";
        entity.ResolvedAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            readyDishNotificationId = entity.ReadyDishNotificationId,
            status = entity.Status,
        });
    }

    public sealed record LoginRequest(string Username, string Password);
    public sealed record RegisterRequest(string Name, string Username, string Password, string PhoneNumber, string? Email, string? Gender, DateOnly? DateOfBirth, string? Address);
    public sealed record ChangePasswordRequest(int CustomerId, string CurrentPassword, string NewPassword);
    public sealed record ForgotPasswordRequest(string UsernameOrEmailOrPhone);
    public sealed record ResetPasswordRequest(string Token, string NewPassword);
    public sealed record LoyaltySettlementRequest(int PointsUsed, decimal AmountPaid);
    public sealed record UpdateProfileRequest(string Username, string Name, string PhoneNumber, string? Email, string? Gender, DateOnly? DateOfBirth, string? Address);
    public sealed record AdminUpsertCustomerRequest(
        string Name,
        string Username,
        string? Password,
        string PhoneNumber,
        string? Email,
        string? Gender,
        DateOnly? DateOfBirth,
        string? Address,
        int? LoyaltyPoints,
        bool? IsActive);

    private async Task<string?> ValidateAdminCustomerRequestAsync(
        AdminUpsertCustomerRequest request,
        int? currentCustomerId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return "Name is required.";
        }

        if (string.IsNullOrWhiteSpace(request.Username))
        {
            return "Username is required.";
        }

        if (string.IsNullOrWhiteSpace(request.PhoneNumber))
        {
            return "PhoneNumber is required.";
        }

        if (currentCustomerId is null && string.IsNullOrWhiteSpace(request.Password))
        {
            return "Password is required.";
        }

        var username = request.Username.Trim();
        var exists = await _db.Customers.AnyAsync(
            c => c.Username == username && c.CustomerID != currentCustomerId,
            cancellationToken);
        if (exists)
        {
            return "Username already exists.";
        }

        return null;
    }
}
