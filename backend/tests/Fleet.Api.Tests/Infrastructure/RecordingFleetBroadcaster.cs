using System.Collections.Concurrent;
using Fleet.Api.Data;
using Fleet.Api.Realtime;
using Fleet.Api.Vehicles;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Fleet.Api.Tests.Infrastructure;

/// <param name="Method">"VehicleUpdated" or "ActivityRaised".</param>
/// <param name="CommittedWhenSent">
/// Whether the broadcast data was already visible to *another* database connection when it was sent.
/// Another connection only sees committed data, so false means the broadcast happened before the commit.
/// </param>
public record BroadcastRecord(string Method, Guid VehicleId, object Payload, bool CommittedWhenSent);

public class RecordingFleetBroadcaster(IServiceScopeFactory scopeFactory) : IFleetBroadcaster
{
    private readonly ConcurrentQueue<BroadcastRecord> _records = new();

    public IReadOnlyList<BroadcastRecord> For(Guid vehicleId) => _records.Where(r => r.VehicleId == vehicleId).ToList();

    public async Task VehicleUpdatedAsync(VehicleDto vehicle, CancellationToken cancellationToken)
    {
        var committed = await IsVisibleAsync(db => db.Vehicles.AnyAsync(v =>
            v.Id == vehicle.Id && v.LastSeenAt == vehicle.LastSeenAt && v.Connectivity == vehicle.Connectivity));
        _records.Enqueue(new BroadcastRecord("VehicleUpdated", vehicle.Id, vehicle, committed));
    }

    public async Task ActivityRaisedAsync(ActivityEventDto activityEvent, CancellationToken cancellationToken)
    {
        var committed = await IsVisibleAsync(db => db.ActivityEvents.AnyAsync(e => e.Id == activityEvent.Id));
        _records.Enqueue(new BroadcastRecord("ActivityRaised", activityEvent.VehicleId, activityEvent, committed));
    }

    // A new scope = a new DbContext = a different pooled connection from the one doing the ingestion.
    private async Task<bool> IsVisibleAsync(Func<FleetDbContext, Task<bool>> query)
    {
        using var scope = scopeFactory.CreateScope();
        return await query(scope.ServiceProvider.GetRequiredService<FleetDbContext>());
    }
}
