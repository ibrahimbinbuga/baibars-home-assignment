using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Fleet.Simulator;

/// <summary>Sends samples like a device would: plain HttpClient, simple manual retry with backoff.</summary>
public class TelemetrySender(HttpClient http, ILogger<TelemetrySender> logger)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    private static readonly TimeSpan MaxBackoff = TimeSpan.FromSeconds(10);

    public async Task WaitForApiAsync(CancellationToken cancellationToken)
    {
        logger.LogInformation("Waiting for API at {BaseUrl}", http.BaseAddress);
        while (true)
        {
            try
            {
                using var response = await http.GetAsync("/health", cancellationToken);
                if (response.IsSuccessStatusCode)
                {
                    logger.LogInformation("API is healthy");
                    return;
                }

                logger.LogDebug("Health check returned {StatusCode}", (int)response.StatusCode);
            }
            catch (HttpRequestException ex)
            {
                logger.LogDebug("API not reachable yet: {Message}", ex.Message);
            }

            await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken);
        }
    }

    /// <summary>
    /// Sends one sample. Network errors, 5xx and 429 are retried with the SAME sample (same sequence), so if an
    /// earlier attempt actually reached the API, the retry is answered as a duplicate instead of stored twice.
    /// Other 4xx are not retried: sending the same request again would fail the same way.
    /// </summary>
    public async Task SendAsync(DeviceConfig device, TelemetryPayload payload, CancellationToken cancellationToken)
    {
        var backoff = TimeSpan.FromSeconds(1);
        for (var attempt = 1; ; attempt++)
        {
            string failure;
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, "/api/ingest/telemetry")
                {
                    Content = JsonContent.Create(payload, options: Json),
                };
                request.Headers.Add("X-Device-Key", device.DeviceKey);
                using var response = await http.SendAsync(request, cancellationToken);

                if (response.IsSuccessStatusCode)
                {
                    if (attempt > 1)
                    {
                        logger.LogInformation("{Vehicle}: sample {Sequence} delivered after {Attempts} attempts",
                            device.Name, payload.Sequence, attempt);
                    }
                    else
                    {
                        logger.LogDebug("{Vehicle}: sent sample {Sequence} ({StatusCode})",
                            device.Name, payload.Sequence, (int)response.StatusCode);
                    }

                    return;
                }

                if (!IsRetryable(response.StatusCode))
                {
                    logger.LogError("{Vehicle}: sample {Sequence} rejected with {StatusCode}; dropping it",
                        device.Name, payload.Sequence, (int)response.StatusCode);
                    return;
                }

                failure = $"HTTP {(int)response.StatusCode}";
            }
            catch (HttpRequestException ex)
            {
                failure = ex.Message;
            }
            catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                failure = "request timed out";
            }

            logger.LogWarning("{Vehicle}: sending sample {Sequence} failed ({Failure}); retry {Attempt} in {Delay}s",
                device.Name, payload.Sequence, failure, attempt, backoff.TotalSeconds);
            await Task.Delay(backoff, cancellationToken);
            backoff = TimeSpan.FromTicks(Math.Min(backoff.Ticks * 2, MaxBackoff.Ticks));
        }
    }

    private static bool IsRetryable(HttpStatusCode status) =>
        (int)status >= 500 || status == HttpStatusCode.TooManyRequests;
}
