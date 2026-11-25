using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Testcontainers.PostgreSql;

namespace Fleet.Api.Tests.Infrastructure;

/// <summary>
/// Runs the real API against a real Postgres in a container (no in-memory database).
/// One instance is shared by all test classes in the "api" collection, so the container starts once per test run.
/// </summary>
public class FleetApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string TestSigningKey = "test-signing-key-that-is-at-least-32-bytes-long";

    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:16-alpine").Build();

    public async Task InitializeAsync() => await _postgres.StartAsync();

    public new async Task DisposeAsync()
    {
        await base.DisposeAsync();
        await _postgres.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // "Testing" so no appsettings.Development.json values leak in: every setting the tests rely on is listed here.
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:Fleet"] = _postgres.GetConnectionString(),
            ["Jwt:SigningKey"] = TestSigningKey,
            ["Seed:Enabled"] = "true",
            ["Seed:DevicesFile"] = FindDevicesFile(),
            // High enough that the normal auth tests never hit the login rate limit.
            ["RateLimiting:Login:PermitLimit"] = "1000",
        }));
    }

    /// <summary>Creates a separate app instance (same database) with some settings overridden.</summary>
    public WebApplicationFactory<Program> WithSettings(Dictionary<string, string?> settings) =>
        WithWebHostBuilder(builder =>
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(settings)));

    // The tests use the same config/devices.json as docker-compose, found by walking up from the test output folder.
    private static string FindDevicesFile()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, "config", "devices.json");
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        throw new FileNotFoundException("config/devices.json not found above " + AppContext.BaseDirectory);
    }
}

[CollectionDefinition(Name)]
public class ApiCollection : ICollectionFixture<FleetApiFactory>
{
    public const string Name = "api";
}
