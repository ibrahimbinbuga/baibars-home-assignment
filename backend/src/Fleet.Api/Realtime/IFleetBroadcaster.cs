using Fleet.Api.Vehicles;

namespace Fleet.Api.Realtime;

/// <summary>
/// Pushes changes to connected clients. Only called after the database transaction has committed.
/// An interface so ingestion and offline detection can be tested without SignalR.
/// </summary>
public interface IFleetBroadcaster
{
    Task VehicleUpdatedAsync(VehicleDto vehicle, CancellationToken cancellationToken);
    /// <param name="fleetId">Fleet of the event's vehicle; decides who receives it.</param>
    Task ActivityRaisedAsync(Guid fleetId, ActivityEventDto activityEvent, CancellationToken cancellationToken);
}
