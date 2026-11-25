namespace Fleet.Api.Vehicles;

/// <summary>Defaults and bounds for the history endpoints (documented in docs/API.md).</summary>
public static class HistoryLimits
{
    public static readonly TimeSpan TelemetryDefaultWindow = TimeSpan.FromHours(1);

    // Caps one request's cost; a client that needs more asks for several windows.
    public static readonly TimeSpan TelemetryMaxWindow = TimeSpan.FromDays(7);
    public const int TelemetryDefaultLimit = 500;
    public const int TelemetryMaxLimit = 2000;

    public const int ActivityDefaultLimit = 50;
    public const int ActivityMaxLimit = 200;
}
