using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SelfRestaurant.ViewModels
{
    // ==================== LOGIN & REGISTER ====================

    /// <summary>
    /// View Model cho đăng nhập
    /// </summary>
    public class LoginViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
        [Display(Name = "Tên đăng nhập / Email / Số điện thoại")]
        public string Username { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
        [DataType(DataType.Password)]
        [Display(Name = "Mật khẩu")]
        public string Password { get; set; }

        [Display(Name = "Nhớ tôi")]
        public bool RememberMe { get; set; }
    }

    /// <summary>
    /// View Model cho đăng ký
    /// </summary>
    public class RegisterViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên")]
        [StringLength(100, ErrorMessage = "Họ tên không quá 100 ký tự")]
        [Display(Name = "Họ và tên")]
        public string Name { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
        [StringLength(50, ErrorMessage = "Tên đăng nhập không quá 50 ký tự")]
        [Display(Name = "Tên đăng nhập")]
        public string Username { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
        [StringLength(100, MinimumLength = 6, ErrorMessage = "Mật khẩu phải có từ 6-100 ký tự")]
        [DataType(DataType.Password)]
        [Display(Name = "Mật khẩu")]
        public string Password { get; set; }

        [Required(ErrorMessage = "Vui lòng xác nhận mật khẩu")]
        [DataType(DataType.Password)]
        [Compare("Password", ErrorMessage = "Mật khẩu xác nhận không khớp")]
        [Display(Name = "Xác nhận mật khẩu")]
        public string ConfirmPassword { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập số điện thoại")]
        [Phone(ErrorMessage = "Số điện thoại không hợp lệ")]
        [Display(Name = "Số điện thoại")]
        public string PhoneNumber { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập email")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        [Display(Name = "Email")]
        public string Email { get; set; }

        [Display(Name = "Giới tính")]
        public string Gender { get; set; }

        [Display(Name = "Địa chỉ")]
        [StringLength(500, ErrorMessage = "Địa chỉ không quá 500 ký tự")]
        public string Address { get; set; }

        [Display(Name = "Ngày sinh")]
        [DataType(DataType.Date)]
        public DateTime? DateOfBirth { get; set; }
    }

    // ==================== FORGOT & RESET PASSWORD ====================

    /// <summary>
    /// View Model cho quên mật khẩu
    /// </summary>
    public class ForgotPasswordViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập email")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        [Display(Name = "Email đã đăng ký")]
        public string Email { get; set; }
    }

    /// <summary>
    /// View Model cho đặt lại mật khẩu
    /// </summary>
    public class ResetPasswordViewModel
    {
        [Required]
        public string Token { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới")]
        [StringLength(100, MinimumLength = 6, ErrorMessage = "Mật khẩu phải có từ 6-100 ký tự")]
        [DataType(DataType.Password)]
        [Display(Name = "Mật khẩu mới")]
        public string NewPassword { get; set; }

        [Required(ErrorMessage = "Vui lòng xác nhận mật khẩu")]
        [DataType(DataType.Password)]
        [Compare("NewPassword", ErrorMessage = "Mật khẩu xác nhận không khớp")]
        [Display(Name = "Xác nhận mật khẩu")]
        public string ConfirmPassword { get; set; }
    }

    // ==================== PROFILE & DASHBOARD ====================

    /// <summary>
    /// View Model cho cập nhật thông tin cá nhân
    /// </summary>
    public class UpdateProfileViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên")]
        [StringLength(100, ErrorMessage = "Họ tên không quá 100 ký tự")]
        [Display(Name = "Họ và tên")]
        public string Name { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập email")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        [Display(Name = "Email")]
        public string Email { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập số điện thoại")]
        [Phone(ErrorMessage = "Số điện thoại không hợp lệ")]
        [Display(Name = "Số điện thoại")]
        public string PhoneNumber { get; set; }

        [Display(Name = "Địa chỉ")]
        [StringLength(500, ErrorMessage = "Địa chỉ không quá 500 ký tự")]
        public string Address { get; set; }

        [Display(Name = "Giới tính")]
        public string Gender { get; set; }

        [Display(Name = "Ngày sinh")]
        [DataType(DataType.Date)]
        public DateTime? DateOfBirth { get; set; }
    }

    /// <summary>
    /// View Model cho đổi mật khẩu
    /// </summary>
    public class ChangePasswordViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu hiện tại")]
        [DataType(DataType.Password)]
        [Display(Name = "Mật khẩu hiện tại")]
        public string CurrentPassword { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới")]
        [StringLength(100, MinimumLength = 6, ErrorMessage = "Mật khẩu phải có từ 6-100 ký tự")]
        [DataType(DataType.Password)]
        [Display(Name = "Mật khẩu mới")]
        public string NewPassword { get; set; }

        [Required(ErrorMessage = "Vui lòng xác nhận mật khẩu")]
        [DataType(DataType.Password)]
        [Compare("NewPassword", ErrorMessage = "Mật khẩu xác nhận không khớp")]
        [Display(Name = "Xác nhận mật khẩu")]
        public string ConfirmPassword { get; set; }
    }

    /// <summary>
    /// View Model cho Dashboard - Trang tổng quan
    /// </summary>
    public class DashboardViewModel
    {
        // Thông tin khách hàng
        public int CustomerID { get; set; }
        public string CustomerName { get; set; }
        public string CustomerPhone { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerAddress { get; set; }
        public string Gender { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public int LoyaltyPoints { get; set; }

        // Danh sách đơn hàng
        public List<OrderSummaryViewModel> Orders { get; set; }

        // Thống kê
        public int TotalOrders { get; set; }
        public decimal TotalSpent { get; set; }
        public int PendingOrders { get; set; }
        public int CompletedOrders { get; set; }

        public DashboardViewModel()
        {
            Orders = new List<OrderSummaryViewModel>();
        }
    }

    /// <summary>
    /// View Model cho tóm tắt đơn hàng
    /// </summary>
    public class OrderSummaryViewModel
    {
        public int OrderID { get; set; }
        public string OrderCode { get; set; }
        public DateTime? OrderTime { get; set; }
        public DateTime? CompletedTime { get; set; }
        public string StatusCode { get; set; }
        public string StatusName { get; set; }
        public decimal TotalAmount { get; set; }
        public int ItemCount { get; set; }
        public string TableNumber { get; set; }
        public string Note { get; set; }

        // Computed properties
        public string FormattedOrderTime
        {
            get
            {
                return OrderTime?.ToString("dd/MM/yyyy HH:mm") ?? "";
            }
        }

        public string FormattedTotalAmount
        {
            get
            {
                return TotalAmount.ToString("N0") + " ₫";
            }
        }

        public string StatusBadgeClass
        {
            get
            {
                switch (StatusCode)
                {
                    case "PENDING":
                        return "badge bg-warning text-dark";
                    case "CONFIRMED":
                        return "badge bg-info";
                    case "PREPARING":
                        return "badge bg-primary";
                    case "READY":
                        return "badge bg-success";
                    case "SERVING":
                        return "badge bg-primary";
                    case "COMPLETED":
                        return "badge bg-success";
                    case "CANCELLED":
                        return "badge bg-danger";
                    default:
                        return "badge bg-secondary";
                }
            }
        }
    }

    // ==================== ORDER DETAILS ====================

    /// <summary>
    /// View Model cho chi tiết đơn hàng
    /// </summary>
    public class OrderDetailsViewModel
    {
        // Thông tin đơn hàng
        public int OrderID { get; set; }
        public string OrderCode { get; set; }
        public DateTime? OrderTime { get; set; }
        public DateTime? CompletedTime { get; set; }
        public string Note { get; set; }
        public string StatusName { get; set; }
        public string StatusCode { get; set; }

        // Thông tin bàn
        public string TableNumber { get; set; }
        public string BranchName { get; set; }

        // Thông tin khách hàng
        public string CustomerName { get; set; }
        public string CustomerPhone { get; set; }

        // Danh sách món ăn
        public List<OrderItemViewModel> Items { get; set; }

        // Tổng tiền
        public decimal SubTotal { get; set; }
        public decimal Discount { get; set; }
        public decimal TotalAmount { get; set; }

        public OrderDetailsViewModel()
        {
            Items = new List<OrderItemViewModel>();
        }

        // Computed properties
        public string FormattedOrderTime
        {
            get { return OrderTime?.ToString("dd/MM/yyyy HH:mm") ?? ""; }
        }

        public string FormattedCompletedTime
        {
            get { return CompletedTime?.ToString("dd/MM/yyyy HH:mm") ?? "Chưa hoàn thành"; }
        }

        public string FormattedSubTotal
        {
            get { return SubTotal.ToString("N0") + " ₫"; }
        }

        public string FormattedDiscount
        {
            get { return Discount.ToString("N0") + " ₫"; }
        }

        public string FormattedTotalAmount
        {
            get { return TotalAmount.ToString("N0") + " ₫"; }
        }
    }

    /// <summary>
    /// View Model cho món ăn trong đơn hàng
    /// </summary>
    public class OrderItemViewModel
    {
        public int ItemID { get; set; }
        public string DishName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal LineTotal { get; set; }
        public string Note { get; set; }
        public string DishImage { get; set; }

        // Computed properties
        public string FormattedUnitPrice
        {
            get { return UnitPrice.ToString("N0") + " ₫"; }
        }

        public string FormattedLineTotal
        {
            get { return LineTotal.ToString("N0") + " ₫"; }
        }
    }

    // ==================== LOYALTY CARD ====================

    /// <summary>
    /// View Model cho thẻ thành viên
    /// </summary>
    public class LoyaltyCardViewModel
    {
        public int CardID { get; set; }
        public int CurrentPoints { get; set; }
        public DateTime? IssueDate { get; set; }
        public DateTime? ExpiryDate { get; set; }
        public bool IsActive { get; set; }

        // Thông tin khách hàng
        public string CustomerName { get; set; }
        public string CustomerPhone { get; set; }
        public string CustomerEmail { get; set; }

        // Lịch sử điểm thưởng
        public List<LoyaltyHistoryViewModel> PointsHistory { get; set; }

        public LoyaltyCardViewModel()
        {
            PointsHistory = new List<LoyaltyHistoryViewModel>();
        }

        // Computed properties
        public string CardLevel
        {
            get
            {
                if (CurrentPoints >= 5000) return "Platinum";
                if (CurrentPoints >= 3000) return "Gold";
                if (CurrentPoints >= 1000) return "Silver";
                return "Bronze";
            }
        }

        public string FormattedIssueDate
        {
            get { return IssueDate?.ToString("dd/MM/yyyy") ?? ""; }
        }

        public string FormattedExpiryDate
        {
            get { return ExpiryDate?.ToString("dd/MM/yyyy") ?? ""; }
        }

        public int PointsToNextLevel
        {
            get
            {
                if (CurrentPoints >= 5000) return 0;
                if (CurrentPoints >= 3000) return 5000 - CurrentPoints;
                if (CurrentPoints >= 1000) return 3000 - CurrentPoints;
                return 1000 - CurrentPoints;
            }
        }
    }

    /// <summary>
    /// View Model cho lịch sử điểm thưởng
    /// </summary>
    public class LoyaltyHistoryViewModel
    {
        public DateTime TransactionDate { get; set; }
        public string Description { get; set; }
        public int PointsChanged { get; set; }
        public int BalanceAfter { get; set; }

        public string FormattedDate
        {
            get { return TransactionDate.ToString("dd/MM/yyyy HH:mm"); }
        }

        public string PointsChangeText
        {
            get
            {
                if (PointsChanged > 0)
                    return "+" + PointsChanged.ToString();
                return PointsChanged.ToString();
            }
        }

        public string PointsChangeClass
        {
            get
            {
                return PointsChanged > 0 ? "text-success" : "text-danger";
            }
        }
    }

    // ==================== PASSWORD RESET TOKEN ====================

    /// <summary>
    /// View Model cho token reset password
    /// </summary>
    public class PasswordResetTokenModel
    {
        public int TokenID { get; set; }
        public int CustomerID { get; set; }
        public string Token { get; set; }
        public DateTime ExpiryDate { get; set; }
        public bool IsUsed { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    // ==================== STATISTICS ====================

    /// <summary>
    /// View Model cho thống kê khách hàng
    /// </summary>
    public class CustomerStatisticsViewModel
    {
        public int TotalOrders { get; set; }
        public int CompletedOrders { get; set; }
        public int CancelledOrders { get; set; }
        public decimal TotalSpent { get; set; }
        public decimal AverageOrderValue { get; set; }
        public int LoyaltyPoints { get; set; }
        public string FavoriteDish { get; set; }
        public DateTime? LastOrderDate { get; set; }
        public DateTime? MemberSince { get; set; }

        // Computed properties
        public string FormattedTotalSpent
        {
            get { return TotalSpent.ToString("N0") + " ₫"; }
        }

        public string FormattedAverageOrderValue
        {
            get { return AverageOrderValue.ToString("N0") + " ₫"; }
        }

        public string FormattedLastOrderDate
        {
            get { return LastOrderDate?.ToString("dd/MM/yyyy") ?? "Chưa có đơn hàng"; }
        }

        public string FormattedMemberSince
        {
            get { return MemberSince?.ToString("dd/MM/yyyy") ?? ""; }
        }

        public int DaysSinceMember
        {
            get
            {
                if (MemberSince.HasValue)
                    return (DateTime.Now - MemberSince.Value).Days;
                return 0;
            }
        }
    }
}