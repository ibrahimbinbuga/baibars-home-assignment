using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Fleet.Api.Realtime;
using Fleet.Api.Telemetry;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;

namespace Fleet.Api.Tests;

/// <summary>
/// Calls OfflineDetector directly with a FakeTimeProvider; the background loop is disabled in tests.
/// Samples go through the real ingest endpoint (real clock), then fake time starts from the stored LastSeenAt.
/// </summary>
[Collection(ApiCollection.Name)]
public class OfflineDetectorTests(FleetApiFactory factory)
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Vehicle_GoesOfflineAfterThreshold_AndComesBackOnNextSample()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        await _client.PostTelemetryAsync(key, new SampleBody(1, DateTimeOffset.UtcNow));
        var time = new FakeTimeProvider(await LastSeenAtAsync(vehicleId));

        time.Advance(TimeSpan.FromSeconds(29));
        await DetectOnceAsync(time);
        Assert.Equal(Connectivity.Online, await ConnectivityAsync(vehicleId));

        time.Advance(TimeSpan.FromSeconds(2)); // 31 s since last seen
        await DetectOnceAsync(time);
        Assert.Equal(Connectivity.Offline, await ConnectivityAsync(vehicleId));
        Assert.Equal(ActivityEventType.WentOffline, (await LastEventAsync(vehicleId)).Type);

        var broadcasts = factory.Broadcasts().For(vehicleId).TakeLast(2).ToList();
        Assert.Equal(VehicleStatus.Offline, Assert.IsType<VehicleDto>(broadcasts[0].Payload).Status);
        Assert.Equal(ActivityEventType.WentOffline, Assert.IsType<ActivityEventDto>(broadcasts[1].Payload).Type);
        Assert.All(broadcasts, b => Assert.True(b.CommittedWhenSent));

        await _client.PostTelemetryAsync(key, new SampleBody(2, DateTimeOffset.UtcNow));
        Assert.Equal(Connectivity.Online, await ConnectivityAsync(vehicleId));
        Assert.Equal(ActivityEventType.CameOnline, (await LastEventAsync(vehicleId)).Type);
    }

    [Fact]
    public async Task AlreadyOfflineVehicle_IsNotMarkedAgain()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        await _client.PostTelemetryAsync(key, new SampleBody(1, DateTimeOffset.UtcNow));
        var time = new FakeTimeProvider(await LastSeenAtAsync(vehicleId));
        time.Advance(TimeSpan.FromSeconds(31));

        await DetectOnceAsync(time);
        await DetectOnceAsync(time);

        Assert.Equal(1, await factory.WithDbAsync(db =>
            db.ActivityEvents.CountAsync(e => e.VehicleId == vehicleId && e.Type == ActivityEventType.WentOffline)));
    }

    [Fact]
    public async Task SampleArrivingBetweenReadAndWrite_PreventsOffline()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        await _client.PostTelemetryAsync(key, new SampleBody(1, DateTimeOffset.UtcNow));
        var time = new FakeTimeProvider(await LastSeenAtAsync(vehicleId));
        time.Advance(TimeSpan.FromSeconds(31));

        using var scope = factory.Services.CreateScope();
        var detector = CreateDetector(scope, time);

        // 1. The detector reads the vehicle as stale...
        var stale = Assert.Single(await detector.FindStaleVehiclesAsync(CancellationToken.None), v => v.Id == vehicleId);
        var broadcastsBefore = factory.Broadcasts().For(vehicleId).Count;

        // 2. ...a sample arrives through the real ingest endpoint (updates LastSeenAt, so xmin changes)...
        await _client.PostTelemetryAsync(key, new SampleBody(2, DateTimeOffset.UtcNow));
        var broadcastsFromIngest = factory.Broadcasts().For(vehicleId).Count - broadcastsBefore;

        // 3. ...so writing Offline from the stale snapshot must be skipped.
        var marked = await detector.TryMarkOfflineAsync(stale, CancellationToken.None);

        Assert.False(marked);
        Assert.Equal(Connectivity.Online, await ConnectivityAsync(vehicleId));
        Assert.DoesNotContain(ActivityEventType.WentOffline, await factory.WithDbAsync(db =>
            db.ActivityEvents.Where(e => e.VehicleId == vehicleId).Select(e => e.Type).ToListAsync()));
        Assert.Equal(broadcastsBefore + broadcastsFromIngest, factory.Broadcasts().For(vehicleId).Count);
    }

    private async Task DetectOnceAsync(FakeTimeProvider time)
    {
        using var scope = factory.Services.CreateScope();
        await CreateDetector(scope, time).DetectOnceAsync(CancellationToken.None);
    }

    // Built by hand so it uses the fake clock; everything else comes from the app's container.
    private static OfflineDetector CreateDetector(IServiceScope scope, TimeProvider time) => new(
        scope.ServiceProvider.GetRequiredService<FleetDbContext>(),
        scope.ServiceProvider.GetRequiredService<FleetChangePublisher>(),
        time,
        Options.Create(new TelemetryOptions { OfflineThresholdSeconds = 30 }),
        NullLogger<OfflineDetector>.Instance);

    private Task<DateTimeOffset> LastSeenAtAsync(Guid vehicleId) =>
        factory.WithDbAsync(db => db.Vehicles.Where(v => v.Id == vehicleId).Select(v => v.LastSeenAt!.Value).SingleAsync());

    private Task<Connectivity> ConnectivityAsync(Guid vehicleId) =>
        factory.WithDbAsync(db => db.Vehicles.Where(v => v.Id == vehicleId).Select(v => v.Connectivity).SingleAsync());

    // By Id (insertion order), not OccurredAt: these tests mix the fake clock (detector) with the real clock (ingest),
    // so OccurredAt order would not reflect what happened last.
    private Task<ActivityEvent> LastEventAsync(Guid vehicleId) =>
        factory.WithDbAsync(db => db.ActivityEvents.Where(e => e.VehicleId == vehicleId)
            .OrderByDescending(e => e.Id).FirstAsync());
}
