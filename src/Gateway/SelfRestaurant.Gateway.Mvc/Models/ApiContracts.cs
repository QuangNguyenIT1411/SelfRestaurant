namespace SelfRestaurant.Gateway.Mvc.Models;

public sealed record BranchDto(int BranchId, string Name, string? Location);

public sealed record BranchTablesResponse(string BranchName, IReadOnlyList<BranchTableDto> Tables);

public sealed record BranchTableDto(int TableId, int BranchId, int DisplayTableNumber, int NumberOfSeats, string StatusName, bool IsAvailable);

public sealed record MenuResponse(int BranchId, string BranchName, IReadOnlyList<MenuCategoryDto> Categories);

public sealed record MenuCategoryDto(int CategoryId, string CategoryName, int DisplayOrder, IReadOnlyList<MenuDishDto> Dishes);

public sealed record MenuDishDto(
    int DishId,
    string Name,
    string? Description,
    decimal Price,
    string? Image,
    string? Unit,
    bool IsVegetarian,
    bool IsDailySpecial,
    bool Available,
    IReadOnlyList<MenuDishIngredientDto>? Ingredients = null);

public sealed record MenuDishIngredientDto(
    string Name,
    decimal Quantity,
    string? Unit);

public sealed record ActiveOrderResponse(
    int OrderId,
    string? OrderCode,
    int? TableId,
    string StatusCode,
    string OrderStatus,
    decimal Subtotal,
    int TotalItems,
    IReadOnlyList<ActiveOrderItemDto> Items);

public sealed record ActiveOrderItemDto(
    int ItemId,
    int DishId,
    string DishName,
    int Quantity,
    decimal UnitPrice,
    decimal LineTotal,
    string? Note,
    string? Unit,
    string? Image,
    string? Status);

public sealed record CustomerProfileResponse(
    int CustomerId,
    string Username,
    string Name,
    string PhoneNumber,
    string? Email,
    string? Gender,
    DateOnly? DateOfBirth,
    string? Address,
    int LoyaltyPoints);

public sealed record CustomerOrderHistoryDto(
    int OrderId,
    string? OrderCode,
    DateTime? OrderTime,
    string? StatusCode,
    string? OrderStatus,
    decimal TotalAmount = 0,
    int ItemCount = 0);

public sealed record ReadyDishNotificationDto(
    long ReadyDishNotificationId,
    int OrderId,
    int? CustomerId,
    int? TableId,
    string EventName,
    string Message,
    string Status,
    DateTime CreatedAtUtc);

public sealed record CategoryDto(int CategoryId, string Name, string? Description, int DisplayOrder, bool IsActive);

public sealed record AdminIdentityStatsResponse(int TotalEmployees, int ActiveEmployees, int BranchCount);

public sealed record AdminOrderStatsResponse(int TodayOrders, int PendingOrders, decimal TodayRevenue);

public sealed record AdminRevenueReportRowDto(
    DateOnly Date,
    int BranchId,
    string BranchName,
    int TotalOrders,
    decimal TotalRevenue);

public sealed record AdminRevenueReportDto(
    decimal TotalRevenue,
    IReadOnlyList<AdminRevenueReportRowDto> RevenueByBranchDate);

public sealed record AdminTopDishReportItemDto(
    int DishId,
    string DishName,
    string CategoryName,
    int TotalQuantity,
    decimal TotalRevenue);

public sealed record AdminTopDishReportDto(IReadOnlyList<AdminTopDishReportItemDto> Items);

public sealed record StaffLoginRequest(string Username, string Password);

public sealed record StaffLoginResponse(
    int EmployeeId,
    string Username,
    string Name,
    string? Phone,
    string? Email,
    int RoleId,
    string RoleCode,
    string RoleName,
    int BranchId,
    string BranchName);

public sealed record StaffChangePasswordRequest(int EmployeeId, string CurrentPassword, string NewPassword);
public sealed record StaffForgotPasswordRequest(string EmailOrUsername);
public sealed record StaffResetPasswordRequest(string Token, string NewPassword);

public sealed record StaffUpdateProfileRequest(string Name, string Phone, string? Email = null);

public sealed record LoginRequest(string Username, string Password);

public sealed record LoginResponse(
    int CustomerId,
    string Username,
    string Name,
    string PhoneNumber,
    string? Email,
    int LoyaltyPoints);

public sealed record RegisterRequest(
    string Name,
    string Username,
    string Password,
    string PhoneNumber,
    string? Email = null,
    string? Gender = null,
    DateOnly? DateOfBirth = null,
    string? Address = null);

public sealed record ChangePasswordRequest(int CustomerId, string CurrentPassword, string NewPassword);

public sealed record ForgotPasswordRequest(string UsernameOrEmailOrPhone);

public sealed record ForgotPasswordResponse(string Message, string? ResetToken, DateTime? ExpiresAt);

public sealed record ResetPasswordRequest(string Token, string NewPassword);

public sealed record UpdateCustomerProfileRequest(
    string Username,
    string Name,
    string PhoneNumber,
    string? Email,
    string? Gender,
    DateOnly? DateOfBirth,
    string? Address);

public sealed record CreateCategoryRequest(string Name, string? Description, int DisplayOrder);

public sealed record UpdateCategoryRequest(string Name, string? Description, int DisplayOrder, bool IsActive);

public sealed record ChefOrderItemDto(int ItemId, string DishName, int Quantity, string? Note);

public sealed record ChefOrderDto(
    int OrderId,
    string? OrderCode,
    int? TableId,
    string? TableName,
    string StatusCode,
    string StatusName,
    DateTime OrderTime,
    IReadOnlyList<ChefOrderItemDto> Items);

public sealed record ChefHistoryDto(
    int OrderId,
    string? OrderCode,
    DateTime OrderTime,
    DateTime? CompletedTime,
    string? TableName,
    string StatusCode,
    string StatusName,
    string DishesSummary);

public sealed record CashierOrderItemDto(
    int ItemId,
    int OrderId,
    int DishId,
    string DishName,
    int Quantity,
    decimal UnitPrice,
    decimal LineTotal,
    string? Image,
    string? Note);

public sealed record CashierOrderDto(
    int OrderId,
    string? OrderCode,
    DateTime OrderTime,
    int TableId,
    string TableName,
    int? CustomerId,
    string? CustomerName,
    int CustomerPoints,
    string StatusCode,
    string StatusName,
    decimal Subtotal,
    int ItemCount,
    IReadOnlyList<CashierOrderItemDto> Items);

public sealed record CashierCheckoutRequest(
    int EmployeeId,
    decimal Discount = 0,
    int PointsUsed = 0,
    string PaymentMethod = "CASH",
    decimal PaymentAmount = 0);

public sealed record CashierCheckoutResponse(
    string BillCode,
    decimal TotalAmount,
    decimal ChangeAmount,
    int PointsUsed,
    int PointsEarned,
    int CustomerPoints,
    string? CustomerName,
    int PointsBefore);

public sealed record CashierBillSummaryDto(
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

public sealed record CashierReportDto(
    DateOnly Date,
    int EmployeeId,
    int BranchId,
    int BillCount,
    decimal TotalRevenue,
    IReadOnlyList<CashierBillSummaryDto> Bills);

public sealed record BranchCashierReportDto(
    DateOnly Date,
    int BranchId,
    int BillCount,
    decimal TotalRevenue);

public sealed record EmployeeRoleDto(int RoleId, string RoleCode, string RoleName);

public sealed record AdminEmployeeDto(
    int EmployeeId,
    string Name,
    string Username,
    string? Password,
    string? Phone,
    string? Email,
    decimal? Salary,
    string? Shift,
    bool IsActive,
    int BranchId,
    string BranchName,
    int RoleId,
    string RoleCode,
    string RoleName);

public sealed record AdminEmployeePagedResponse(
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages,
    IReadOnlyList<AdminEmployeeDto> Items);

public sealed record AdminUpsertEmployeeRequest(
    string Name,
    string Username,
    string? Password,
    string? Phone,
    string? Email,
    decimal? Salary,
    string? Shift,
    bool? IsActive,
    int? BranchId,
    int? RoleId);

public sealed record AdminEmployeeHistoryMetaDto(
    int EmployeeId,
    string EmployeeName,
    string RoleCode,
    string RoleName,
    int BranchId,
    string BranchName);

public sealed record AdminChefHistoryItemDto(
    int OrderId,
    string? OrderCode,
    DateTime OrderTime,
    DateTime? CompletedTime,
    string? TableName,
    string? BranchName,
    string StatusCode,
    string StatusName,
    string DishesSummary)
{
    public string StatusBadgeClass => StatusCode?.ToUpperInvariant() switch
    {
        "READY" => "badge bg-success",
        "PREPARING" => "badge bg-warning text-dark",
        "PENDING" => "badge bg-secondary",
        "COMPLETED" => "badge bg-primary",
        _ => "badge bg-secondary"
    };
}

public sealed record AdminCashierHistoryItemDto(
    int BillId,
    string BillCode,
    DateTime BillTime,
    string? OrderCode,
    string? TableName,
    string? CustomerName,
    decimal Subtotal,
    decimal Discount,
    decimal PointsDiscount,
    int? PointsUsed,
    decimal TotalAmount,
    string PaymentMethod,
    decimal? PaymentAmount,
    decimal? ChangeAmount);

public sealed record AdminEmployeeHistoryResponse(
    AdminEmployeeHistoryMetaDto Employee,
    IReadOnlyList<AdminChefHistoryItemDto> ChefHistory,
    IReadOnlyList<AdminCashierHistoryItemDto> CashierHistory);

public sealed record AdminCustomerDto(
    int CustomerId,
    string Name,
    string Username,
    string? Password,
    string PhoneNumber,
    string? Email,
    string? Gender,
    DateOnly? DateOfBirth,
    string? Address,
    int LoyaltyPoints,
    bool IsActive);

public sealed record AdminCustomerPagedResponse(
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages,
    IReadOnlyList<AdminCustomerDto> Items);

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

public sealed record AdminDishDto(
    int DishId,
    string Name,
    decimal Price,
    int CategoryId,
    string CategoryName,
    string? Description,
    string? Unit,
    string? Image,
    bool IsVegetarian,
    bool IsDailySpecial,
    bool Available,
    bool IsActive);

public sealed record AdminDishPagedResponse(
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages,
    IReadOnlyList<AdminDishDto> Items);

public sealed record AdminUpsertDishRequest(
    string Name,
    decimal? Price,
    int? CategoryId,
    string? Description,
    string? Unit,
    string? Image,
    bool? IsVegetarian,
    bool? IsDailySpecial,
    bool? Available,
    bool? IsActive);

public sealed record AdminDishIngredientLineDto(
    int IngredientId,
    string Name,
    string Unit,
    decimal CurrentStock,
    bool IsActive,
    bool Selected,
    decimal QuantityPerDish);

public sealed record AdminDishIngredientItemRequest(int IngredientId, decimal QuantityPerDish);
public sealed record AdminUpdateDishIngredientsRequest(IReadOnlyList<AdminDishIngredientItemRequest> Items);

public sealed record AdminIngredientDto(
    int IngredientId,
    string Name,
    string Unit,
    decimal CurrentStock,
    decimal ReorderLevel,
    bool IsActive);

public sealed record AdminIngredientPagedResponse(
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages,
    IReadOnlyList<AdminIngredientDto> Items);

public sealed record AdminUpsertIngredientRequest(
    string Name,
    string Unit,
    decimal? CurrentStock,
    decimal? ReorderLevel,
    bool? IsActive);

public sealed record TableStatusDto(int StatusId, string StatusCode, string StatusName);

public sealed record AdminTableDto(
    int TableId,
    int BranchId,
    string BranchName,
    int NumberOfSeats,
    string? QRCode,
    int StatusId,
    string StatusCode,
    string StatusName,
    bool IsActive);

public sealed record AdminTablePagedResponse(
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages,
    IReadOnlyList<AdminTableDto> Items);

public sealed record AdminUpsertTableRequest(
    int? BranchId,
    int? NumberOfSeats,
    string? QRCode,
    int? StatusId,
    bool? IsActive);
