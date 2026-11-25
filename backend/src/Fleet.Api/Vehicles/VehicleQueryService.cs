using System.Security.Claims;
using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Vehicles;

/// <summary>
/// Read side for fleets and vehicles. Every vehicle query starts from <see cref="ScopedVehiclesAsync"/>,
/// so access control lives in IVehicleAccessService and nowhere else.
/// Methods return null when the vehicle doesn't exist *or* is outside the user's scope; the controller turns both
/// into the same 404, so a user can't tell whether a vehicle they may not see exists (assumption A10).
/// </summary>
public class VehicleQueryService(FleetDbContext db, IVehicleAccessService accessService)
{
    public async Task<IReadOnlyList<FleetDto>> ListFleetsAsync(ClaimsPrincipal user, CancellationToken cancellationToken)
    {
        var fleetIds = await accessService.GetAccessibleFleetIdsAsync(user, cancellationToken);
        return await db.Fleets
            .AsNoTracking()
            .Where(f => fleetIds.Contains(f.Id))
            .OrderBy(f => f.Name)
            .Select(f => new FleetDto(f.Id, f.Name, f.Region))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<VehicleDto>> ListVehiclesAsync(
        ClaimsPrincipal user, Guid? fleetId, VehicleStatus? status, CancellationToken cancellationToken)
    {
        var vehicles = await ScopedVehiclesAsync(user, cancellationToken);

        // Applied after scoping, so a fleetId outside the user's scope simply returns an empty list.
        if (fleetId is not null)
        {
            vehicles = vehicles.Where(v => v.FleetId == fleetId);
        }

        var dtos = vehicles.Select(VehicleProjections.ToDto);
        if (status is not null)
        {
            dtos = dtos.Where(d => d.Status == status);
        }

        return await dtos.OrderBy(d => d.FleetName).ThenBy(d => d.Name).ToListAsync(cancellationToken);
    }

    public async Task<VehicleDto?> GetVehicleAsync(ClaimsPrincipal user, Guid vehicleId, CancellationToken cancellationToken)
    {
        var vehicles = await ScopedVehiclesAsync(user, cancellationToken);
        return await vehicles
            .Where(v => v.Id == vehicleId)
            .Select(VehicleProjections.ToDto)
            .SingleOrDefaultAsync(cancellationToken);
    }

    /// <param name="from">UTC, inclusive.</param>
    /// <param name="to">UTC, inclusive.</param>
    public async Task<TelemetryResponse?> GetTelemetryAsync(
        ClaimsPrincipal user, Guid vehicleId, DateTimeOffset from, DateTimeOffset to, int limit,
        CancellationToken cancellationToken)
    {
        if (!await IsInScopeAsync(user, vehicleId, cancellationToken))
        {
            return null;
        }

        var items = await db.TelemetryRecords
            .AsNoTracking()
            .Where(t => t.VehicleId == vehicleId && t.RecordedAt >= from && t.RecordedAt <= to)
            .OrderByDescending(t => t.RecordedAt)
            .ThenByDescending(t => t.Id)
            .Take(limit)
            .Select(t => new TelemetryPointDto(
                t.Sequence, t.RecordedAt, t.ReceivedAt, t.Latitude, t.Longitude,
                t.SpeedKmh, t.HeadingDeg, t.BatteryPct, t.ReportedState))
            .ToListAsync(cancellationToken);

        return new TelemetryResponse(from, to, items);
    }

    public async Task<ActivityPageResponse?> GetActivityAsync(
        ClaimsPrincipal user, Guid vehicleId, ActivityCursor? before, int limit, CancellationToken cancellationToken)
    {
        if (!await IsInScopeAsync(user, vehicleId, cancellationToken))
        {
            return null;
        }

        var query = db.ActivityEvents.AsNoTracking().Where(e => e.VehicleId == vehicleId);
        if (before is { } cursor)
        {
            // Keyset pagination: strictly "older than the cursor" in (OccurredAt desc, Id desc) order.
            query = query.Where(e =>
                e.OccurredAt < cursor.OccurredAt || (e.OccurredAt == cursor.OccurredAt && e.Id < cursor.Id));
        }

        // Fetch one extra row only to know whether another page exists.
        var rows = await query
            .OrderByDescending(e => e.OccurredAt)
            .ThenByDescending(e => e.Id)
            .Take(limit + 1)
            .Select(e => new ActivityEventDto(e.Id, e.VehicleId, e.Type, e.OccurredAt, e.Details))
            .ToListAsync(cancellationToken);

        var items = rows.Take(limit).ToList();
        var nextBefore = rows.Count > limit
            ? new ActivityCursor(items[^1].OccurredAt, items[^1].Id).Encode()
            : null;

        return new ActivityPageResponse(items, nextBefore);
    }

    private async Task<IQueryable<Vehicle>> ScopedVehiclesAsync(ClaimsPrincipal user, CancellationToken cancellationToken)
    {
        var fleetIds = await accessService.GetAccessibleFleetIdsAsync(user, cancellationToken);
        return accessService.ScopeVehicles(db.Vehicles.AsNoTracking(), fleetIds);
    }

    private async Task<bool> IsInScopeAsync(ClaimsPrincipal user, Guid vehicleId, CancellationToken cancellationToken)
    {
        var vehicles = await ScopedVehiclesAsync(user, cancellationToken);
        return await vehicles.AnyAsync(v => v.Id == vehicleId, cancellationToken);
    }
}
