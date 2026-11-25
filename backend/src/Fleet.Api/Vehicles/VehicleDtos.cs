using Fleet.Api.Data.Entities;

namespace Fleet.Api.Vehicles;

/// <summary>What users see: the reported state while online, otherwise Offline.</summary>
public enum VehicleStatus
{
    Moving,
    Idle,
    Charging,
    Fault,
    Offline,
}

// Init properties instead of a positional record on purpose: EF Core can translate a Where/OrderBy that runs
// *after* a member-init projection, which lets the ?status= filter reuse the status expression in the projection.
public record VehicleDto
{
    public required Guid Id { get; init; }
    public required Guid FleetId { get; init; }
    public required string FleetName { get; init; }
    public required string Name { get; init; }
    public required string Model { get; init; }
    public required string SerialNumber { get; init; }
    public required VehicleStatus Status { get; init; }
    public required Connectivity Connectivity { get; init; }
    public double? Latitude { get; init; }
    public double? Longitude { get; init; }
    public double? SpeedKmh { get; init; }
    public double? HeadingDeg { get; init; }
    public double? BatteryPct { get; init; }
    public DateTimeOffset? LastTelemetryAt { get; init; }
    public DateTimeOffset? LastSeenAt { get; init; }

    /// <summary>Per-vehicle ordering key: a client keeps the copy with the greatest UpdatedAt.</summary>
    public required DateTimeOffset UpdatedAt { get; init; }
}

public record TelemetryPointDto(
    long Sequence,
    DateTimeOffset RecordedAt,
    DateTimeOffset ReceivedAt,
    double Latitude,
    double Longitude,
    double SpeedKmh,
    double HeadingDeg,
    double BatteryPct,
    VehicleState State);

/// <summary>From/To are the window actually applied, after defaults.</summary>
public record TelemetryResponse(DateTimeOffset From, DateTimeOffset To, IReadOnlyList<TelemetryPointDto> Items);

public record ActivityEventDto(long Id, Guid VehicleId, ActivityEventType Type, DateTimeOffset OccurredAt, string Details);

/// <summary>NextBefore is an opaque cursor for the next (older) page, or null when there are no more events.</summary>
public record ActivityPageResponse(IReadOnlyList<ActivityEventDto> Items, string? NextBefore);
