using System.ComponentModel.DataAnnotations;

namespace SelfRestaurant.Gateway.Mvc.Models;

public sealed class CustomerForgotPasswordViewModel
{
    [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập, email hoặc số điện thoại.")]
    [Display(Name = "Tên đăng nhập / Email / SĐT")]
    public string UsernameOrEmailOrPhone { get; set; } = "";
}
