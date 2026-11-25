using System.Net;
using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Fleet.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace Fleet.Api.Tests;

/// <summary>
/// The xmin retry in ingestion. A conflict is forced by changing the vehicle row on another connection right before
/// EF saves, exactly what a concurrent writer (e.g. the offline detector) would do.
/// </summary>
[Collection(ApiCollection.Name)]
public class IngestionConcurrencyTests(FleetApiFactory factory)
{
    [Fact]
    public async Task OneConflict_IsRetried_AndTheSampleIsStoredOnce()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var interceptor = new ConflictInjector(factory.ConnectionString, vehicleId, conflicts: 1);
        using var app = WithInterceptor(interceptor);

        var response = await app.CreateClient().PostTelemetryAsync(key, new SampleBody(1, DateTimeOffset.UtcNow));

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.Equal(0, interceptor.ConflictsLeft);
        Assert.Equal(1, await factory.WithDbAsync(db => db.TelemetryRecords.CountAsync(t => t.VehicleId == vehicleId)));
        // The retry starts from a reloaded vehicle, so CameOnline is recorded once, not twice.
        Assert.Equal(1, await factory.WithDbAsync(db => db.ActivityEvents.CountAsync(e => e.VehicleId == vehicleId)));
    }

    [Fact]
    public async Task ConflictOnBothAttempts_Returns503_StoresNothing_AndDoesNotBroadcast()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var interceptor = new ConflictInjector(factory.ConnectionString, vehicleId, conflicts: 2);
        using var app = WithInterceptor(interceptor);
        var client = app.CreateClient();

        var response = await client.PostTelemetryAsync(key, new SampleBody(1, DateTimeOffset.UtcNow));

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal(0, await factory.WithDbAsync(db => db.TelemetryRecords.CountAsync(t => t.VehicleId == vehicleId)));
        Assert.Equal(Connectivity.Offline,
            await factory.WithDbAsync(db => db.Vehicles.Where(v => v.Id == vehicleId).Select(v => v.Connectivity).SingleAsync()));
        Assert.Empty(app.Services.GetRequiredService<RecordingFleetBroadcaster>().For(vehicleId));

        // The device retries the same sample (as the simulator does) and it goes through.
        var retry = await client.PostTelemetryAsync(key, new SampleBody(1, DateTimeOffset.UtcNow));
        Assert.Equal(HttpStatusCode.Accepted, retry.StatusCode);
    }

    private WebApplicationFactory<Program> WithInterceptor(ConflictInjector interceptor) =>
        factory.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
            services.ConfigureDbContext<FleetDbContext>(options => options.AddInterceptors(interceptor))));

    private sealed class ConflictInjector(string connectionString, Guid vehicleId, int conflicts) : SaveChangesInterceptor
    {
        public int ConflictsLeft { get; private set; } = conflicts;

        public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            var updatesVehicle = eventData.Context!.ChangeTracker.Entries<Vehicle>()
                .Any(e => e.State == EntityState.Modified && e.Entity.Id == vehicleId);

            if (updatesVehicle && ConflictsLeft > 0)
            {
                ConflictsLeft--;
                // A no-op update still creates a new row version (new xmin), so EF's
                // "UPDATE ... WHERE xmin = <value we read>" will match no row.
                await using var connection = new NpgsqlConnection(connectionString);
                await connection.OpenAsync(cancellationToken);
                await using var command = new NpgsqlCommand("""UPDATE "Vehicles" SET "Name" = "Name" WHERE "Id" = @id""", connection);
                command.Parameters.AddWithValue("id", vehicleId);
                await command.ExecuteNonQueryAsync(cancellationToken);
            }

            return result;
        }
    }
}
