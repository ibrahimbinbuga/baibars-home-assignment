using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Fleet.Api.Realtime;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Telemetry;

/// <summary>
/// One offline-detection pass (assumption A5). Split into find + mark so the race with ingestion can be tested:
/// a sample may arrive between reading a stale vehicle and writing it Offline.
/// </summary>
public class OfflineDetector(
    FleetDbContext db,
    FleetChangePublisher publisher,
    TimeProvider timeProvider,
    IOptions<TelemetryOptions> options,
    ILogger<OfflineDetector> logger)
{
    /// <returns>How many vehicles were marked Offline.</returns>
    public async Task<int> DetectOnceAsync(CancellationToken cancellationToken)
    {
        var marked = 0;
        foreach (var vehicle in await FindStaleVehiclesAsync(cancellationToken))
        {
            if (await TryMarkOfflineAsync(vehicle, cancellationToken))
            {
                marked++;
            }
        }

        return marked;
    }

    /// <summary>Online vehicles not heard from within the threshold. Untracked snapshots (with their xmin).</summary>
    public async Task<IReadOnlyList<Vehicle>> FindStaleVehiclesAsync(CancellationToken cancellationToken)
    {
        var cutoff = timeProvider.GetUtcNow() - Threshold;
        return await db.Vehicles
            .AsNoTracking()
            .Where(v => v.Connectivity == Connectivity.Online && v.LastSeenAt < cutoff)
            .ToListAsync(cancellationToken);
    }

    /// <summary>
    /// Marks one vehicle Offline, but only if its row is unchanged since <paramref name="snapshot"/> was read.
    /// The UPDATE is guarded by xmin: if a sample arrived in between (new LastSeenAt), the update matches no row and
    /// the vehicle is skipped. It just reported in, so it is not offline.
    /// </summary>
    /// <returns>True if the vehicle was marked Offline.</returns>
    public async Task<bool> TryMarkOfflineAsync(Vehicle snapshot, CancellationToken cancellationToken)
    {
        db.ChangeTracker.Clear();
        db.Vehicles.Attach(snapshot); // tracked as unchanged, with the xmin we read as the expected Version
        snapshot.Connectivity = Connectivity.Offline;
        snapshot.MarkUpdated(timeProvider.GetUtcNow());

        var wentOffline = new ActivityEvent
        {
            VehicleId = snapshot.Id,
            Type = ActivityEventType.WentOffline,
            OccurredAt = timeProvider.GetUtcNow(),
            Details = $"No telemetry for {Threshold.TotalSeconds:0} s",
        };
        db.ActivityEvents.Add(wentOffline);

        try
        {
            // One SaveChanges per vehicle (its own transaction), so a conflict on one doesn't undo the others.
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            logger.LogDebug("Vehicle {VehicleName} reported in during the offline check; not marking it offline", snapshot.Name);
            return false;
        }
        finally
        {
            db.ChangeTracker.Clear();
        }

        logger.LogInformation("Vehicle {VehicleName}: WentOffline (last seen {LastSeenAt:O})", snapshot.Name, snapshot.LastSeenAt);
        await publisher.PublishAsync(snapshot.Id, [wentOffline], cancellationToken);
        return true;
    }

    private TimeSpan Threshold => TimeSpan.FromSeconds(options.Value.OfflineThresholdSeconds);
}
