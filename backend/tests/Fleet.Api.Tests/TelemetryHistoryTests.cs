using System.Net;
using System.Net.Http.Json;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;

namespace Fleet.Api.Tests;

[Collection(ApiCollection.Name)]
public class TelemetryHistoryTests(FleetApiFactory factory) : IAsyncLifetime
{
    private Guid _vehicleId;
    private HttpClient _client = null!;

    public async Task InitializeAsync()
    {
        _vehicleId = await factory.VehicleIdAsync("SN-0001");
        await factory.ClearHistoryAsync(_vehicleId);
        _client = factory.CreateClient();
        await _client.AuthenticateAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);
    }

    public Task DisposeAsync() => factory.ClearHistoryAsync(_vehicleId);

    [Fact]
    public async Task Default_ReturnsLastHour_NewestFirst()
    {
        var now = DateTimeOffset.UtcNow;
        await InsertAsync((1, now.AddHours(-2)), (2, now.AddMinutes(-30)), (3, now.AddMinutes(-10)));

        var response = await GetAsync("");

        Assert.Equal([3L, 2L], response.Items.Select(i => i.Sequence));
        Assert.InRange(response.To - response.From, TimeSpan.FromHours(1), TimeSpan.FromHours(1));
    }

    [Fact]
    public async Task ExplicitRange_ReturnsOnlyRecordsInside_AndAcceptsNonUtcOffsets()
    {
        var baseTime = new DateTimeOffset(2026, 11, 20, 12, 0, 0, TimeSpan.Zero);
        await InsertAsync((1, baseTime.AddMinutes(-1)), (2, baseTime), (3, baseTime.AddMinutes(5)), (4, baseTime.AddMinutes(11)));

        // 15:00+03:00 == 12:00Z. "+" must be URL-encoded in a query string.
        var response = await GetAsync("?from=2026-11-20T15:00:00%2B03:00&to=2026-11-20T12:10:00Z");

        Assert.Equal([3L, 2L], response.Items.Select(i => i.Sequence));
        Assert.Equal(baseTime, response.From);
    }

    [Fact]
    public async Task LimitAboveMax_IsClampedTo2000()
    {
        var now = DateTimeOffset.UtcNow;
        await InsertAsync(Enumerable.Range(1, 2001).Select(i => ((long)i, now.AddMilliseconds(-i * 100))).ToArray());

        var response = await GetAsync("?limit=5000");

        Assert.Equal(2000, response.Items.Count);
    }

    [Theory]
    [InlineData("?from=2026-11-20T12:00:00Z&to=2026-11-20T11:00:00Z")]  // from > to
    [InlineData("?from=2026-11-01T00:00:00Z&to=2026-11-08T00:00:01Z")]  // more than 7 days
    [InlineData("?limit=0")]
    [InlineData("?limit=-5")]
    public async Task InvalidQuery_Returns400ProblemDetails(string query)
    {
        var response = await _client.GetAsync($"/api/vehicles/{_vehicleId}/telemetry{query}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task ExactlySevenDays_IsAllowed()
    {
        var response = await _client.GetAsync(
            $"/api/vehicles/{_vehicleId}/telemetry?from=2026-11-01T00:00:00Z&to=2026-11-08T00:00:00Z");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private async Task<TelemetryResponse> GetAsync(string query) =>
        (await _client.GetFromJsonAsync<TelemetryResponse>(
            $"/api/vehicles/{_vehicleId}/telemetry{query}", HttpClientExtensions.Json))!;

    private Task InsertAsync(params (long Sequence, DateTimeOffset RecordedAt)[] records) =>
        factory.WithDbAsync(async db =>
        {
            db.TelemetryRecords.AddRange(records.Select(r => TestData.Telemetry(_vehicleId, r.Sequence, r.RecordedAt)));
            await db.SaveChangesAsync();
        });
}
