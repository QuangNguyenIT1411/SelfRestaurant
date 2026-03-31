using System.ComponentModel.DataAnnotations;

namespace SelfRestaurant.Gateway.Mvc.Models;

public sealed class CustomerLoginViewModel
{
    [Required]
    [Display(Name = "Username / Email / Phone")]
    public string Username { get; set; } = "";

    [Required]
    [DataType(DataType.Password)]
    [MinLength(6, ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự.")]
    public string Password { get; set; } = "";

    public bool RememberMe { get; set; }

    public string? ReturnUrl { get; set; }
}
