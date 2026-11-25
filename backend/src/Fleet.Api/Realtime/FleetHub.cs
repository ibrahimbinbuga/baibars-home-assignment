using Fleet.Api.Vehicles;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Fleet.Api.Realtime;

/// <summary>
/// Real-time channel to the mobile app. Server → client only: there are no hub methods a client can call, so a client
/// cannot choose which fleets it hears about. Only user JWTs are accepted (a device key cannot connect).
/// </summary>
[Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
public class FleetHub(IVehicleAccessService accessService, ILogger<FleetHub> logger) : Hub<IFleetClient>
{
    public const string Path = "/hubs/fleet";

    public static string GroupName(Guid fleetId) => $"fleet:{fleetId}";

    /// <summary>
    /// Group membership is decided here, by the server, with the same access rule as the REST API.
    /// A user with no fleets joins no group: they stay connected and simply receive nothing.
    /// Access changes apply on the next connection.
    /// </summary>
    public override async Task OnConnectedAsync()
    {
        var fleetIds = await accessService.GetAccessibleFleetIdsAsync(Context.User!, Context.ConnectionAborted);
        foreach (var fleetId in fleetIds)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(fleetId), Context.ConnectionAborted);
        }

        logger.LogDebug("Connection {ConnectionId} joined {GroupCount} fleet groups", Context.ConnectionId, fleetIds.Count);
        await base.OnConnectedAsync();
    }
}
