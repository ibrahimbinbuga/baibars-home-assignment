using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Fleet.Api.Data.Configurations;

public class VehicleFleetConfiguration : IEntityTypeConfiguration<VehicleFleet>
{
    public void Configure(EntityTypeBuilder<VehicleFleet> builder)
    {
        builder.ToTable("Fleets");
        builder.HasKey(f => f.Id);
        builder.Property(f => f.Name).HasMaxLength(100);
        builder.HasIndex(f => f.Name).IsUnique();
        builder.Property(f => f.Region).HasMaxLength(100);
    }
}
