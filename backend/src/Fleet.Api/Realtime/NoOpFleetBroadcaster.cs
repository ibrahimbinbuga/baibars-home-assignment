using Fleet.Api.Vehicles;

namespace Fleet.Api.Realtime;

// Placeholder until the SignalR hub exists (Phase 4).
public class NoOpFleetBroadcaster : IFleetBroadcaster
{
    public Task VehicleUpdatedAsync(VehicleDto vehicle, CancellationToken cancellationToken) => Task.CompletedTask;

    public Task ActivityRaisedAsync(ActivityEventDto activityEvent, CancellationToken cancellationToken) =>
        Task.CompletedTask;
}
