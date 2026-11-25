using Fleet.Api.Vehicles;
using Microsoft.AspNetCore.SignalR;

namespace Fleet.Api.Realtime;

/// <summary>Sends each change only to the group of the vehicle's fleet, so it never reaches users of other fleets.</summary>
public class SignalRFleetBroadcaster(IHubContext<FleetHub, IFleetClient> hub) : IFleetBroadcaster
{
    // Typed hub client methods can't take a CancellationToken; sends to a group are fire-and-forget per connection.
    public Task VehicleUpdatedAsync(VehicleDto vehicle, CancellationToken cancellationToken) =>
        hub.Clients.Group(FleetHub.GroupName(vehicle.FleetId)).VehicleUpdated(vehicle);

    public Task ActivityRaisedAsync(Guid fleetId, ActivityEventDto activityEvent, CancellationToken cancellationToken) =>
        hub.Clients.Group(FleetHub.GroupName(fleetId)).ActivityRaised(activityEvent);
}
