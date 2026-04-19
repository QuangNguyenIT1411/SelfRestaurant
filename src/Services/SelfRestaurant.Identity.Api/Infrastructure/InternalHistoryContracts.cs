namespace SelfRestaurant.Identity.Api.Infrastructure;

public sealed record ChefHistoryAggregateResponse(
    int OrderId,
    string? OrderCode,
    DateTime OrderTime,
    DateTime? CompletedTime,
    string? TableName,
    string? BranchName,
    string StatusCode,
    string StatusName,
    string DishesSummary);

public sealed record CashierHistoryAggregateResponse(
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
