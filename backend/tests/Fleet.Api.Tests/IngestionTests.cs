using System.Net;
using System.Net.Http.Json;
using Fleet.Api.Data.Entities;
using Fleet.Api.Telemetry;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Tests;

/// <summary>Ingestion rules (CLAUDE.md Section 9). Every test uses its own vehicle in the test-only fleet.</summary>
[Collection(ApiCollection.Name)]
public class IngestionTests(FleetApiFactory factory)
{
    private readonly HttpClient _client = factory.CreateClient();
    private static DateTimeOffset Now => DateTimeOffset.UtcNow;

    [Fact]
    public async Task MissingDeviceKey_Returns401()
    {
        var response = await _client.PostTelemetryAsync(null, new SampleBody(1, Now));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task WrongDeviceKey_Returns401_AndStoresNothing()
    {
        var response = await _client.PostTelemetryAsync("not-a-real-key", new SampleBody(1, Now));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task UserToken_CannotIngest()
    {
        await _client.AuthenticateAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        var response = await _client.PostTelemetryAsync(null, new SampleBody(1, Now));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DeviceKey_CannotReadUserEndpoints()
    {
        var (_, key) = await factory.CreateTestVehicleAsync();
        var request = new HttpRequestMessage(HttpMethod.Get, "/api/vehicles");
        request.Headers.Add("X-Device-Key", key);

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ValidSample_Returns202_UpdatesLatestState_ComesOnline_AndBroadcastsAfterCommit()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var recordedAt = Now.AddSeconds(-1);

        var response = await _client.PostTelemetryAsync(key, new SampleBody(1, recordedAt, 36.95, 34.91, 12.5, 270, 76, "Moving"));

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.False((await response.Content.ReadFromJsonAsync<IngestResponse>())!.Duplicate);

        var vehicle = await GetVehicleAsAdminAsync(vehicleId);
        Assert.Equal(VehicleStatus.Moving, vehicle.Status);
        Assert.Equal(Connectivity.Online, vehicle.Connectivity);
        Assert.Equal((36.95, 34.91, 12.5, 270, 76), (vehicle.Latitude, vehicle.Longitude, vehicle.SpeedKmh, vehicle.HeadingDeg, vehicle.BatteryPct));
        Assert.NotNull(vehicle.LastSeenAt);
        Assert.Equal(1, await TelemetryCountAsync(vehicleId));
        Assert.Equal([ActivityEventType.CameOnline], await EventTypesAsync(vehicleId));

        var broadcasts = factory.Broadcasts().For(vehicleId);
        Assert.Equal(["VehicleUpdated", "ActivityRaised"], broadcasts.Select(b => b.Method));
        Assert.All(broadcasts, b => Assert.True(b.CommittedWhenSent, $"{b.Method} was sent before the commit."));
        Assert.Equal(VehicleStatus.Moving, ((VehicleDto)broadcasts[0].Payload).Status);
    }

    [Fact]
    public async Task DuplicateSequence_Returns200Duplicate_StoresOnce_AndDoesNotBroadcast()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var sample = new SampleBody(7, Now);
        await _client.PostTelemetryAsync(key, sample);
        var broadcastsAfterFirst = factory.Broadcasts().For(vehicleId).Count;

        var response = await _client.PostTelemetryAsync(key, sample with { BatteryPct = 10 });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True((await response.Content.ReadFromJsonAsync<IngestResponse>())!.Duplicate);
        Assert.Equal(1, await TelemetryCountAsync(vehicleId));
        Assert.Equal(80, (await GetVehicleAsAdminAsync(vehicleId)).BatteryPct);
        Assert.Equal(broadcastsAfterFirst, factory.Broadcasts().For(vehicleId).Count);
    }

    [Fact]
    public async Task EveryAcceptedSample_AdvancesUpdatedAt_ButDuplicateDoesNot()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var t = Now;
        var created = (await GetVehicleAsAdminAsync(vehicleId)).UpdatedAt;

        await _client.PostTelemetryAsync(key, new SampleBody(2, t));
        var afterFirst = (await GetVehicleAsAdminAsync(vehicleId)).UpdatedAt;
        // A late sample doesn't change the latest state, but it is still a write (LastSeenAt), so UpdatedAt moves.
        await _client.PostTelemetryAsync(key, new SampleBody(1, t.AddSeconds(-5)));
        var afterLate = (await GetVehicleAsAdminAsync(vehicleId)).UpdatedAt;
        await _client.PostTelemetryAsync(key, new SampleBody(1, t.AddSeconds(-5)));
        var afterDuplicate = (await GetVehicleAsAdminAsync(vehicleId)).UpdatedAt;

        Assert.True(afterFirst > created);
        Assert.True(afterLate > afterFirst);
        Assert.Equal(afterLate, afterDuplicate);
        var broadcast = factory.Broadcasts().For(vehicleId).Last(b => b.Method == "VehicleUpdated");
        Assert.Equal(afterLate, ((VehicleDto)broadcast.Payload).UpdatedAt);
    }

    [Fact]
    public async Task OutOfOrderSample_IsStoredInHistory_ButDoesNotOverwriteLatestState()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var t = Now;
        await _client.PostTelemetryAsync(key, new SampleBody(2, t, BatteryPct: 70, State: "Idle"));

        var response = await _client.PostTelemetryAsync(key, new SampleBody(1, t.AddSeconds(-10), BatteryPct: 90, State: "Moving"));

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.Equal(2, await TelemetryCountAsync(vehicleId));
        var vehicle = await GetVehicleAsAdminAsync(vehicleId);
        Assert.Equal(70, vehicle.BatteryPct);
        Assert.Equal(VehicleStatus.Idle, vehicle.Status);
        Assert.DoesNotContain(ActivityEventType.StateChanged, await EventTypesAsync(vehicleId));
    }

    [Fact]
    public async Task StateChange_CreatesStateChangedEvent_ButNotOnFirstSample()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var t = Now;

        await _client.PostTelemetryAsync(key, new SampleBody(1, t.AddSeconds(-4), State: "Idle"));
        await _client.PostTelemetryAsync(key, new SampleBody(2, t.AddSeconds(-2), State: "Idle"));
        await _client.PostTelemetryAsync(key, new SampleBody(3, t, State: "Moving"));

        var events = await EventsAsync(vehicleId);
        var stateChanged = Assert.Single(events, e => e.Type == ActivityEventType.StateChanged);
        Assert.Equal("Idle → Moving", stateChanged.Details);
    }

    [Fact]
    public async Task Fault_RaisesFaultRaised_OnlyWhenEnteringFault()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var t = Now.AddSeconds(-20);
        string[] states = ["Moving", "Fault", "Fault", "Fault", "Idle", "Fault"];

        for (var i = 0; i < states.Length; i++)
        {
            await _client.PostTelemetryAsync(key, new SampleBody(i + 1, t.AddSeconds(i), State: states[i]));
        }

        Assert.Equal(2, (await EventTypesAsync(vehicleId)).Count(e => e == ActivityEventType.FaultRaised));
    }

    [Fact]
    public async Task LowBattery_FiresOnceWhenCrossingThreshold_AndAgainAfterRecovery()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();
        var t = Now.AddSeconds(-20);
        double[] battery = [25, 19, 15, 12, 30, 18];

        for (var i = 0; i < battery.Length; i++)
        {
            await _client.PostTelemetryAsync(key, new SampleBody(i + 1, t.AddSeconds(i), BatteryPct: battery[i]));
        }

        var lowBattery = (await EventsAsync(vehicleId)).Where(e => e.Type == ActivityEventType.LowBattery).ToList();
        Assert.Equal(["Battery at 18%", "Battery at 19%"], lowBattery.Select(e => e.Details).Order());
    }

    [Fact]
    public async Task FirstSampleBelowThreshold_FiresLowBattery()
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();

        await _client.PostTelemetryAsync(key, new SampleBody(1, Now, BatteryPct: 10));

        Assert.Contains(ActivityEventType.LowBattery, await EventTypesAsync(vehicleId));
    }

    public static TheoryData<string, object> InvalidBodies()
    {
        var now = DateTimeOffset.UtcNow;
        var valid = new SampleBody(1, now);
        return new TheoryData<string, object>
        {
            { "latitude > 90", valid with { Latitude = 91 } },
            { "longitude < -180", valid with { Longitude = -181 } },
            { "battery > 100", valid with { BatteryPct = 101 } },
            { "negative speed", valid with { SpeedKmh = -1 } },
            { "heading = 360", valid with { HeadingDeg = 360 } },
            { "recordedAt 6 min in future", valid with { RecordedAt = now.AddMinutes(6) } },
            { "unknown state", valid with { State = "Flying" } },
            { "missing state", new { sequence = 1, recordedAt = now, latitude = 36.9, longitude = 34.9, speedKmh = 1, headingDeg = 1, batteryPct = 50 } },
            { "missing latitude", new { sequence = 1, recordedAt = now, longitude = 34.9, speedKmh = 1, headingDeg = 1, batteryPct = 50, state = "Idle" } },
        };
    }

    [Theory]
    [MemberData(nameof(InvalidBodies))]
    public async Task InvalidSample_Returns400_StoresNothing_AndDoesNotBroadcast(string because, object body)
    {
        var (vehicleId, key) = await factory.CreateTestVehicleAsync();

        var response = await _client.PostTelemetryAsync(key, body);

        Assert.True(response.StatusCode == HttpStatusCode.BadRequest, because);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal(0, await TelemetryCountAsync(vehicleId));
        Assert.Empty(factory.Broadcasts().For(vehicleId));
    }

    [Fact]
    public async Task RecordedAtWithinClockSkew_IsAccepted()
    {
        var (_, key) = await factory.CreateTestVehicleAsync();

        var response = await _client.PostTelemetryAsync(key, new SampleBody(1, Now.AddMinutes(4)));

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
    }

    [Fact]
    public async Task VehicleIdInBody_IsIgnored_KeyDecidesTheVehicle()
    {
        var (vehicleA, keyA) = await factory.CreateTestVehicleAsync();
        var (vehicleB, _) = await factory.CreateTestVehicleAsync();

        var body = new { vehicleId = vehicleB, sequence = 1, recordedAt = Now, latitude = 36.9, longitude = 34.9,
            speedKmh = 1, headingDeg = 1, batteryPct = 50, state = "Idle" };
        var response = await _client.PostTelemetryAsync(keyA, body);

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.Equal(1, await TelemetryCountAsync(vehicleA));
        Assert.Equal(0, await TelemetryCountAsync(vehicleB));
    }

    private async Task<VehicleDto> GetVehicleAsAdminAsync(Guid vehicleId)
    {
        var admin = factory.CreateClient();
        await admin.AuthenticateAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);
        return (await admin.GetFromJsonAsync<VehicleDto>($"/api/vehicles/{vehicleId}", HttpClientExtensions.Json))!;
    }

    private Task<int> TelemetryCountAsync(Guid vehicleId) =>
        factory.WithDbAsync(db => db.TelemetryRecords.CountAsync(t => t.VehicleId == vehicleId));

    private Task<List<ActivityEvent>> EventsAsync(Guid vehicleId) =>
        factory.WithDbAsync(db => db.ActivityEvents.Where(e => e.VehicleId == vehicleId).OrderBy(e => e.Id).ToListAsync());

    private async Task<List<ActivityEventType>> EventTypesAsync(Guid vehicleId) =>
        (await EventsAsync(vehicleId)).Select(e => e.Type).ToList();
}
