using Fleet.Api.Auth;

namespace Fleet.Api.Tests;

public class PasswordHashingTests
{
    [Fact]
    public void DummyPasswordHash_UsesSameWorkFactorAsRealHashes()
    {
        // If the work factor changes, the dummy hash must be regenerated, or unknown-email logins become
        // faster/slower than real ones and leak which emails exist.
        var realHash = BCrypt.Net.BCrypt.HashPassword("any-password", AuthService.BcryptWorkFactor);

        Assert.Equal(realHash[..7], AuthService.DummyPasswordHash[..7]); // "$2a$11$": version + work factor
        Assert.Equal(realHash.Length, AuthService.DummyPasswordHash.Length);
    }
}
