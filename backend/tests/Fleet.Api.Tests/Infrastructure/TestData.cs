using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Fleet.Api.Tests.Infrastructure;

/// <summary>Direct database access for arranging test data. See FleetApiFactory for the rules.</summary>
public static class TestData
{
    public static readonly string[] TarsusSerials = ["SN-0001", "SN-0002", "SN-0003", "SN-0004"];
    public static readonly string[] AdanaSerials = ["SN-0005", "SN-0006", "SN-0007", "SN-0008"];
    public static readonly string[] AllSeededSerials = [.. TarsusSerials, .. AdanaSerials];

    public const string TarsusFleetName = "Tarsus Field Ops";
    public const string AdanaFleetName = "Adana Field Ops";

    public static async Task<T> WithDbAsync<T>(this FleetApiFactory factory, Func<FleetDbContext, Task<T>> action)
    {
        using var scope = factory.Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<FleetDbContext>());
    }

    public static Task WithDbAsync(this FleetApiFactory factory, Func<FleetDbContext, Task> action) =>
        factory.WithDbAsync(async db => { await action(db); return true; });

    public static Task<Guid> VehicleIdAsync(this FleetApiFactory factory, string serialNumber) =>
        factory.WithDbAsync(db => db.Vehicles.Where(v => v.SerialNumber == serialNumber).Select(v => v.Id).SingleAsync());

    public static Task<Guid> FleetIdAsync(this FleetApiFactory factory, string name) =>
        factory.WithDbAsync(db => db.Fleets.Where(f => f.Name == name).Select(f => f.Id).SingleAsync());

    /// <summary>Removes telemetry and activity for one vehicle so a history test starts from a known state.</summary>
    public static Task ClearHistoryAsync(this FleetApiFactory factory, Guid vehicleId) =>
        factory.WithDbAsync(async db =>
        {
            await db.TelemetryRecords.Where(t => t.VehicleId == vehicleId).ExecuteDeleteAsync();
            await db.ActivityEvents.Where(e => e.VehicleId == vehicleId).ExecuteDeleteAsync();
        });

    public static TelemetryRecord Telemetry(Guid vehicleId, long sequence, DateTimeOffset recordedAt) => new()
    {
        VehicleId = vehicleId,
        Sequence = sequence,
        RecordedAt = recordedAt,
        ReceivedAt = recordedAt,
        Latitude = 36.92,
        Longitude = 34.89,
        SpeedKmh = 10,
        HeadingDeg = 90,
        BatteryPct = 80,
        ReportedState = VehicleState.Moving,
    };

    public static ActivityEvent Activity(Guid vehicleId, DateTimeOffset occurredAt, string details) => new()
    {
        VehicleId = vehicleId,
        Type = ActivityEventType.StateChanged,
        OccurredAt = occurredAt,
        Details = details,
    };
}
