using System.Net;
using Fleet.Api.Tests.Infrastructure;

namespace Fleet.Api.Tests;

[Collection(ApiCollection.Name)]
public class LoginRateLimitTests(FleetApiFactory factory)
{
    [Fact]
    public async Task Login_OverTheLimit_Returns429ProblemDetails()
    {
        // A separate app instance with its own (low) limit, so other tests are not affected.
        using var limitedApp = factory.WithSettings(new()
        {
            ["RateLimiting:Login:PermitLimit"] = "2",
            ["RateLimiting:Login:WindowSeconds"] = "60",
        });
        var client = limitedApp.CreateClient();

        // Failed attempts count too: that is what slows down password guessing.
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.LoginAsync(DemoUsers.AdminEmail, "wrong-1")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.LoginAsync(DemoUsers.AdminEmail, "wrong-2")).StatusCode);
        var blocked = await client.LoginAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        Assert.Equal(HttpStatusCode.TooManyRequests, blocked.StatusCode);
        Assert.Equal("application/problem+json", blocked.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task RateLimit_AppliesOnlyToLogin()
    {
        using var limitedApp = factory.WithSettings(new() { ["RateLimiting:Login:PermitLimit"] = "1" });
        var client = limitedApp.CreateClient();

        for (var i = 0; i < 5; i++)
        {
            Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
        }
    }
}
