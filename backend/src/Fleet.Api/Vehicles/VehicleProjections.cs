using System.Linq.Expressions;
using Fleet.Api.Data.Entities;

namespace Fleet.Api.Vehicles;

public static class VehicleProjections
{
    /// <summary>
    /// Entity → DTO, translated to SQL by EF Core (fleetName becomes a join, no Include needed).
    /// This is the only place the user-facing status is derived. The ?status= filter is applied to the result
    /// of this projection, so the list and the filter can never disagree.
    /// </summary>
    public static readonly Expression<Func<Vehicle, VehicleDto>> ToDto = v => new VehicleDto
    {
        Id = v.Id,
        FleetId = v.FleetId,
        FleetName = v.Fleet!.Name,
        Name = v.Name,
        Model = v.Model,
        SerialNumber = v.SerialNumber,
        Status = v.Connectivity == Connectivity.Offline || v.LastReportedState == null ? VehicleStatus.Offline
            : v.LastReportedState == VehicleState.Moving ? VehicleStatus.Moving
            : v.LastReportedState == VehicleState.Idle ? VehicleStatus.Idle
            : v.LastReportedState == VehicleState.Charging ? VehicleStatus.Charging
            : VehicleStatus.Fault,
        Connectivity = v.Connectivity,
        Latitude = v.LastLatitude,
        Longitude = v.LastLongitude,
        SpeedKmh = v.LastSpeedKmh,
        HeadingDeg = v.LastHeadingDeg,
        BatteryPct = v.LastBatteryPct,
        LastTelemetryAt = v.LastTelemetryAt,
        LastSeenAt = v.LastSeenAt,
        UpdatedAt = v.UpdatedAt,
    };
}
