using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SelfRestaurant.Models
{
    // ===== BRANCHES - CHI NHÁNH =====
    [Table("Branches")]
    public class Branch
    {
        [Key]
        public int BranchID { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; }

        [MaxLength(500)]
        public string Location { get; set; }

        [MaxLength(100)]
        public string ManagerName { get; set; }

        [MaxLength(20)]
        public string Phone { get; set; }

        [MaxLength(100)]
        public string Email { get; set; }

        [MaxLength(100)]
        public string OpeningHours { get; set; }

        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int RestaurantID { get; set; }

        // Navigation properties
        public virtual ICollection<Menu> Menus { get; set; }
        public virtual ICollection<DiningTable> DiningTables { get; set; }
    }

    // ===== CATEGORIES - DANH MỤC MÓN ĂN =====
    [Table("Categories")]
    public class Category
    {
        [Key]
        public int CategoryID { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; }

        public string Description { get; set; }
        public int DisplayOrder { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        // Navigation properties
        public virtual ICollection<Dishes> Dishes { get; set; }
    }

    // ===== DISHES - MÓN ĂN =====
    [Table("Dishes")]
    public class Dishes
    {
        [Key]
        public int DishID { get; set; }

        [Required]
        [MaxLength(200)]
        public string Name { get; set; }

        [Required]
        public decimal Price { get; set; }

        public bool? Available { get; set; }

        [MaxLength(500)]
        public string Image { get; set; }

        public string Description { get; set; }

        [MaxLength(50)]
        public string Unit { get; set; }

        public bool? IsVegetarian { get; set; }
        public bool? IsDailySpecial { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int CategoryID { get; set; }

        // Navigation properties
        [ForeignKey("CategoryID")]
        public virtual Category Categories { get; set; }
    }

    // ===== MENUS - THỰC ĐƠN =====
    [Table("Menus")]
    public class Menu
    {
        [Key]
        public int MenuID { get; set; }

        [Required]
        [MaxLength(200)]
        public string MenuName { get; set; }

        public DateTime? Date { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int BranchID { get; set; }

        // Navigation properties
        [ForeignKey("BranchID")]
        public virtual Branch Branches { get; set; }

        public virtual ICollection<MenuCategory> MenuCategory { get; set; }
    }

    // ===== MENU CATEGORY - LIÊN KẾT MENU VÀ CATEGORY =====
    [Table("MenuCategory")]
    public class MenuCategory
    {
        [Key]
        public int MenuCategoryID { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public bool IsActive { get; set; }
        public int MenuID { get; set; }
        public int CategoryID { get; set; }

        // Navigation properties
        [ForeignKey("MenuID")]
        public virtual Menu Menu { get; set; }

        [ForeignKey("CategoryID")]
        public virtual Category Category { get; set; }

        public virtual ICollection<CategoryDish> CategoryDish { get; set; }
    }

    

    // ===== DINING TABLES - BÀN ĂN =====
    [Table("DiningTables")]
    public class DiningTable
    {
        [Key]
        public int TableID { get; set; }

        [Required]
        [MaxLength(100)]
        public string TableCode { get; set; }

        public int NumberOfSeats { get; set; }
        public string QRCode { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int BranchID { get; set; }

        // Navigation properties
        [ForeignKey("BranchID")]
        public virtual Branch Branches { get; set; }

        public virtual ICollection<Orders> Orders { get; set; }
    }

    // ===== ORDER STATUS - TRẠNG THÁI ĐƠN HÀNG =====
    [Table("OrderStatus")]
    public class OrderStatus
    {
        [Key]
        public int StatusID { get; set; }

        [Required]
        [MaxLength(50)]
        public string StatusCode { get; set; }

        [Required]
        [MaxLength(100)]
        public string StatusName { get; set; }

        public string Description { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    // ===== ORDERS - ĐƠN HÀNG =====
    [Table("Orders")]
    public class Orders
    {
        [Key]
        public int OrderID { get; set; }

        [MaxLength(50)]
        public string OrderCode { get; set; }

        public DateTime? OrderTime { get; set; }
        public DateTime? CompletedTime { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int? TableID { get; set; }
        public int? CustomerID { get; set; }
        public int? StatusID { get; set; }

        // Navigation properties
        [ForeignKey("TableID")]
        public virtual DiningTable DiningTables { get; set; }

        [ForeignKey("StatusID")]
        public virtual OrderStatus OrderStatus { get; set; }

        public virtual ICollection<OrderItems> OrderItems { get; set; }
    }

    // ===== ORDER ITEMS - CHI TIẾT ĐƠN HÀNG =====
    [Table("OrderItems")]
    public class OrderItems
    {
        [Key]
        public int ItemID { get; set; }

        public int Quantity { get; set; }
        public decimal LineTotal { get; set; }
        public string Note { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int OrderID { get; set; }
        public int DishID { get; set; }

        // Navigation properties
        [ForeignKey("OrderID")]
        public virtual Orders Orders { get; set; }

        [ForeignKey("DishID")]
        public virtual Dishes Dishes { get; set; }
    }

    // ===== CUSTOMERS - KHÁCH HÀNG =====
    [Table("Customers")]
    public class Customers
    {
        [Key]
        public int CustomerID { get; set; }

        [Required]
        [MaxLength(100)]
        public string Username { get; set; }

        [Required]
        [MaxLength(100)]
        public string Password { get; set; }

        [MaxLength(200)]
        public string Name { get; set; }

        [MaxLength(20)]
        public string PhoneNumber { get; set; }

        [MaxLength(100)]
        public string Email { get; set; }

        [MaxLength(500)]
        public string Address { get; set; }

        [MaxLength(10)]
        public string Gender { get; set; }

        public DateTime? DateOfBirth { get; set; }
        public int? LoyaltyPoints { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}