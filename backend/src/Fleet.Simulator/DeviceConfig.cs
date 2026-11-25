namespace Fleet.Simulator;

/// <summary>One entry of config/devices.json (the same file the API seeder reads).</summary>
public record DeviceConfig(string SerialNumber, string Name, string DeviceKey, double StartLatitude, double StartLongitude);

public record DevicesFile(List<DeviceConfig> Vehicles);

public enum SimulatedState
{
    Moving,
    Idle,
    Charging,
    Fault,
}

/// <summary>The ingest request body (see docs/API.md).</summary>
public record TelemetryPayload(
    long Sequence,
    DateTimeOffset RecordedAt,
    double Latitude,
    double Longitude,
    double SpeedKmh,
    double HeadingDeg,
    double BatteryPct,
    SimulatedState State);
