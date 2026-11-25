using System.Net.Http.Json;

namespace Fleet.Api.Tests.Infrastructure;

/// <summary>A valid ingest body; tests override what they care about with `with { ... }`.</summary>
public record SampleBody(
    long Sequence,
    DateTimeOffset RecordedAt,
    double Latitude = 36.92,
    double Longitude = 34.89,
    double SpeedKmh = 10,
    double HeadingDeg = 90,
    double BatteryPct = 80,
    string State = "Moving");

public static class IngestHelpers
{
    public static Task<HttpResponseMessage> PostTelemetryAsync(this HttpClient client, string? deviceKey, object body)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/ingest/telemetry")
        {
            Content = JsonContent.Create(body, options: HttpClientExtensions.Json),
        };
        if (deviceKey is not null)
        {
            request.Headers.Add("X-Device-Key", deviceKey);
        }

        return client.SendAsync(request);
    }
}
