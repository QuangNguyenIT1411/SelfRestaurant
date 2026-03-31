using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Billing.Api.Persistence.Entities;

namespace SelfRestaurant.Billing.Api.Persistence;

public sealed class BillingDbContext : DbContext
{
    public BillingDbContext(DbContextOptions<BillingDbContext> options)
        : base(options)
    {
    }

    public DbSet<Bills> Bills => Set<Bills>();
    public DbSet<Branches> Branches => Set<Branches>();
    public DbSet<Customers> Customers => Set<Customers>();
    public DbSet<DiningTables> DiningTables => Set<DiningTables>();
    public DbSet<Dishes> Dishes => Set<Dishes>();
    public DbSet<Employees> Employees => Set<Employees>();
    public DbSet<OrderItems> OrderItems => Set<OrderItems>();
    public DbSet<OutboxEvents> OutboxEvents => Set<OutboxEvents>();
    public DbSet<OrderStatus> OrderStatus => Set<OrderStatus>();
    public DbSet<Orders> Orders => Set<Orders>();
    public DbSet<TableStatus> TableStatus => Set<TableStatus>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Ignore<ActiveOrders>();
        modelBuilder.Ignore<BranchRevenue>();
        modelBuilder.Ignore<Categories>();
        modelBuilder.Ignore<CategoryDish>();
        modelBuilder.Ignore<CustomerLoyalty>();
        modelBuilder.Ignore<DishDetails>();
        modelBuilder.Ignore<DishIngredients>();
        modelBuilder.Ignore<EmployeeRoles>();
        modelBuilder.Ignore<Ingredients>();
        modelBuilder.Ignore<LoyaltyCards>();
        modelBuilder.Ignore<MenuCategory>();
        modelBuilder.Ignore<Menus>();
        modelBuilder.Ignore<OrderItemIngredients>();
        modelBuilder.Ignore<PasswordResetTokens>();
        modelBuilder.Ignore<PaymentMethod>();
        modelBuilder.Ignore<PaymentStatus>();
        modelBuilder.Ignore<Payments>();
        modelBuilder.Ignore<Reports>();
        modelBuilder.Ignore<Restaurants>();
        modelBuilder.Ignore<TableNumbers>();

        modelBuilder.Entity<Bills>(entity =>
        {
            entity.HasKey(e => e.BillID);
            entity.HasIndex(e => e.BillTime).HasDatabaseName("IX_Bills_BillTime");
            entity.HasIndex(e => e.OrderID).HasDatabaseName("IX_Bills_OrderID");
            entity.Property(e => e.BillCode).HasMaxLength(50);
            entity.Property(e => e.BillTime).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.ChangeAmount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Discount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.PaymentAmount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.PaymentMethod).HasMaxLength(20);
            entity.Property(e => e.PointsDiscount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Subtotal).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TotalAmount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.HasOne(e => e.Customer)
                .WithMany(c => c.Bills)
                .HasForeignKey(e => e.CustomerID);
            entity.HasOne(e => e.Employee)
                .WithMany(emp => emp.Bills)
                .HasForeignKey(e => e.EmployeeID);
            entity.HasOne(e => e.Order)
                .WithMany()
                .HasForeignKey(e => e.OrderID)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<Branches>(entity =>
        {
            entity.HasKey(e => e.BranchID);
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_branches_active");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Email).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.Location).HasMaxLength(500);
            entity.Property(e => e.ManagerName).HasMaxLength(100);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.OpeningHours).HasMaxLength(100);
            entity.Property(e => e.Phone).HasMaxLength(20).IsUnicode(false);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.Employees);
            entity.Ignore(e => e.Menus);
            entity.Ignore(e => e.Restaurant);
        });

        modelBuilder.Entity<Customers>(entity =>
        {
            entity.HasKey(e => e.CustomerID);
            entity.HasIndex(e => e.Username).IsUnique().HasDatabaseName("UQ_Customers_Username");
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_customers_active");
            entity.Property(e => e.Address).HasMaxLength(500);
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Email).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.Gender).HasMaxLength(10);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.LoyaltyPoints).HasDefaultValue(0);
            entity.Property(e => e.Name).HasMaxLength(100);
            entity.Property(e => e.Password).HasMaxLength(255).IsUnicode(false);
            entity.Property(e => e.PhoneNumber).HasMaxLength(20).IsUnicode(false);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Username).HasMaxLength(50).IsUnicode(false);
            entity.Ignore(e => e.LoyaltyCards);
            entity.Ignore(e => e.PasswordResetTokens);
            entity.Ignore(e => e.Payments);
        });

        modelBuilder.Entity<DiningTables>(entity =>
        {
            entity.HasKey(e => e.TableID);
            entity.HasIndex(e => e.BranchID).HasDatabaseName("idx_tables_branch");
            entity.HasIndex(e => e.StatusID).HasDatabaseName("idx_tables_status");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.QRCode).HasMaxLength(200).IsUnicode(false);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.HasOne(e => e.Branch)
                .WithMany(b => b.DiningTables)
                .HasForeignKey(e => e.BranchID);
            entity.HasOne(e => e.Status)
                .WithMany(s => s.DiningTables)
                .HasForeignKey(e => e.StatusID)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<Dishes>(entity =>
        {
            entity.HasKey(e => e.DishID);
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_dishes_active");
            entity.HasIndex(e => e.Available).HasDatabaseName("idx_dishes_available");
            entity.Property(e => e.Available).HasDefaultValue(true);
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Image).HasMaxLength(500).IsUnicode(false);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.IsDailySpecial).HasDefaultValue(false);
            entity.Property(e => e.IsVegetarian).HasDefaultValue(false);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.Price).HasColumnType("decimal(15, 2)");
            entity.Property(e => e.Unit).HasMaxLength(50);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.Category);
            entity.Ignore(e => e.CategoryDish);
            entity.Ignore(e => e.DishIngredients);
        });

        modelBuilder.Entity<Employees>(entity =>
        {
            entity.HasKey(e => e.EmployeeID);
            entity.HasIndex(e => e.Username).IsUnique();
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_employees_active");
            entity.HasIndex(e => e.BranchID).HasDatabaseName("idx_employees_branch");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Email).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.Name).HasMaxLength(100);
            entity.Property(e => e.Password).HasMaxLength(255).IsUnicode(false);
            entity.Property(e => e.Phone).HasMaxLength(20).IsUnicode(false);
            entity.Property(e => e.Salary).HasColumnType("decimal(15, 2)");
            entity.Property(e => e.Shift).HasMaxLength(50);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Username).HasMaxLength(50).IsUnicode(false);
            entity.Ignore(e => e.Orders);
            entity.Ignore(e => e.Role);
            entity.HasOne(e => e.Branch)
                .WithMany()
                .HasForeignKey(e => e.BranchID);
        });

        modelBuilder.Entity<OrderItems>(entity =>
        {
            entity.HasKey(e => e.ItemID);
            entity.HasIndex(e => e.DishID).HasDatabaseName("idx_orderitems_dish");
            entity.HasIndex(e => e.OrderID).HasDatabaseName("idx_orderitems_order");
            entity.Property(e => e.LineTotal).HasColumnType("decimal(15, 2)");
            entity.Property(e => e.Quantity).HasDefaultValue(1);
            entity.Property(e => e.UnitPrice).HasColumnType("decimal(15, 2)");
            entity.Ignore(e => e.OrderItemIngredients);
            entity.HasOne(e => e.Dish)
                .WithMany(d => d.OrderItems)
                .HasForeignKey(e => e.DishID)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<OutboxEvents>(entity =>
        {
            entity.HasKey(e => e.OutboxEventId);
            entity.HasIndex(e => e.Status).HasDatabaseName("IX_OutboxEvents_Status");
            entity.HasIndex(e => e.CreatedAtUtc).HasDatabaseName("IX_OutboxEvents_CreatedAtUtc");
            entity.Property(e => e.EventName).HasMaxLength(200).IsUnicode(false);
            entity.Property(e => e.Source).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.CorrelationId).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.PayloadJson).HasColumnType("nvarchar(max)");
            entity.Property(e => e.Status).HasMaxLength(30).IsUnicode(false).HasDefaultValue("PENDING");
            entity.Property(e => e.CreatedAtUtc).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
            entity.Property(e => e.OccurredAtUtc).HasColumnType("datetime2");
            entity.Property(e => e.ProcessedAtUtc).HasColumnType("datetime2");
            entity.Property(e => e.Error).HasColumnType("nvarchar(max)");
        });

        modelBuilder.Entity<OrderStatus>(entity =>
        {
            entity.HasKey(e => e.StatusID);
            entity.HasIndex(e => e.StatusCode).IsUnique();
            entity.Property(e => e.StatusCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.StatusName).HasMaxLength(100);
        });

        modelBuilder.Entity<Orders>(entity =>
        {
            entity.HasKey(e => e.OrderID);
            entity.HasIndex(e => e.OrderCode).IsUnique();
            entity.HasIndex(e => e.CustomerID).HasDatabaseName("idx_orders_customer");
            entity.HasIndex(e => e.StatusID).HasDatabaseName("idx_orders_status");
            entity.HasIndex(e => e.TableID).HasDatabaseName("idx_orders_table");
            entity.HasIndex(e => e.OrderTime).HasDatabaseName("idx_orders_time");
            entity.Property(e => e.CompletedTime).HasColumnType("datetime");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.OrderCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.OrderTime).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.Bills);
            entity.Ignore(e => e.Cashier);
            entity.Ignore(e => e.Payments);
            entity.HasOne(e => e.Customer)
                .WithMany(c => c.Orders)
                .HasForeignKey(e => e.CustomerID)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(e => e.Status)
                .WithMany(s => s.Orders)
                .HasForeignKey(e => e.StatusID)
                .OnDelete(DeleteBehavior.ClientSetNull);
            entity.HasOne(e => e.Table)
                .WithMany(t => t.Orders)
                .HasForeignKey(e => e.TableID)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<TableStatus>(entity =>
        {
            entity.HasKey(e => e.StatusID);
            entity.HasIndex(e => e.StatusCode).IsUnique();
            entity.Property(e => e.StatusCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.StatusName).HasMaxLength(100);
        });
    }
}
