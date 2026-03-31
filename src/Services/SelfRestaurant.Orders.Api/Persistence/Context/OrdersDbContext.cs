using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Orders.Api.Persistence.Entities;
using CustomerEntity = SelfRestaurant.Orders.Api.Persistence.Entities.Customers;
using OrderEntity = SelfRestaurant.Orders.Api.Persistence.Entities.Orders;

namespace SelfRestaurant.Orders.Api.Persistence;

public sealed class OrdersDbContext : DbContext
{
    public OrdersDbContext(DbContextOptions<OrdersDbContext> options)
        : base(options)
    {
    }

    public DbSet<Branches> Branches => Set<Branches>();
    public DbSet<Categories> Categories => Set<Categories>();
    public DbSet<CustomerEntity> Customers => Set<CustomerEntity>();
    public DbSet<DiningTables> DiningTables => Set<DiningTables>();
    public DbSet<Dishes> Dishes => Set<Dishes>();
    public DbSet<LoyaltyCards> LoyaltyCards => Set<LoyaltyCards>();
    public DbSet<InboxEvents> InboxEvents => Set<InboxEvents>();
    public DbSet<OrderItems> OrderItems => Set<OrderItems>();
    public DbSet<OutboxEvents> OutboxEvents => Set<OutboxEvents>();
    public DbSet<OrderStatus> OrderStatus => Set<OrderStatus>();
    public DbSet<OrderEntity> Orders => Set<OrderEntity>();
    public DbSet<TableStatus> TableStatus => Set<TableStatus>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Ignore<ActiveOrders>();
        modelBuilder.Ignore<Bills>();
        modelBuilder.Ignore<BranchRevenue>();
        modelBuilder.Ignore<CategoryDish>();
        modelBuilder.Ignore<CustomerLoyalty>();
        modelBuilder.Ignore<DishDetails>();
        modelBuilder.Ignore<DishIngredients>();
        modelBuilder.Ignore<EmployeeRoles>();
        modelBuilder.Ignore<Employees>();
        modelBuilder.Ignore<Ingredients>();
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

        modelBuilder.Entity<Categories>(entity =>
        {
            entity.HasKey(e => e.CategoryID);
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_categories_active");
            entity.HasIndex(e => e.DisplayOrder).HasDatabaseName("idx_categories_display");
            entity.HasIndex(e => e.Name).HasDatabaseName("idx_categories_name");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.DisplayOrder).HasDefaultValue(0);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.MenuCategory);
        });

        modelBuilder.Entity<CustomerEntity>(entity =>
        {
            entity.HasKey(e => e.CustomerID);
            entity.HasIndex(e => e.Username).IsUnique().HasDatabaseName("UQ_Customers_Username");
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_customers_active");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Email).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.Name).HasMaxLength(100);
            entity.Property(e => e.PhoneNumber).HasMaxLength(20).IsUnicode(false);
            entity.Property(e => e.Username).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.Password).HasMaxLength(255);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.Bills);
            entity.Ignore(e => e.PasswordResetTokens);
            entity.Ignore(e => e.Payments);
        });

        modelBuilder.Entity<DiningTables>(entity =>
        {
            entity.HasKey(e => e.TableID);
            entity.HasIndex(e => e.BranchID).HasDatabaseName("idx_tables_branch");
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_tables_active");
            entity.HasIndex(e => e.StatusID).HasDatabaseName("idx_tables_status");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.QRCode).HasMaxLength(100);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.HasOne(e => e.Branch)
                .WithMany(b => b.DiningTables)
                .HasForeignKey(e => e.BranchID);
            entity.HasOne(e => e.Status)
                .WithMany(s => s.DiningTables)
                .HasForeignKey(e => e.StatusID);
        });

        modelBuilder.Entity<Dishes>(entity =>
        {
            entity.HasKey(e => e.DishID);
            entity.HasIndex(e => e.CategoryID).HasDatabaseName("idx_dishes_category");
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_dishes_active");
            entity.HasIndex(e => e.Available).HasDatabaseName("idx_dishes_available");
            entity.Property(e => e.CreatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.Description).HasMaxLength(1000);
            entity.Property(e => e.Image).HasMaxLength(500);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.Price).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Unit).HasMaxLength(50);
            entity.Property(e => e.UpdatedAt).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.CategoryDish);
            entity.Ignore(e => e.DishIngredients);
            entity.HasOne(e => e.Category)
                .WithMany(c => c.Dishes)
                .HasForeignKey(e => e.CategoryID);
        });

        modelBuilder.Entity<LoyaltyCards>(entity =>
        {
            entity.HasKey(e => e.CardID);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.HasOne(e => e.Customer)
                .WithMany(c => c.LoyaltyCards)
                .HasForeignKey(e => e.CustomerID);
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
            entity.HasIndex(e => e.OrderID).HasDatabaseName("idx_orderitems_order");
            entity.HasIndex(e => e.DishID).HasDatabaseName("idx_orderitems_dish");
            entity.Property(e => e.LineTotal).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Note).HasMaxLength(500);
            entity.Property(e => e.UnitPrice).HasColumnType("decimal(18, 2)");
            entity.Ignore(e => e.OrderItemIngredients);
            entity.HasOne(e => e.Dish)
                .WithMany(d => d.OrderItems)
                .HasForeignKey(e => e.DishID);
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
            entity.Property(e => e.StatusCode).HasMaxLength(50);
            entity.Property(e => e.StatusName).HasMaxLength(100);
        });

        modelBuilder.Entity<OrderEntity>(entity =>
        {
            entity.HasKey(e => e.OrderID);
            entity.HasIndex(e => e.OrderCode).IsUnique();
            entity.HasIndex(e => e.OrderTime).HasDatabaseName("idx_orders_time");
            entity.HasIndex(e => e.StatusID).HasDatabaseName("idx_orders_status");
            entity.HasIndex(e => e.TableID).HasDatabaseName("idx_orders_table");
            entity.Property(e => e.CompletedTime).HasColumnType("datetime");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.Note).HasMaxLength(1000);
            entity.Property(e => e.OrderCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.OrderTime).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Ignore(e => e.Bills);
            entity.Ignore(e => e.Cashier);
            entity.Ignore(e => e.Payments);
            entity.HasOne(e => e.Customer)
                .WithMany(c => c.Orders)
                .HasForeignKey(e => e.CustomerID);
            entity.HasOne(e => e.Status)
                .WithMany(s => s.Orders)
                .HasForeignKey(e => e.StatusID);
            entity.HasOne(e => e.Table)
                .WithMany(t => t.Orders)
                .HasForeignKey(e => e.TableID);
        });

        modelBuilder.Entity<TableStatus>(entity =>
        {
            entity.HasKey(e => e.StatusID);
            entity.Property(e => e.StatusCode).HasMaxLength(50);
            entity.Property(e => e.StatusName).HasMaxLength(100);
        });
    }
}
