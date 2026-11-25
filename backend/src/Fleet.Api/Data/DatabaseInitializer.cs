using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Data;

/// <summary>
/// Applies migrations and (optionally) seeds the database when the app starts.
/// It is a hosted service so it runs after startup options validation (a bad Jwt key fails first)
/// and before the web server starts accepting requests.
/// </summary>
public class DatabaseInitializer(
    IServiceScopeFactory scopeFactory,
    IOptions<SeedOptions> seedOptions,
    ILogger<DatabaseInitializer> logger) : IHostedService
{
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<FleetDbContext>();

        // TODO(DECISIONS.md): migrating at startup is fine for a single instance. With several instances they would
        // race to apply the same migration; production would run migrations as a separate deploy step instead
        // (e.g. an EF migration bundle in the release pipeline).
        logger.LogInformation("Applying database migrations");
        await db.Database.MigrateAsync(cancellationToken);

        if (seedOptions.Value.Enabled)
        {
            await scope.ServiceProvider.GetRequiredService<DbSeeder>().SeedAsync(cancellationToken);
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
