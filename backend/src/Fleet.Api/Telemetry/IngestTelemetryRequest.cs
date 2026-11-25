using System.ComponentModel.DataAnnotations;
using Fleet.Api.Data.Entities;

namespace Fleet.Api.Telemetry;

/// <summary>
/// One telemetry sample as sent by a vehicle. Every field is nullable + [Required] on purpose: with non-nullable
/// types a missing field would silently become 0 (or Moving) instead of a 400.
/// There is no vehicle id: the device key decides which vehicle is written to.
/// </summary>
public record IngestTelemetryRequest
{
    [Required, Range(0, double.MaxValue)] public long? Sequence { get; init; }
    [Required] public DateTimeOffset? RecordedAt { get; init; }
    [Required, Range(-90.0, 90.0)] public double? Latitude { get; init; }
    [Required, Range(-180.0, 180.0)] public double? Longitude { get; init; }
    [Required, Range(0.0, double.MaxValue)] public double? SpeedKmh { get; init; }
    [Required, Range(0.0, 360.0, MaximumIsExclusive = true)] public double? HeadingDeg { get; init; }
    [Required, Range(0.0, 100.0)] public double? BatteryPct { get; init; }
    [Required] public VehicleState? State { get; init; }

    /// <summary>Only call after model validation passed.</summary>
    public TelemetrySample ToSample() => new(
        Sequence!.Value,
        RecordedAt!.Value.ToUniversalTime(), // Npgsql only accepts UTC for timestamptz
        Latitude!.Value,
        Longitude!.Value,
        SpeedKmh!.Value,
        HeadingDeg!.Value,
        BatteryPct!.Value,
        State!.Value);
}

/// <summary>A validated sample with no nullable fields.</summary>
public record TelemetrySample(
    long Sequence,
    DateTimeOffset RecordedAt,
    double Latitude,
    double Longitude,
    double SpeedKmh,
    double HeadingDeg,
    double BatteryPct,
    VehicleState State);

public record IngestResponse(bool Duplicate);
