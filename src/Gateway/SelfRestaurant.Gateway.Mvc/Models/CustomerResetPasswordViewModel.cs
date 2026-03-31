using System.ComponentModel.DataAnnotations;

namespace SelfRestaurant.Gateway.Mvc.Models;

public sealed class CustomerResetPasswordViewModel
{
    [Required(ErrorMessage = "Thiếu mã xác thực đặt lại mật khẩu.")]
    public string Token { get; set; } = "";

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới.")]
    [DataType(DataType.Password)]
    [Display(Name = "Mật khẩu mới")]
    [MinLength(6, ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự.")]
    public string NewPassword { get; set; } = "";

    [Required(ErrorMessage = "Vui lòng xác nhận mật khẩu mới.")]
    [DataType(DataType.Password)]
    [Display(Name = "Xác nhận mật khẩu")]
    [Compare(nameof(NewPassword), ErrorMessage = "Mật khẩu xác nhận không khớp.")]
    public string ConfirmPassword { get; set; } = "";
}
