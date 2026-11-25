using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Fleet.Api.Data.Configurations;

public class VehicleConfiguration : IEntityTypeConfiguration<Vehicle>
{
    public void Configure(EntityTypeBuilder<Vehicle> builder)
    {
        builder.ToTable("Vehicles");
        builder.HasKey(v => v.Id);
        builder.Property(v => v.Name).HasMaxLength(100);
        builder.Property(v => v.Model).HasMaxLength(100);
        builder.Property(v => v.SerialNumber).HasMaxLength(50);
        builder.HasIndex(v => v.SerialNumber).IsUnique();

        // Ingestion finds the vehicle by the hash of the key it sent, so this must be indexed and unique.
        builder.Property(v => v.DeviceKeyHash).HasMaxLength(64);
        builder.HasIndex(v => v.DeviceKeyHash).IsUnique();

        builder.Property(v => v.LastReportedState).HasConversion<string>().HasMaxLength(20);
        builder.Property(v => v.Connectivity).HasConversion<string>().HasMaxLength(20);

        // Npgsql maps a uint row version to Postgres' built-in xmin column, so no extra column is needed.
        builder.Property(v => v.Version).IsRowVersion();

        builder.HasOne(v => v.Fleet)
            .WithMany(f => f.Vehicles)
            .HasForeignKey(v => v.FleetId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
