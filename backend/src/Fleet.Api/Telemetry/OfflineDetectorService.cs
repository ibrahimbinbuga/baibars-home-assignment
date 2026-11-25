using Microsoft.Extensions.Options;

namespace Fleet.Api.Telemetry;

/// <summary>Runs <see cref="OfflineDetector.DetectOnceAsync"/> on a timer. All logic lives in OfflineDetector.</summary>
public class OfflineDetectorService(
    IServiceScopeFactory scopeFactory,
    TimeProvider timeProvider,
    IOptions<TelemetryOptions> options,
    ILogger<OfflineDetectorService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // PeriodicTimer with TimeProvider, so time can be faked in tests.
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(options.Value.OfflineCheckIntervalSeconds), timeProvider);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                // New scope per pass: a fresh DbContext, like a request.
                await using var scope = scopeFactory.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<OfflineDetector>().DetectOnceAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // Keep the loop alive (e.g. database briefly unavailable); the next tick tries again.
                logger.LogError(ex, "Offline detection pass failed");
            }
        }
    }
}
