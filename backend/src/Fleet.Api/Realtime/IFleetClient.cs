using Fleet.Api.Vehicles;

namespace Fleet.Api.Realtime;

/// <summary>Messages the server sends to connected apps. The method names are the SignalR message names.</summary>
public interface IFleetClient
{
    Task VehicleUpdated(VehicleDto vehicle);
    Task ActivityRaised(ActivityEventDto activityEvent);
}
