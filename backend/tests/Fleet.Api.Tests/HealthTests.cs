using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Fleet.Api.Tests;

// Phase 0 smoke test: the app starts and the liveness endpoint answers without authentication.
// The shared Postgres (Testcontainers) fixture is introduced in Phase 1, when the app first needs a database.
public class HealthTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Health_ReturnsHealthy()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }
}
