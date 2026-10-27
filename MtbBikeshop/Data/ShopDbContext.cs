using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Models;

namespace MtbBikeshop.Data;

public class ShopDbContext(DbContextOptions<ShopDbContext> options) : DbContext(options)
{
    public DbSet<Bike> Bikes => Set<Bike>();
    public DbSet<BikePart> BikeParts => Set<BikePart>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Bike>().Property(b => b.Price).HasPrecision(10, 2);
        modelBuilder.Entity<Order>().Property(o => o.Total).HasPrecision(10, 2);
        modelBuilder.Entity<OrderItem>().Property(i => i.UnitPrice).HasPrecision(10, 2);

        modelBuilder.Entity<Bike>().HasIndex(b => b.Rank).IsUnique();

        modelBuilder.Entity<BikePart>()
            .HasOne(p => p.Bike)
            .WithMany(b => b.Parts)
            .HasForeignKey(p => p.BikeId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<OrderItem>()
            .HasOne(i => i.Bike)
            .WithMany()
            .HasForeignKey(i => i.BikeId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
