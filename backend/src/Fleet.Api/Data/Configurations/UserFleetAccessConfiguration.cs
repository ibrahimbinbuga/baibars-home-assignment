using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Fleet.Api.Data.Configurations;

public class UserFleetAccessConfiguration : IEntityTypeConfiguration<UserFleetAccess>
{
    public void Configure(EntityTypeBuilder<UserFleetAccess> builder)
    {
        builder.ToTable("UserFleetAccess");
        builder.HasKey(a => new { a.UserId, a.FleetId });

        builder.HasOne(a => a.User)
            .WithMany(u => u.FleetAccess)
            .HasForeignKey(a => a.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(a => a.Fleet)
            .WithMany()
            .HasForeignKey(a => a.FleetId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
