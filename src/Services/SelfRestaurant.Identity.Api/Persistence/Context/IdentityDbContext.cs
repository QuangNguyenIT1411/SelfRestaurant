using Microsoft.EntityFrameworkCore;
using SelfRestaurant.Identity.Api.Persistence.Entities;

namespace SelfRestaurant.Identity.Api.Persistence;

public sealed class IdentityDbContext : DbContext
{
    public IdentityDbContext(DbContextOptions<IdentityDbContext> options)
        : base(options)
    {
    }

    public DbSet<CatalogBranchSnapshots> CatalogBranchSnapshots => Set<CatalogBranchSnapshots>();
    public DbSet<CustomerLoyalty> CustomerLoyalty => Set<CustomerLoyalty>();
    public DbSet<Customers> Customers => Set<Customers>();
    public DbSet<EmployeeRoles> EmployeeRoles => Set<EmployeeRoles>();
    public DbSet<Employees> Employees => Set<Employees>();
    public DbSet<PasswordResetTokens> PasswordResetTokens => Set<PasswordResetTokens>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<CatalogBranchSnapshots>(entity =>
        {
            entity.HasKey(e => e.BranchId);
            entity.HasIndex(e => e.IsActive).HasDatabaseName("idx_catalog_branch_snapshots_active");
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.Location).HasMaxLength(500);
            entity.Property(e => e.RefreshedAtUtc).HasColumnType("datetime2");
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
        });

        modelBuilder.Entity<CustomerLoyalty>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("CustomerLoyalty");

            entity.Property(e => e.Email)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.Name).HasMaxLength(100);
            entity.Property(e => e.PhoneNumber)
                .HasMaxLength(20)
                .IsUnicode(false);
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
            entity.HasOne(e => e.Role)
                .WithMany(r => r.Employees)
                .HasForeignKey(e => e.RoleID)
                .OnDelete(DeleteBehavior.ClientSetNull);
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
