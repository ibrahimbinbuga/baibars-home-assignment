using System.Security.Claims;
using System.Text.Encodings.Web;
using Fleet.Api.Data;
using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Telemetry;

/// <summary>
/// Authenticates a vehicle by its X-Device-Key header. Used only by the ingest endpoint; user endpoints use JWT.
/// Keeping the two as separate schemes means a user token can't ingest and a device key can't read user data.
/// </summary>
public class DeviceKeyAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    FleetDbContext db)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "DeviceKey";
    public const string HeaderName = "X-Device-Key";
    public const string VehicleIdClaim = "vehicle_id";

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var deviceKey = Request.Headers[HeaderName].ToString();
        if (string.IsNullOrWhiteSpace(deviceKey))
        {
            return AuthenticateResult.NoResult();
        }

        // Keys are stored as SHA-256 hashes, so the lookup is one query on a unique index.
        var keyHash = DeviceKeyHasher.Hash(deviceKey);
        var vehicleId = await db.Vehicles
            .AsNoTracking()
            .Where(v => v.DeviceKeyHash == keyHash)
            .Select(v => (Guid?)v.Id)
            .SingleOrDefaultAsync(Context.RequestAborted);

        if (vehicleId is null)
        {
            return AuthenticateResult.Fail("Invalid device key.");
        }

        var identity = new ClaimsIdentity([new Claim(VehicleIdClaim, vehicleId.Value.ToString())], SchemeName);
        return AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName));
    }
}
