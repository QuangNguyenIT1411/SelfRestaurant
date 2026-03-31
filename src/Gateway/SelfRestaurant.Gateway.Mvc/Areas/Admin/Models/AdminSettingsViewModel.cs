using System.ComponentModel.DataAnnotations;

namespace SelfRestaurant.Gateway.Mvc.Areas.Admin.Models;

public sealed class AdminSettingsViewModel
{
    [Required]
    [Display(Name = "Ho ten")]
    public string Name { get; set; } = "";

    [Display(Name = "Tai khoan")]
    public string Username { get; set; } = "";

    [Required]
    [Display(Name = "So dien thoai")]
    public string Phone { get; set; } = "";

    [EmailAddress]
    [Display(Name = "Email")]
    public string? Email { get; set; }

    [DataType(DataType.Password)]
    [Display(Name = "Mat khau hien tai")]
    public string? CurrentPassword { get; set; }

    [DataType(DataType.Password)]
    [Display(Name = "Mat khau moi")]
    [MinLength(6)]
    public string? NewPassword { get; set; }

    [DataType(DataType.Password)]
    [Display(Name = "Nhap lai mat khau moi")]
    [Compare(nameof(NewPassword), ErrorMessage = "Xac nhan mat khau khong khop.")]
    public string? ConfirmPassword { get; set; }
}
