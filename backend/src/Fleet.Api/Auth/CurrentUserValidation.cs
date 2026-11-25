using System.Security.Claims;
using Fleet.Api.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Fleet.Api.Auth;

/// <summary>
/// Runs after a JWT's signature and lifetime are valid, on every authenticated request and hub connection.
/// A token alone isn't enough: the user must still exist, and their role is taken from the database, not the token.
/// So deleting a user or changing their role takes effect on the next request, not after the token expires.
/// Cost: one primary-key lookup per request / hub connection.
/// </summary>
public static class CurrentUserValidation
{
    public static async Task OnTokenValidatedAsync(TokenValidatedContext context)
    {
        var identity = context.Principal?.Identity as ClaimsIdentity;
        var subject = identity?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
        if (identity is null || !Guid.TryParse(subject, out var userId))
        {
            context.Fail("Token has no valid subject.");
            return;
        }

        var db = context.HttpContext.RequestServices.GetRequiredService<FleetDbContext>();
        var role = await db.Users
            .AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => (Data.Entities.Role?)u.Role)
            .SingleOrDefaultAsync(context.HttpContext.RequestAborted);

        if (role is null)
        {
            // Deleted user (or a token from another database with the same signing key): not authenticated → 401.
            context.Fail("User no longer exists.");
            return;
        }

        // The current role from the database replaces whatever role the token was issued with.
        foreach (var claim in identity.FindAll(AuthClaims.Role).ToList())
        {
            identity.RemoveClaim(claim);
        }

        identity.AddClaim(new Claim(AuthClaims.Role, role.Value.ToString()));
    }
}
