using System.Buffers.Text;
using System.Net;
using System.Net.Http.Json;
using System.Text;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;

namespace Fleet.Api.Tests;

[Collection(ApiCollection.Name)]
public class ActivityTests(FleetApiFactory factory) : IAsyncLifetime
{
    private Guid _vehicleId;
    private HttpClient _client = null!;

    public async Task InitializeAsync()
    {
        _vehicleId = await factory.VehicleIdAsync("SN-0002");
        await factory.ClearHistoryAsync(_vehicleId);
        _client = factory.CreateClient();
        await _client.AuthenticateAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);
    }

    public Task DisposeAsync() => factory.ClearHistoryAsync(_vehicleId);

    [Fact]
    public async Task Paging_ReturnsEveryEventExactlyOnce_WithTiedAndSubMicrosecondTimestamps()
    {
        var t = new DateTimeOffset(2026, 11, 20, 12, 0, 0, TimeSpan.Zero);
        // 3 identical timestamps, 3 that differ only below a microsecond (.NET ticks are 100 ns; Postgres keeps µs),
        // plus older and newer neighbours. With limit 2 the page boundaries fall inside the tied group.
        await InsertAsync(
            t.AddSeconds(-1), t, t, t, t.AddTicks(1), t.AddTicks(5), t.AddTicks(9), t.AddMicroseconds(1), t.AddSeconds(1));

        var seen = new List<ActivityEventDto>();
        string? before = null;
        var pages = 0;
        do
        {
            var page = await GetAsync(before is null ? "?limit=2" : $"?limit=2&before={before}");
            seen.AddRange(page.Items);
            before = page.NextBefore;
            Assert.True(++pages < 20, "Paging did not terminate.");
        }
        while (before is not null);

        Assert.Equal(9, seen.Count);
        Assert.Equal(seen.Count, seen.Select(e => e.Id).Distinct().Count());
        var expectedOrder = seen.OrderByDescending(e => e.OccurredAt).ThenByDescending(e => e.Id).Select(e => e.Id);
        Assert.Equal(expectedOrder, seen.Select(e => e.Id));
    }

    [Fact]
    public async Task LastPage_HasNullNextBefore()
    {
        var now = DateTimeOffset.UtcNow;
        await InsertAsync(now.AddMinutes(-2), now.AddMinutes(-1));

        var page = await GetAsync("?limit=2");

        Assert.Equal(2, page.Items.Count);
        Assert.Null(page.NextBefore);
    }

    [Fact]
    public async Task NoEvents_ReturnsEmptyPage()
    {
        var page = await GetAsync("");

        Assert.Empty(page.Items);
        Assert.Null(page.NextBefore);
    }

    [Fact]
    public async Task LimitAboveMax_IsClampedTo200()
    {
        var now = DateTimeOffset.UtcNow;
        await InsertAsync(Enumerable.Range(1, 201).Select(i => now.AddSeconds(-i)).ToArray());

        var page = await GetAsync("?limit=1000");

        Assert.Equal(200, page.Items.Count);
        Assert.NotNull(page.NextBefore);
    }

    public static TheoryData<string> InvalidQueries => new()
    {
        "?limit=0",
        "?before=not*base64!",
        "?before=" + Base64Url.EncodeToString(Encoding.UTF8.GetBytes("garbage")),
        "?before=" + Base64Url.EncodeToString(Encoding.UTF8.GetBytes("123")),
        "?before=" + Base64Url.EncodeToString(Encoding.UTF8.GetBytes("-5_10")),
        "?before=" + Base64Url.EncodeToString(Encoding.UTF8.GetBytes("99999999999999999999_10")),
        "?before=" + Base64Url.EncodeToString(Encoding.UTF8.GetBytes("1_0")),
    };

    [Theory]
    [MemberData(nameof(InvalidQueries))]
    public async Task InvalidLimitOrCursor_Returns400ProblemDetails(string query)
    {
        var response = await _client.GetAsync($"/api/vehicles/{_vehicleId}/activity{query}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    private async Task<ActivityPageResponse> GetAsync(string query) =>
        (await _client.GetFromJsonAsync<ActivityPageResponse>(
            $"/api/vehicles/{_vehicleId}/activity{query}", HttpClientExtensions.Json))!;

    private Task InsertAsync(params DateTimeOffset[] occurredAt) =>
        factory.WithDbAsync(async db =>
        {
            db.ActivityEvents.AddRange(occurredAt.Select((t, i) => TestData.Activity(_vehicleId, t, $"event {i}")));
            await db.SaveChangesAsync();
        });
}
