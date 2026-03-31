using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Customers.Api.Persistence.Entities;
using CustomerEntity = SelfRestaurant.Customers.Api.Persistence.Entities.Customers;
using OrderEntity = SelfRestaurant.Customers.Api.Persistence.Entities.Orders;

namespace SelfRestaurant.Customers.Api.Persistence;

public sealed class CustomersDbContext : DbContext
{
    public CustomersDbContext(DbContextOptions<CustomersDbContext> options)
        : base(options)
    {
    }

    public DbSet<Bills> Bills => Set<Bills>();
    public DbSet<Branches> Branches => Set<Branches>();
    public DbSet<CustomerEntity> Customers => Set<CustomerEntity>();
    public DbSet<DiningTables> DiningTables => Set<DiningTables>();
    public DbSet<Dishes> Dishes => Set<Dishes>();
    public DbSet<EmployeeRoles> EmployeeRoles => Set<EmployeeRoles>();
    public DbSet<Employees> Employees => Set<Employees>();
    public DbSet<InboxEvents> InboxEvents => Set<InboxEvents>();
    public DbSet<OrderItems> OrderItems => Set<OrderItems>();
    public DbSet<OrderStatus> OrderStatus => Set<OrderStatus>();
    public DbSet<OrderEntity> Orders => Set<OrderEntity>();
    public DbSet<PasswordResetTokens> PasswordResetTokens => Set<PasswordResetTokens>();
    public DbSet<ReadyDishNotifications> ReadyDishNotifications => Set<ReadyDishNotifications>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Ignore<ActiveOrders>();
        modelBuilder.Ignore<BranchRevenue>();
        modelBuilder.Ignore<Categories>();
        modelBuilder.Ignore<CategoryDish>();
        modelBuilder.Ignore<CustomerLoyalty>();
        modelBuilder.Ignore<DishDetails>();
        modelBuilder.Ignore<DishIngredients>();
        modelBuilder.Ignore<Ingredients>();
        modelBuilder.Ignore<LoyaltyCards>();
        modelBuilder.Ignore<MenuCategory>();
        modelBuilder.Ignore<Menus>();
        modelBuilder.Ignore<OrderItemIngredients>();
        modelBuilder.Ignore<PaymentMethod>();
        modelBuilder.Ignore<PaymentStatus>();
        modelBuilder.Ignore<Payments>();
        modelBuilder.Ignore<Reports>();
        modelBuilder.Ignore<Restaurants>();
        modelBuilder.Ignore<TableNumbers>();
        modelBuilder.Ignore<TableStatus>();

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
            entity.Ignore(e => e.Menus);
            entity.Ignore(e => e.Restaurant);
        });

        modelBuilder.Entity<CustomerEntity>(entity =>
        {
            entity.HasKey(e => e.CustomerID);
            entity.HasIndex(e => e.Username).IsUnique().HasDatabaseName("UQ_Customers_Username");
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_customers_active");
            entity.HasIndex(e => e.Email).HasDatabaseName("idx_customers_email");
            entity.HasIndex(e => e.PhoneNumber).HasDatabaseName("idx_customers_phone");
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
            entity.Ignore(e => e.Payments);
        });

        modelBuilder.Entity<DiningTables>(entity =>
        {
            entity.HasKey(e => e.TableID);
            entity.HasIndex(e => e.BranchID).HasDatabaseName("idx_diningtables_branch");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.QRCode).HasMaxLength(200).IsUnicode(false);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.Status);
            entity.HasOne(e => e.Branch)
                .WithMany(b => b.DiningTables)
                .HasForeignKey(e => e.BranchID);
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

        modelBuilder.Entity<EmployeeRoles>(entity =>
        {
            entity.HasKey(e => e.RoleID);
            entity.HasIndex(e => e.RoleCode).IsUnique();
            entity.Property(e => e.RoleCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.RoleName).HasMaxLength(100);
        });

        modelBuilder.Entity<Employees>(entity =>
        {
            entity.HasKey(e => e.EmployeeID);
            entity.HasIndex(e => e.Username).IsUnique();
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_employees_active");
            entity.HasIndex(e => e.BranchID).HasDatabaseName("idx_employees_branch");
            entity.HasIndex(e => e.RoleID).HasDatabaseName("idx_employees_role");
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
            entity.HasOne(e => e.Branch)
                .WithMany(b => b.Employees)
                .HasForeignKey(e => e.BranchID);
            entity.HasOne(e => e.Role)
                .WithMany(r => r.Employees)
                .HasForeignKey(e => e.RoleID)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<InboxEvents>(entity =>
        {
            entity.HasKey(e => e.InboxEventId);
            entity.HasIndex(e => new { e.Source, e.SourceEventId }).IsUnique().HasDatabaseName("UX_InboxEvents_Source_SourceEventId");
            entity.HasIndex(e => e.ReceivedAtUtc).HasDatabaseName("IX_InboxEvents_ReceivedAtUtc");
            entity.Property(e => e.Source).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.EventName).HasMaxLength(200).IsUnicode(false);
            entity.Property(e => e.CorrelationId).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.PayloadJson).HasColumnType("nvarchar(max)");
            entity.Property(e => e.Status).HasMaxLength(30).IsUnicode(false).HasDefaultValue("PROCESSED");
            entity.Property(e => e.RetryCount).HasDefaultValue(0);
            entity.Property(e => e.ReceivedAtUtc).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
            entity.Property(e => e.NextRetryAtUtc).HasColumnType("datetime2");
            entity.Property(e => e.ProcessedAtUtc).HasColumnType("datetime2");
            entity.Property(e => e.Error).HasColumnType("nvarchar(max)");
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

        modelBuilder.Entity<OrderStatus>(entity =>
        {
            entity.HasKey(e => e.StatusID);
            entity.HasIndex(e => e.StatusCode).IsUnique();
            entity.Property(e => e.StatusCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.StatusName).HasMaxLength(100);
        });

        modelBuilder.Entity<ReadyDishNotifications>(entity =>
        {
            entity.HasKey(e => e.ReadyDishNotificationId);
            entity.HasIndex(e => new { e.OrderId, e.EventName }).HasDatabaseName("IX_ReadyDishNotifications_Order_Event");
            entity.Property(e => e.EventName).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.Message).HasMaxLength(500);
            entity.Property(e => e.Status).HasMaxLength(30).IsUnicode(false).HasDefaultValue("OPEN");
            entity.Property(e => e.CreatedAtUtc).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
            entity.Property(e => e.ResolvedAtUtc).HasColumnType("datetime2");
        });

        modelBuilder.Entity<OrderEntity>(entity =>
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

        modelBuilder.Entity<PasswordResetTokens>(entity =>
        {
            entity.HasKey(e => e.TokenID);
            entity.HasIndex(e => e.CustomerID).HasDatabaseName("idx_customer");
            entity.HasIndex(e => e.Token).HasDatabaseName("idx_token");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.ExpiryDate).HasColumnType("datetime");
            entity.Property(e => e.Token).HasMaxLength(255).IsUnicode(false);
            entity.HasOne(e => e.Customer)
                .WithMany(c => c.PasswordResetTokens)
                .HasForeignKey(e => e.CustomerID);
        });
    }
}
