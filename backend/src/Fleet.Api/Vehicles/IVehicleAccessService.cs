using System.Security.Claims;

namespace Fleet.Api.Vehicles;

/// <summary>
/// The single place that decides what a user may see (CLAUDE.md Section 6).
/// Every vehicle query and the real-time hub go through this service.
/// </summary>
public interface IVehicleAccessService
{
    /// <summary>Admin: every fleet. Operator: only fleets assigned in UserFleetAccess.</summary>
    Task<IReadOnlyList<Guid>> GetAccessibleFleetIdsAsync(ClaimsPrincipal user, CancellationToken cancellationToken);
}
