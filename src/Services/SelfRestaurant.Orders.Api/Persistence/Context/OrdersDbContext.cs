using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Orders.Api.Persistence.Entities;
using OrderEntity = SelfRestaurant.Orders.Api.Persistence.Entities.Orders;

namespace SelfRestaurant.Orders.Api.Persistence;

public sealed class OrdersDbContext : DbContext
{
    public OrdersDbContext(DbContextOptions<OrdersDbContext> options)
        : base(options)
    {
    }

    public DbSet<CatalogBranchSnapshots> CatalogBranchSnapshots => Set<CatalogBranchSnapshots>();
    public DbSet<CatalogDishSnapshots> CatalogDishSnapshots => Set<CatalogDishSnapshots>();
    public DbSet<CatalogTableSnapshots> CatalogTableSnapshots => Set<CatalogTableSnapshots>();
    public DbSet<BusinessAuditLogs> BusinessAuditLogs => Set<BusinessAuditLogs>();
    public DbSet<InboxEvents> InboxEvents => Set<InboxEvents>();
    public DbSet<OrderItems> OrderItems => Set<OrderItems>();
    public DbSet<OutboxEvents> OutboxEvents => Set<OutboxEvents>();
    public DbSet<OrderStatus> OrderStatus => Set<OrderStatus>();
    public DbSet<OrderEntity> Orders => Set<OrderEntity>();
    public DbSet<SubmitCommands> SubmitCommands => Set<SubmitCommands>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<CatalogBranchSnapshots>(entity =>
        {
            entity.HasKey(e => e.BranchId);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.Location).HasMaxLength(500);
            entity.Property(e => e.RefreshedAtUtc).HasColumnType("datetime2");
        });

        modelBuilder.Entity<CatalogDishSnapshots>(entity =>
        {
            entity.HasKey(e => e.DishId);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.CategoryName).HasMaxLength(200);
            entity.Property(e => e.Price).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Unit).HasMaxLength(50);
            entity.Property(e => e.Image).HasMaxLength(500);
            entity.Property(e => e.RefreshedAtUtc).HasColumnType("datetime2");
        });

        modelBuilder.Entity<CatalogTableSnapshots>(entity =>
        {
            entity.HasKey(e => e.TableId);
            entity.Property(e => e.QrCode).HasMaxLength(100);
            entity.Property(e => e.StatusCode).HasMaxLength(50);
            entity.Property(e => e.StatusName).HasMaxLength(100);
            entity.Property(e => e.RefreshedAtUtc).HasColumnType("datetime2");
        });

        modelBuilder.Entity<BusinessAuditLogs>(entity =>
        {
            entity.HasKey(e => e.BusinessAuditLogId);
            entity.HasIndex(e => e.CreatedAtUtc).HasDatabaseName("IX_BusinessAuditLogs_CreatedAtUtc");
            entity.HasIndex(e => new { e.EntityType, e.EntityId }).HasDatabaseName("IX_BusinessAuditLogs_Entity");
            entity.HasIndex(e => e.OrderId).HasDatabaseName("IX_BusinessAuditLogs_OrderId");
            entity.HasIndex(e => e.TableId).HasDatabaseName("IX_BusinessAuditLogs_TableId");
            entity.Property(e => e.CreatedAtUtc).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
            entity.Property(e => e.ActionType).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.EntityType).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.EntityId).HasMaxLength(100);
            entity.Property(e => e.ActorType).HasMaxLength(30).IsUnicode(false);
            entity.Property(e => e.ActorCode).HasMaxLength(100);
            entity.Property(e => e.ActorName).HasMaxLength(200);
            entity.Property(e => e.ActorRoleCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.DiningSessionCode).HasMaxLength(64).IsUnicode(false);
            entity.Property(e => e.CorrelationId).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.IdempotencyKey).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.Notes).HasMaxLength(500);
            entity.Property(e => e.BeforeState).HasColumnType("nvarchar(max)");
            entity.Property(e => e.AfterState).HasColumnType("nvarchar(max)");
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
            entity.Property(e => e.StatusCode).HasMaxLength(30).IsUnicode(false).HasDefaultValue("PENDING");
            entity.Property(e => e.UnitPrice).HasColumnType("decimal(18, 2)");
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
            entity.HasIndex(e => e.DiningSessionCode).HasDatabaseName("idx_orders_session");
            entity.HasIndex(e => e.OrderCode).IsUnique();
            entity.HasIndex(e => e.SubmitIdempotencyKey).IsUnique().HasFilter("[SubmitIdempotencyKey] IS NOT NULL").HasDatabaseName("UX_Orders_SubmitIdempotencyKey");
            entity.HasIndex(e => e.OrderTime).HasDatabaseName("idx_orders_time");
            entity.HasIndex(e => e.StatusID).HasDatabaseName("idx_orders_status");
            entity.HasIndex(e => e.TableID).HasDatabaseName("idx_orders_table");
            entity.Property(e => e.CompletedTime).HasColumnType("datetime");
            entity.Property(e => e.DiningSessionCode).HasMaxLength(64).IsUnicode(false);
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.Note).HasMaxLength(1000);
            entity.Property(e => e.OrderCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(e => e.OrderTime).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.SubmitIdempotencyKey).HasMaxLength(100).IsUnicode(false);
            entity.HasOne(e => e.Status)
                .WithMany(s => s.Orders)
                .HasForeignKey(e => e.StatusID);
        });

        modelBuilder.Entity<SubmitCommands>(entity =>
        {
            entity.HasKey(e => e.SubmitCommandId);
            entity.HasIndex(e => e.IdempotencyKey).IsUnique().HasDatabaseName("UX_SubmitCommands_IdempotencyKey");
            entity.HasIndex(e => e.CreatedAtUtc).HasDatabaseName("IX_SubmitCommands_CreatedAtUtc");
            entity.Property(e => e.IdempotencyKey).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.DiningSessionCode).HasMaxLength(64).IsUnicode(false);
            entity.Property(e => e.Status).HasMaxLength(20).IsUnicode(false).HasDefaultValue("PENDING");
            entity.Property(e => e.CreatedAtUtc).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
            entity.Property(e => e.CompletedAtUtc).HasColumnType("datetime2");
            entity.Property(e => e.Error).HasColumnType("nvarchar(max)");
        });
    }
}
