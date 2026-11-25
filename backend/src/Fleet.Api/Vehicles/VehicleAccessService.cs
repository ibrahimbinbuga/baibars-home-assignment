using System.Security.Claims;
using Fleet.Api.Auth;
using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Vehicles;

public class VehicleAccessService(FleetDbContext db) : IVehicleAccessService
{
    public async Task<IReadOnlyList<Guid>> GetAccessibleFleetIdsAsync(
        ClaimsPrincipal user, CancellationToken cancellationToken)
    {
        // The role claim is the user's current role from the database (set in CurrentUserValidation on every
        // request), so a role change applies on the next request.
        if (user.IsInRole(nameof(Role.Admin)))
        {
            return await db.Fleets.Select(f => f.Id).ToListAsync(cancellationToken);
        }

        var userId = user.GetUserId();
        return await db.UserFleetAccess
            .Where(a => a.UserId == userId)
            .Select(a => a.FleetId)
            .ToListAsync(cancellationToken);
    }

    public IQueryable<Vehicle> ScopeVehicles(IQueryable<Vehicle> query, IReadOnlyList<Guid> fleetIds) =>
        query.Where(v => fleetIds.Contains(v.FleetId));
}
