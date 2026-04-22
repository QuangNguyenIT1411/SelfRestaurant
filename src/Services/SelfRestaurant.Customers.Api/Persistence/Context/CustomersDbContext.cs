using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Customers.Api.Persistence.Entities;

namespace SelfRestaurant.Customers.Api.Persistence;

public sealed class CustomersDbContext : DbContext
{
    public CustomersDbContext(DbContextOptions<CustomersDbContext> options)
        : base(options)
    {
    }

    public DbSet<InboxEvents> InboxEvents => Set<InboxEvents>();
    public DbSet<ReadyDishNotifications> ReadyDishNotifications => Set<ReadyDishNotifications>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
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

        modelBuilder.Entity<ReadyDishNotifications>(entity =>
        {
            entity.HasKey(e => e.ReadyDishNotificationId);
            entity.HasIndex(e => new { e.OrderId, e.OrderItemId, e.EventName }).HasDatabaseName("IX_ReadyDishNotifications_Order_Item_Event");
            entity.Property(e => e.EventName).HasMaxLength(100).IsUnicode(false);
            entity.Property(e => e.DishName).HasMaxLength(200);
            entity.Property(e => e.Message).HasMaxLength(500);
            entity.Property(e => e.Status).HasMaxLength(30).IsUnicode(false).HasDefaultValue("OPEN");
            entity.Property(e => e.CreatedAtUtc).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
            entity.Property(e => e.ResolvedAtUtc).HasColumnType("datetime2");
        });
    }
}
