using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Fleet.Api.Data.Configurations;

public class ActivityEventConfiguration : IEntityTypeConfiguration<ActivityEvent>
{
    public void Configure(EntityTypeBuilder<ActivityEvent> builder)
    {
        builder.ToTable("ActivityEvents");
        builder.HasKey(e => e.Id);
        builder.Property(e => e.Type).HasConversion<string>().HasMaxLength(20);
        builder.Property(e => e.Details).HasMaxLength(200);

        // Serves "events for one vehicle, newest first" with keyset pagination on (OccurredAt, Id).
        // Id is part of the sort (and the cursor) so events with the same timestamp are paged deterministically.
        builder.HasIndex(e => new { e.VehicleId, e.OccurredAt, e.Id }).IsDescending(false, true, true);

        builder.HasOne<Vehicle>()
            .WithMany()
            .HasForeignKey(e => e.VehicleId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
