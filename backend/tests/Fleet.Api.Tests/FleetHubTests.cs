using System.Net;
using System.Net.Http.Json;
using System.Text;
using Fleet.Api.Auth;
using Fleet.Api.Data.Entities;
using Fleet.Api.Realtime;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Fleet.Api.Tests;

/// <summary>
/// Real-time access rule: a connection only receives updates for fleets the user may see.
/// Ingests into seeded vehicles SN-0004 (Tarsus) and SN-0008 (Adana) and resets them before and after each test,
/// so other tests still see them as freshly seeded.
/// </summary>
[Collection(ApiCollection.Name)]
public class FleetHubTests(FleetApiFactory factory) : IAsyncLifetime
{
    private const string TarsusSerial = "SN-0004";
    private const string AdanaSerial = "SN-0008";

    private readonly HttpClient _http = factory.CreateClient();
    private long _sequence;

    public async Task InitializeAsync()
    {
        await factory.ResetSeededVehicleAsync(TarsusSerial);
        await factory.ResetSeededVehicleAsync(AdanaSerial);
    }

    public async Task DisposeAsync()
    {
        await factory.ResetSeededVehicleAsync(TarsusSerial);
        await factory.ResetSeededVehicleAsync(AdanaSerial);
    }

    [Fact]
    public async Task TarsusOperator_ReceivesTarsusUpdatesAndActivity_ButNeverAdana()
    {
        var tarsusId = await factory.VehicleIdAsync(TarsusSerial);
        var adanaId = await factory.VehicleIdAsync(AdanaSerial);
        await using var hub = await ConnectAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        // Adana first, then Tarsus. Messages on one connection arrive in send order, so if the Adana update leaked
        // to this connection it would arrive before the Tarsus one. No sleeps needed.
        await IngestAsync(AdanaSerial);
        await IngestAsync(TarsusSerial);

        await hub.WaitForAsync(m => m.Method == "VehicleUpdated" && m.VehicleId == tarsusId);
        var activity = await hub.WaitForAsync(m => m.Method == "ActivityRaised" && m.VehicleId == tarsusId);

        Assert.Equal("CameOnline", activity.Payload.GetProperty("type").GetString());
        Assert.DoesNotContain(hub.Received, m => m.VehicleId == adanaId);
    }

    [Fact]
    public async Task Admin_ReceivesUpdatesFromBothFleets()
    {
        var tarsusId = await factory.VehicleIdAsync(TarsusSerial);
        var adanaId = await factory.VehicleIdAsync(AdanaSerial);
        await using var hub = await ConnectAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        await IngestAsync(AdanaSerial);
        await IngestAsync(TarsusSerial);

        await hub.WaitForAsync(m => m.Method == "VehicleUpdated" && m.VehicleId == adanaId);
        await hub.WaitForAsync(m => m.Method == "VehicleUpdated" && m.VehicleId == tarsusId);
    }

    [Fact]
    public async Task VehicleUpdated_UsesSameJsonAsRestApi_CamelCaseAndStringEnums()
    {
        var tarsusId = await factory.VehicleIdAsync(TarsusSerial);
        await using var hub = await ConnectAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        await IngestAsync(TarsusSerial, state: "Moving");
        var message = await hub.WaitForAsync(m => m.Method == "VehicleUpdated" && m.VehicleId == tarsusId);

        Assert.Equal("Moving", message.Payload.GetProperty("status").GetString());
        Assert.Equal("Online", message.Payload.GetProperty("connectivity").GetString());
        Assert.Equal(TestData.TarsusFleetName, message.Payload.GetProperty("fleetName").GetString());
    }

    [Fact]
    public async Task UserWithNoFleets_StaysConnected_AndReceivesNothing()
    {
        var email = $"nofleet-{Guid.NewGuid():N}@test.local";
        await factory.CreateUserAsync(email, "Test123!", Role.Operator);
        await using var hub = await ConnectAsync(email, "Test123!");

        await IngestAsync(TarsusSerial);
        await IngestAsync(AdanaSerial);

        // The ingest calls return only after their broadcasts were handed to SignalR. A marker sent directly to this
        // connection afterwards arrives after anything that was sent to it before, so everything received before
        // the marker would be a leak.
        var marker = new ActivityEventDto(-1, Guid.Empty, ActivityEventType.StateChanged, DateTimeOffset.UtcNow, "marker");
        await factory.Services.GetRequiredService<IHubContext<FleetHub, IFleetClient>>()
            .Clients.Client(hub.Connection.ConnectionId!).ActivityRaised(marker);
        await hub.WaitForAsync(m => m.Method == "ActivityRaised" && m.Payload.GetProperty("id").GetInt64() == -1);

        Assert.Single(hub.Received); // only the marker
        Assert.Equal(HubConnectionState.Connected, hub.Connection.State);
    }

    [Fact]
    public async Task NoToken_IsRejected()
    {
        var exception = await Assert.ThrowsAsync<HttpRequestException>(() => HubTestClient.ConnectAsync(factory, null));

        Assert.Equal(HttpStatusCode.Unauthorized, exception.StatusCode);
    }

    [Fact]
    public async Task DeviceKey_IsRejected()
    {
        var deviceKey = TestData.SeededDeviceKey(TarsusSerial);

        var exception = await Assert.ThrowsAsync<HttpRequestException>(() =>
            HubTestClient.ConnectAsync(factory, null, o => o.Headers["X-Device-Key"] = deviceKey));

        Assert.Equal(HttpStatusCode.Unauthorized, exception.StatusCode);
    }

    [Fact]
    public async Task QueryStringToken_IsOnlyAcceptedForTheHub()
    {
        var token = await LoginAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        var response = await factory.CreateClient().GetAsync($"/api/auth/me?access_token={token}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Connection_IsClosed_WhenTokenExpires()
    {
        // CloseOnAuthenticationExpiration uses the token's exp (JwtBearer copies ValidTo into ExpiresUtc). ClockSkew
        // (30 s) only applies when a token is validated, not to an open connection. The 15 s timeout is shorter than
        // the skew, so this test would fail if the skew were added.
        var token = CreateToken(await factory.VehicleIdAsync(TarsusSerial), lifetime: TimeSpan.FromSeconds(3));
        var closed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        await using var hub = await HubTestClient.ConnectAsync(factory, token);
        hub.Connection.Closed += _ => { closed.TrySetResult(); return Task.CompletedTask; };

        await closed.Task.WaitAsync(TimeSpan.FromSeconds(15));

        Assert.Equal(HubConnectionState.Disconnected, hub.Connection.State);
    }

    // A token for a user id that may not exist is fine here: the hub only needs a valid signature and claims.
    private static string CreateToken(Guid subject, TimeSpan lifetime)
    {
        var now = DateTime.UtcNow;
        return new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = "fleet-api",
            Audience = "fleet-mobile",
            IssuedAt = now,
            NotBefore = now,
            Expires = now + lifetime,
            Claims = new Dictionary<string, object>
            {
                [JwtRegisteredClaimNames.Sub] = subject.ToString(),
                [AuthClaims.Role] = nameof(Role.Admin),
            },
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(FleetApiFactory.TestSigningKey)), SecurityAlgorithms.HmacSha256),
        });
    }

    private async Task<HubTestClient> ConnectAsync(string email, string password) =>
        await HubTestClient.ConnectAsync(factory, await LoginAsync(email, password));

    private async Task<string> LoginAsync(string email, string password)
    {
        var response = await _http.LoginAsync(email, password);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<LoginResponse>(HttpClientExtensions.Json))!.AccessToken;
    }

    private async Task IngestAsync(string serial, string state = "Moving")
    {
        var response = await _http.PostTelemetryAsync(
            TestData.SeededDeviceKey(serial), new SampleBody(++_sequence, DateTimeOffset.UtcNow, State: state));
        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
    }
}
