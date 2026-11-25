using System.ComponentModel.DataAnnotations;

namespace Fleet.Api.Telemetry;

public class TelemetryOptions
{
    public const string SectionName = "Telemetry";

    /// <summary>A vehicle with no telemetry for this long is marked Offline (assumption A5).</summary>
    [Range(1, 3600)] public int OfflineThresholdSeconds { get; set; } = 30;

    /// <summary>How often the offline detector runs. Worst-case detection time = threshold + interval.</summary>
    [Range(1, 3600)] public int OfflineCheckIntervalSeconds { get; set; } = 5;

    /// <summary>A LowBattery event fires when the battery drops below this value.</summary>
    [Range(0, 100)] public double LowBatteryThresholdPct { get; set; } = 20;

    /// <summary>Samples whose recordedAt is further in the future than this are rejected (device clock guard).</summary>
    [Range(0, 3600)] public int MaxClockSkewSeconds { get; set; } = 300;
}
