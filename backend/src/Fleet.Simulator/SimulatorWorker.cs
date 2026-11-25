using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Fleet.Simulator;

/// <summary>Waits for the API, then runs one independent loop per vehicle in devices.json.</summary>
public class SimulatorWorker(
    TelemetrySender sender,
    IOptions<SimulatorOptions> options,
    ILoggerFactory loggerFactory,
    ILogger<SimulatorWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await sender.WaitForApiAsync(stoppingToken);

        var devices = await ReadDevicesAsync(stoppingToken);
        logger.LogInformation("Simulating {Count} vehicles, one sample every {Interval}s each",
            devices.Count, options.Value.IntervalSeconds);

        var vehicleLogger = loggerFactory.CreateLogger<VehicleSimulator>();
        await Task.WhenAll(devices.Select(device =>
            new VehicleSimulator(device, options.Value, sender, vehicleLogger).RunAsync(stoppingToken)));
    }

    private async Task<IReadOnlyList<DeviceConfig>> ReadDevicesAsync(CancellationToken cancellationToken)
    {
        var path = Path.GetFullPath(options.Value.DevicesFile);
        await using var stream = File.OpenRead(path);
        var file = await JsonSerializer.DeserializeAsync<DevicesFile>(stream, JsonSerializerOptions.Web, cancellationToken);
        return file?.Vehicles ?? throw new InvalidOperationException($"No vehicles found in {path}.");
    }
}
