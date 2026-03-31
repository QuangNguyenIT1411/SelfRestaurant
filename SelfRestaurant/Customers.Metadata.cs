using System;
using System.ComponentModel.DataAnnotations;

namespace SelfRestaurant
{
    [MetadataType(typeof(CustomersMetadata))]
    public partial class Customers
    {
    }

    public class CustomersMetadata
    {
        [Required(ErrorMessage = "Tên không được để trống")]
        [StringLength(150, ErrorMessage = "Tên không được vượt quá 150 ký tự")]
        [Display(Name = "Họ Tên")]
        public string Name { get; set; }

        [Required(ErrorMessage = "Email không được để trống")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        [StringLength(100, ErrorMessage = "Email không được vượt quá 100 ký tự")]
        [Display(Name = "Email")]
        public string Email { get; set; }

        [Required(ErrorMessage = "Số điện thoại không được để trống")]
        [RegularExpression(@"^\d{10,11}$", ErrorMessage = "Số điện thoại phải là 10-11 chữ số")]
        [StringLength(20, ErrorMessage = "Số điện thoại không được vượt quá 20 ký tự")]
        [Display(Name = "Số Điện Thoại")]
        public string PhoneNumber { get; set; }

        [StringLength(200, ErrorMessage = "Địa chỉ không được vượt quá 200 ký tự")]
        [Display(Name = "Địa Chỉ")]
        public string Address { get; set; }

        [StringLength(10, ErrorMessage = "Giới tính không được vượt quá 10 ký tự")]
        [Display(Name = "Giới Tính")]
        public string Gender { get; set; }

        [Display(Name = "Ngày Sinh")]
        public Nullable<System.DateTime> DateOfBirth { get; set; }

        [Required(ErrorMessage = "Tên đăng nhập không được để trống")]
        [StringLength(100, MinimumLength = 3, ErrorMessage = "Tên đăng nhập phải từ 3-100 ký tự")]
        [Display(Name = "Tên Đăng Nhập")]
        public string Username { get; set; }

        [Required(ErrorMessage = "Mật khẩu không được để trống")]
        [StringLength(255, MinimumLength = 6, ErrorMessage = "Mật khẩu phải từ 6-255 ký tự")]
        [DataType(DataType.Password)]
        [Display(Name = "Mật Khẩu")]
        public string Password { get; set; }

        [Display(Name = "Điểm Thưởng")]
        public Nullable<int> LoyaltyPoints { get; set; }

        [Display(Name = "Ngày Tạo")]
        public Nullable<System.DateTime> CreatedAt { get; set; }

        [Display(Name = "Ngày Cập Nhật")]
        public Nullable<System.DateTime> UpdatedAt { get; set; }

        [Display(Name = "Trạng Thái")]
        public Nullable<bool> IsActive { get; set; }
    }
}