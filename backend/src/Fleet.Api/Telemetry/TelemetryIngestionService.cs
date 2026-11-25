using Fleet.Api.Data;
using Fleet.Api.Data.Entities;
using Fleet.Api.Realtime;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Telemetry;

public enum IngestResult
{
    Accepted,
    Duplicate,

    /// <summary>The vehicle row kept changing underneath us (concurrency conflict twice). The device should retry.</summary>
    Busy,
}

/// <summary>Stores one telemetry sample and updates the vehicle's latest state (CLAUDE.md Section 9).</summary>
public class TelemetryIngestionService(
    FleetDbContext db,
    FleetChangePublisher publisher,
    TimeProvider timeProvider,
    IOptions<TelemetryOptions> options,
    ILogger<TelemetryIngestionService> logger)
{
    // First attempt + one retry after a concurrency conflict on the vehicle row.
    private const int MaxAttempts = 2;

    public async Task<IngestResult> IngestAsync(Guid vehicleId, TelemetrySample sample, CancellationToken cancellationToken)
    {
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                var events = await TryIngestOnceAsync(vehicleId, sample, cancellationToken);
                if (events is null)
                {
                    logger.LogDebug("Duplicate sample {Sequence} for vehicle {VehicleId} ignored", sample.Sequence, vehicleId);
                    return IngestResult.Duplicate;
                }

                // Only after the commit, so clients never see data that could still be rolled back.
                await publisher.PublishAsync(vehicleId, events, cancellationToken);
                return IngestResult.Accepted;
            }
            catch (DbUpdateConcurrencyException)
            {
                // The transaction was rolled back (insert included). Forget tracked entities so the next attempt
                // reloads the vehicle with its current values and xmin.
                db.ChangeTracker.Clear();
                if (attempt >= MaxAttempts)
                {
                    logger.LogWarning(
                        "Concurrency conflict on vehicle {VehicleId} persisted after {Attempts} attempts; sample {Sequence} rejected with 503",
                        vehicleId, attempt, sample.Sequence);
                    return IngestResult.Busy;
                }

                logger.LogDebug("Concurrency conflict on vehicle {VehicleId}; retrying sample {Sequence}", vehicleId, sample.Sequence);
            }
        }
    }

    /// <returns>The activity events created, or null if the sample was a duplicate (nothing written).</returns>
    private async Task<List<ActivityEvent>?> TryIngestOnceAsync(
        Guid vehicleId, TelemetrySample sample, CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // 1. Store history. ON CONFLICT DO NOTHING makes a repeated (vehicle, sequence) a no-op instead of an error,
        //    so a duplicate needs no exception handling and leaves the transaction usable. See DECISIONS.md.
        var inserted = await db.Database.ExecuteSqlAsync($"""
            INSERT INTO "TelemetryRecords"
                ("VehicleId", "Sequence", "RecordedAt", "ReceivedAt", "Latitude", "Longitude",
                 "SpeedKmh", "HeadingDeg", "BatteryPct", "ReportedState")
            VALUES
                ({vehicleId}, {sample.Sequence}, {sample.RecordedAt}, {now}, {sample.Latitude}, {sample.Longitude},
                 {sample.SpeedKmh}, {sample.HeadingDeg}, {sample.BatteryPct}, {sample.State.ToString()})
            ON CONFLICT ("VehicleId", "Sequence") DO NOTHING
            """, cancellationToken);

        if (inserted == 0)
        {
            return null; // disposing the transaction rolls back (nothing was written anyway)
        }

        var vehicle = await db.Vehicles.SingleAsync(v => v.Id == vehicleId, cancellationToken);
        var events = new List<ActivityEvent>();

        // 2. Any accepted sample proves the vehicle is alive, even a late one.
        vehicle.LastSeenAt = now;
        if (vehicle.Connectivity == Connectivity.Offline)
        {
            vehicle.Connectivity = Connectivity.Online;
            events.Add(NewEvent(vehicle, ActivityEventType.CameOnline, "Vehicle came online", now));
        }

        // 3. Only a newer sample may replace the latest state; late samples stay in history only.
        if (vehicle.LastTelemetryAt is null || sample.RecordedAt > vehicle.LastTelemetryAt)
        {
            var previousState = vehicle.LastReportedState;
            var previousBattery = vehicle.LastBatteryPct;
            ApplyLatestState(vehicle, sample);

            // 4. Events, only when the latest state changed.
            if (previousState is not null && previousState != sample.State)
            {
                events.Add(NewEvent(vehicle, ActivityEventType.StateChanged, $"{previousState} → {sample.State}", now));
            }

            // On entering Fault only, so a fault lasting many samples raises one event.
            if (sample.State == VehicleState.Fault && previousState != VehicleState.Fault)
            {
                events.Add(NewEvent(vehicle, ActivityEventType.FaultRaised, "Vehicle reported a fault", now));
            }

            // On crossing the threshold only. It fires again after the battery recovers above it and drops again.
            var threshold = options.Value.LowBatteryThresholdPct;
            if (sample.BatteryPct < threshold && (previousBattery is null || previousBattery >= threshold))
            {
                events.Add(NewEvent(vehicle, ActivityEventType.LowBattery, $"Battery at {sample.BatteryPct:0}%", now));
            }
        }

        db.ActivityEvents.AddRange(events);

        // The UPDATE checks xmin: if anything changed the vehicle row since we read it, this throws
        // DbUpdateConcurrencyException and IngestAsync retries.
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        db.ChangeTracker.Clear();

        logger.LogDebug("Stored sample {Sequence} for vehicle {VehicleName}", sample.Sequence, vehicle.Name);
        foreach (var e in events)
        {
            logger.LogInformation("Vehicle {VehicleName}: {EventType} ({Details})", vehicle.Name, e.Type, e.Details);
        }

        return events;
    }

    private static void ApplyLatestState(Vehicle vehicle, TelemetrySample sample)
    {
        vehicle.LastLatitude = sample.Latitude;
        vehicle.LastLongitude = sample.Longitude;
        vehicle.LastSpeedKmh = sample.SpeedKmh;
        vehicle.LastHeadingDeg = sample.HeadingDeg;
        vehicle.LastBatteryPct = sample.BatteryPct;
        vehicle.LastReportedState = sample.State;
        vehicle.LastTelemetryAt = sample.RecordedAt;
        vehicle.LastSequence = sample.Sequence;
    }

    // Server time for every event: device clocks drift, one clock keeps the activity order consistent.
    private static ActivityEvent NewEvent(Vehicle vehicle, ActivityEventType type, string details, DateTimeOffset now) =>
        new() { VehicleId = vehicle.Id, Type = type, OccurredAt = now, Details = details };
}
