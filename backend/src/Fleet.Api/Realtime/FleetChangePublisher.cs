using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Fleet.Api.Vehicles;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Realtime;

/// <summary>
/// Sends VehicleUpdated (+ ActivityRaised per event) for one vehicle. Call it only after the commit.
/// Shared by ingestion and offline detection so both send the same payloads.
/// </summary>
public class FleetChangePublisher(
    FleetDbContext db,
    IFleetBroadcaster broadcaster,
    ILogger<FleetChangePublisher> logger)
{
    public async Task PublishAsync(Guid vehicleId, IReadOnlyList<ActivityEvent> events, CancellationToken cancellationToken)
    {
        try
        {
            // Re-read with the same projection as the REST API, so a pushed VehicleDto always equals what GET returns.
            var vehicle = await db.Vehicles
                .AsNoTracking()
                .Where(v => v.Id == vehicleId)
                .Select(VehicleProjections.ToDto)
                .SingleAsync(cancellationToken);

            await broadcaster.VehicleUpdatedAsync(vehicle, cancellationToken);
            foreach (var e in events)
            {
                await broadcaster.ActivityRaisedAsync(
                    vehicle.FleetId, new ActivityEventDto(e.Id, e.VehicleId, e.Type, e.OccurredAt, e.Details), cancellationToken);
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // The data is already committed. Real-time is best effort: clients re-fetch the snapshot on reconnect.
            logger.LogError(ex, "Broadcasting changes for vehicle {VehicleId} failed", vehicleId);
        }
    }
}
