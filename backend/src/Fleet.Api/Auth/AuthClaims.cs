using System.Security.Claims;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Fleet.Api.Auth;

public static class AuthClaims
{
    // Short claim names as they appear in the token. Inbound claim mapping is turned off (MapInboundClaims = false),
    // so these are also the names seen on ClaimsPrincipal, instead of the long Microsoft claim URIs.
    public const string Role = "role";

    public static Guid GetUserId(this ClaimsPrincipal user)
    {
        var value = user.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? throw new InvalidOperationException("The authenticated user has no 'sub' claim.");
        return Guid.Parse(value);
    }
}
