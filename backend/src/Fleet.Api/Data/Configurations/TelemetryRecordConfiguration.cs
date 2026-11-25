using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Fleet.Api.Data.Configurations;

public class TelemetryRecordConfiguration : IEntityTypeConfiguration<TelemetryRecord>
{
    public void Configure(EntityTypeBuilder<TelemetryRecord> builder)
    {
        builder.ToTable("TelemetryRecords");
        builder.HasKey(t => t.Id);
        builder.Property(t => t.ReportedState).HasConversion<string>().HasMaxLength(20);

        // Makes ingestion idempotent: a repeated (vehicle, sequence) is rejected by the database itself.
        builder.HasIndex(t => new { t.VehicleId, t.Sequence }).IsUnique();

        // Serves "history for one vehicle, newest first".
        builder.HasIndex(t => new { t.VehicleId, t.RecordedAt }).IsDescending(false, true);

        builder.HasOne<Vehicle>()
            .WithMany()
            .HasForeignKey(t => t.VehicleId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
