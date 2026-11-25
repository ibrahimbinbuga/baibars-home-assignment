using System.Net;
using Fleet.Api.Data;
using Fleet.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Tests;

[Collection(ApiCollection.Name)]
public class StartupTests(FleetApiFactory factory)
{
    [Fact]
    public async Task Health_IsAnonymousAndReportsHealthyWithDatabase()
    {
        var response = await factory.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public void Startup_WithShortSigningKey_Fails()
    {
        using var app = factory.WithSettings(new() { ["Jwt:SigningKey"] = "too-short-key" });

        var exception = Record.Exception(() => app.CreateClient());

        var validation = Assert.IsType<OptionsValidationException>(exception);
        Assert.Contains("at least 32 bytes", validation.Message);
    }

    [Fact]
    public async Task Seeder_RunTwice_DoesNotDuplicateData()
    {
        // The app has already seeded once on startup; run the seeder again and compare counts.
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<FleetDbContext>();
        var before = await CountsAsync(db);

        await scope.ServiceProvider.GetRequiredService<DbSeeder>().SeedAsync(CancellationToken.None);

        Assert.Equal(before, await CountsAsync(db));
        // Exact for users (tests never add users); fleets/vehicles may include test-only ones, so check the seeded ones.
        Assert.Equal(3, before.Users);
        Assert.Equal(8, await db.Vehicles.CountAsync(v => TestData.AllSeededSerials.Contains(v.SerialNumber)));
        Assert.Equal(2, await db.Fleets.CountAsync(f => f.Name == TestData.TarsusFleetName || f.Name == TestData.AdanaFleetName));
    }

    private static async Task<(int Users, int Fleets, int Vehicles)> CountsAsync(FleetDbContext db) =>
        (await db.Users.CountAsync(), await db.Fleets.CountAsync(), await db.Vehicles.CountAsync());
}
