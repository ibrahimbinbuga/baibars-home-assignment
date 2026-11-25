using System.Security.Claims;
using Fleet.Api.Data;
using Fleet.Api.Vehicles;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Auth;

public class AuthService(FleetDbContext db, JwtTokenIssuer tokenIssuer, IVehicleAccessService accessService)
{
    public const int BcryptWorkFactor = 11;

    // Used when the email is unknown, so that case still pays for one BCrypt.Verify.
    // Without it, "unknown email" would answer much faster than "wrong password" and reveal which emails exist.
    // It is a precomputed constant (not hashed at runtime) so that even the first unknown-email login after a
    // restart costs exactly one verify, like a real one. The "$2a$11$" prefix means work factor 11, which must stay
    // equal to BcryptWorkFactor; a test checks this. The plaintext was random and thrown away, so the hash is not
    // a secret (public only so that test can read it).
    public const string DummyPasswordHash = "$2a$11$cf9Yk1kVoASLDdxWOpamFerlaP/CApsSSrMIki0YIgsh96pQ8nVuW";

    public static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    /// <returns>The login response, or null when the email/password pair is not valid.</returns>
    public async Task<LoginResponse?> LoginAsync(string email, string password, CancellationToken cancellationToken)
    {
        var normalizedEmail = NormalizeEmail(email);
        var user = await db.Users
            .AsNoTracking()
            .SingleOrDefaultAsync(u => u.Email == normalizedEmail, cancellationToken);

        var passwordMatches = BCrypt.Net.BCrypt.Verify(password, user?.PasswordHash ?? DummyPasswordHash);
        if (user is null || !passwordMatches)
        {
            return null;
        }

        var (token, expiresAt) = tokenIssuer.Issue(user);
        return new LoginResponse(token, expiresAt, UserDto.From(user));
    }

    /// <returns>The current user with their fleets, or null if the user in the token no longer exists.</returns>
    public async Task<MeResponse?> GetMeAsync(ClaimsPrincipal principal, CancellationToken cancellationToken)
    {
        var userId = principal.GetUserId();
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
        {
            return null;
        }

        var fleetIds = await accessService.GetAccessibleFleetIdsAsync(principal, cancellationToken);
        var fleets = await db.Fleets
            .AsNoTracking()
            .Where(f => fleetIds.Contains(f.Id))
            .OrderBy(f => f.Name)
            .Select(f => new FleetDto(f.Id, f.Name, f.Region))
            .ToListAsync(cancellationToken);

        return new MeResponse(UserDto.From(user), fleets);
    }
}
