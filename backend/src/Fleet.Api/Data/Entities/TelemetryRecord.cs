namespace Fleet.Api.Data.Entities;

public class TelemetryRecord
{
    public long Id { get; set; }
    public Guid VehicleId { get; set; }
    public long Sequence { get; set; }

    /// <summary>Device clock.</summary>
    public DateTimeOffset RecordedAt { get; set; }

    /// <summary>Server clock.</summary>
    public DateTimeOffset ReceivedAt { get; set; }

    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double SpeedKmh { get; set; }
    public double HeadingDeg { get; set; }
    public double BatteryPct { get; set; }
    public VehicleState ReportedState { get; set; }
}
