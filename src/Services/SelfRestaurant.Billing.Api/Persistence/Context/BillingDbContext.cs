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
    public DbSet<BusinessAuditLogs> BusinessAuditLogs => Set<BusinessAuditLogs>();
    public DbSet<CheckoutCommands> CheckoutCommands => Set<CheckoutCommands>();
    public DbSet<OrderContextSnapshots> OrderContextSnapshots => Set<OrderContextSnapshots>();
    public DbSet<OutboxEvents> OutboxEvents => Set<OutboxEvents>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Bills>(entity =>
        {
            entity.HasKey(e => e.BillID);
            entity.HasIndex(e => e.BillTime).HasDatabaseName("IX_Bills_BillTime");
            entity.HasIndex(e => e.CheckoutIdempotencyKey).IsUnique().HasFilter("[CheckoutIdempotencyKey] IS NOT NULL").HasDatabaseName("UX_Bills_CheckoutIdempotencyKey");
            entity.HasIndex(e => e.OrderID).IsUnique().HasFilter("[IsActive] = 1").HasDatabaseName("UX_Bills_OrderID_Active");
            entity.HasIndex(e => e.OrderID).HasDatabaseName("IX_Bills_OrderID");
            entity.Property(e => e.BillCode).HasMaxLength(50);
            entity.Property(e => e.CheckoutIdempotencyKey).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.DiningSessionCode).HasMaxLength(64).IsUnicode(false);
            entity.Property(e => e.OrderCodeSnapshot).HasMaxLength(50);
            entity.Property(e => e.TableNameSnapshot).HasMaxLength(200);
            entity.Property(e => e.BranchNameSnapshot).HasMaxLength(200);
            entity.Property(e => e.BillTime).HasColumnType("datetime").HasDefaultValueSql("(getdate())");
            entity.Property(e => e.ChangeAmount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Discount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.PaymentAmount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.PaymentMethod).HasMaxLength(20);
            entity.Property(e => e.PointsDiscount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.Subtotal).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TotalAmount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.IsActive).HasDefaultValue(true);
        });

        modelBuilder.Entity<BusinessAuditLogs>(entity =>
        {
            entity.HasKey(e => e.BusinessAuditLogId);
            entity.HasIndex(e => e.CreatedAtUtc).HasDatabaseName("IX_BusinessAuditLogs_CreatedAtUtc");
            entity.HasIndex(e => new { e.EntityType, e.EntityId }).HasDatabaseName("IX_BusinessAuditLogs_Entity");
            entity.HasIndex(e => e.OrderId).HasDatabaseName("IX_BusinessAuditLogs_OrderId");
            entity.HasIndex(e => e.BillId).HasDatabaseName("IX_BusinessAuditLogs_BillId");
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

        modelBuilder.Entity<CheckoutCommands>(entity =>
        {
            entity.HasKey(e => e.CheckoutCommandId);
            entity.HasIndex(e => e.IdempotencyKey).IsUnique().HasDatabaseName("UX_CheckoutCommands_IdempotencyKey");
            entity.HasIndex(e => e.CreatedAtUtc).HasDatabaseName("IX_CheckoutCommands_CreatedAtUtc");
            entity.Property(e => e.BillCode).HasMaxLength(50);
            entity.Property(e => e.CustomerName).HasMaxLength(200);
            entity.Property(e => e.IdempotencyKey).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.DiningSessionCode).HasMaxLength(64).IsUnicode(false);
            entity.Property(e => e.Status).HasMaxLength(20).IsUnicode(false).HasDefaultValue("PENDING");
            entity.Property(e => e.CreatedAtUtc).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
            entity.Property(e => e.CompletedAtUtc).HasColumnType("datetime2");
            entity.Property(e => e.Error).HasColumnType("nvarchar(max)");
            entity.Property(e => e.TotalAmount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.ChangeAmount).HasColumnType("decimal(18, 2)");
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

        modelBuilder.Entity<OrderContextSnapshots>(entity =>
        {
            entity.HasKey(e => e.OrderId);
            entity.HasIndex(e => e.BranchId).HasDatabaseName("IX_OrderContextSnapshots_BranchId");
            entity.HasIndex(e => e.RefreshedAtUtc).HasDatabaseName("IX_OrderContextSnapshots_RefreshedAtUtc");
            entity.Property(e => e.OrderCode).HasMaxLength(50);
            entity.Property(e => e.TableName).HasMaxLength(200);
            entity.Property(e => e.BranchName).HasMaxLength(200);
            entity.Property(e => e.RefreshedAtUtc).HasColumnType("datetime2");
        });

    }
}
