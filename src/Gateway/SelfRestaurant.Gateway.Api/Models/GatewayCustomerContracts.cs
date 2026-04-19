namespace SelfRestaurant.Gateway.Api.Models;

public sealed record ApiErrorResponse(bool Success, string Code, string Message, object? Details = null);

public sealed record CustomerSessionDto(
    bool Authenticated,
    CustomerSessionUserDto? Customer,
    CustomerTableContextDto? TableContext);

public sealed record CustomerSessionUserDto(
    int CustomerId,
    string Username,
    string Name,
    string PhoneNumber,
    string? Email,
    int LoyaltyPoints);

public sealed record CustomerTableContextDto(
    int TableId,
    int BranchId,
    string? BranchName,
    int? TableNumber);

public sealed record SetCustomerTableContextRequest(int TableId, int BranchId);
public sealed record CustomerLoginApiRequest(string Username, string Password);
public sealed record CustomerRegisterApiRequest(
    string Name,
    string Username,
    string Password,
    string PhoneNumber,
    string? Email = null,
    string? Gender = null,
    DateOnly? DateOfBirth = null,
    string? Address = null);
public sealed record CustomerForgotPasswordApiRequest(string UsernameOrEmailOrPhone);
public sealed record CustomerResetPasswordApiRequest(string Token, string NewPassword, string ConfirmPassword);
public sealed record CustomerChangePasswordApiRequest(string CurrentPassword, string NewPassword, string ConfirmPassword);
public sealed record UpdateCustomerProfileApiRequest(
    string Username,
    string Name,
    string PhoneNumber,
    string? Email,
    string? Gender,
    DateOnly? DateOfBirth,
    string? Address);
public sealed record AddOrderItemApiRequest(int DishId, int Quantity, string? Note = null);
public sealed record SubmitMenuOrderApiRequest(int TableId, int BranchId, IReadOnlyList<AddOrderItemApiRequest>? Items);
public sealed record UpdateOrderItemQuantityApiRequest(int Quantity);
public sealed record UpdateOrderItemNoteApiRequest(string? Note);
public sealed record ScanLoyaltyApiRequest(string PhoneNumber);

public sealed record CustomerMenuScreenDto(
    CustomerTableContextDto TableContext,
    CustomerSessionUserDto? Customer,
    MenuResponse Menu,
    IReadOnlyList<int> TopDishIds,
    IReadOnlyList<CustomerDishRecommendationDto> Recommendations,
    int CurrentOrderId);

public sealed record CustomerDishRecommendationDto(
    int DishId,
    string Reason);

public sealed record CustomerMenuRecommendationsDto(
    IReadOnlyList<CustomerDishRecommendationDto> Recommendations);

public sealed record CustomerProfileDto(
    int CustomerId,
    string Username,
    string Name,
    string PhoneNumber,
    string? Email,
    string? Address,
    string? Gender,
    DateOnly? DateOfBirth,
    int LoyaltyPoints);

public sealed record CustomerReadyNotificationsDto(
    int? TableId,
    IReadOnlyList<ReadyDishNotificationDto> Items);

public sealed record CustomerDashboardDto(
    CustomerProfileDto Customer,
    CustomerDashboardSummaryDto Summary,
    IReadOnlyList<CustomerDashboardOrderDto> RecentOrders);

public sealed record CustomerDashboardSummaryDto(
    int TotalOrders,
    decimal TotalSpent,
    int PendingOrders,
    int CompletedOrders);

public sealed record CustomerDashboardOrderDto(
    int OrderId,
    string? OrderCode,
    DateTime? OrderTime,
    string? StatusCode,
    string? StatusName,
    decimal TotalAmount,
    int ItemCount);

public sealed record CustomerForgotPasswordResultDto(
    string Message,
    string? ResetToken,
    DateTime? ExpiresAt,
    string? ResetPath);
