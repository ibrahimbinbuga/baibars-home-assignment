using Fleet.Api.Realtime;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Testcontainers.PostgreSql;

namespace Fleet.Api.Tests.Infrastructure;

/// <summary>
/// Runs the real API against a real Postgres in a container (no in-memory database).
/// One instance is shared by all test classes in the "api" collection, so the container starts once per test run.
/// Tests in one collection run one after another, so they can safely change shared rows if they restore them.
///
/// Test data rules (keep count assertions stable):
/// - The seeded data (2 fleets, 8 vehicles, 3 users) is never deleted. Operator tests assert "exactly 4, all own
///   fleet"; admin tests assert "contains all 8 seeded" (not "exactly 8").
/// - History tests write TelemetryRecord/ActivityEvent rows for one seeded vehicle and clear them first (TestData).
/// - Vehicles created by tests go into a separate test-only fleet that no operator is assigned to
///   (TestData.CreateTestVehicleAsync), so operator counts never change. Admin and fleet-list assertions use
///   "contains the seeded ones", never exact totals.
/// </summary>
public class FleetApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string TestSigningKey = "test-signing-key-that-is-at-least-32-bytes-long";

    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:16-alpine").Build();

    /// <summary>For tests that need their own connection to the test database.</summary>
    public string ConnectionString => _postgres.GetConnectionString() + ";GSS Encryption Mode=Disable";

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
            // Same setting as compose: we never use Kerberos, so Npgsql should not try to load libgssapi.
            ["ConnectionStrings:Fleet"] = ConnectionString,
            ["Jwt:SigningKey"] = TestSigningKey,
            ["Seed:Enabled"] = "true",
            ["Seed:DevicesFile"] = DevicesFilePath,
            // High enough that the normal auth tests never hit the login rate limit.
            ["RateLimiting:Login:PermitLimit"] = "1000",
            // The background offline detector would otherwise flip test vehicles Offline at random moments.
            // Tests call OfflineDetector.DetectOnceAsync directly, with a FakeTimeProvider.
            ["Telemetry:OfflineCheckIntervalSeconds"] = "3600",
        }));

        // Records broadcasts (and forwards them to the real SignalR broadcaster) so tests can check what was sent and when.
        builder.ConfigureTestServices(services =>
        {
            services.AddSingleton<RecordingFleetBroadcaster>();
            services.AddSingleton<IFleetBroadcaster>(sp => sp.GetRequiredService<RecordingFleetBroadcaster>());
        });
    }

    /// <summary>Creates a separate app instance (same database) with some settings overridden.</summary>
    public WebApplicationFactory<Program> WithSettings(Dictionary<string, string?> settings) =>
        WithWebHostBuilder(builder =>
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(settings)));

    /// <summary>The same config/devices.json as docker-compose (holds the seeded vehicles' plaintext demo keys).</summary>
    public static string DevicesFilePath { get; } = FindDevicesFile();

    // Found by walking up from the test output folder.
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
