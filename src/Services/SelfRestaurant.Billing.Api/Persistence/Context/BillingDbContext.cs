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
    public DbSet<OrderContextSnapshots> OrderContextSnapshots => Set<OrderContextSnapshots>();
    public DbSet<OutboxEvents> OutboxEvents => Set<OutboxEvents>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Bills>(entity =>
        {
            entity.HasKey(e => e.BillID);
            entity.HasIndex(e => e.BillTime).HasDatabaseName("IX_Bills_BillTime");
            entity.HasIndex(e => e.OrderID).HasDatabaseName("IX_Bills_OrderID");
            entity.Property(e => e.BillCode).HasMaxLength(50);
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
