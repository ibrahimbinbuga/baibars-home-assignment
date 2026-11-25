namespace Fleet.Api.Data.Entities;

public class Vehicle
{
    public Guid Id { get; set; }
    public Guid FleetId { get; set; }
    public required string Name { get; set; }
    public required string Model { get; set; }
    public required string SerialNumber { get; set; }

    /// <summary>SHA-256 of the device key (see DeviceKeyHasher). The plaintext key is never stored.</summary>
    public required string DeviceKeyHash { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    // Latest state, copied from the newest telemetry sample. Kept on the vehicle row (denormalized)
    // so the list and map can be served without scanning telemetry history. All null until the first sample.
    public double? LastLatitude { get; set; }
    public double? LastLongitude { get; set; }
    public double? LastSpeedKmh { get; set; }
    public double? LastHeadingDeg { get; set; }
    public double? LastBatteryPct { get; set; }
    public VehicleState? LastReportedState { get; set; }
    public DateTimeOffset? LastTelemetryAt { get; set; }
    public DateTimeOffset? LastSeenAt { get; set; }
    public long? LastSequence { get; set; }
    public Connectivity Connectivity { get; set; } = Connectivity.Offline;

    /// <summary>Maps to Postgres' xmin system column; used as an optimistic concurrency token.</summary>
    public uint Version { get; set; }

    public VehicleFleet? Fleet { get; set; }
}
