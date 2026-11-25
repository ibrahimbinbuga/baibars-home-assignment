using System.Net;
using System.Net.Http.Json;
using Fleet.Api.Auth;
using Fleet.Api.Data.Entities;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Tests;

/// <summary>
/// A valid token is not enough: the user must still exist, and the role comes from the database on every request.
/// Each test uses its own user, so the seeded demo users are never changed.
/// </summary>
[Collection(ApiCollection.Name)]
public class CurrentUserValidationTests(FleetApiFactory factory)
{
    private const string Password = "Test123!";

    [Fact]
    public async Task DeletedUser_GetsUnauthorized_OnRest()
    {
        var tarsus = await factory.FleetIdAsync(TestData.TarsusFleetName);
        var (client, email) = await LoggedInNewUserAsync(Role.Operator, tarsus);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/vehicles")).StatusCode);

        await DeleteUserAsync(email);

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/vehicles")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/auth/me")).StatusCode);
    }

    [Fact]
    public async Task DeletedAdmin_GetsUnauthorized_EvenThoughTheTokenSaysAdmin()
    {
        var (client, email) = await LoggedInNewUserAsync(Role.Admin);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/vehicles")).StatusCode);

        await DeleteUserAsync(email);

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/vehicles")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/fleets")).StatusCode);
    }

    [Fact]
    public async Task AdminDemotedToOperator_SeesOnlyAssignedFleets_WithoutLoggingInAgain()
    {
        var tarsus = await factory.FleetIdAsync(TestData.TarsusFleetName);
        var (client, email) = await LoggedInNewUserAsync(Role.Admin, tarsus);
        var before = await client.GetFromJsonAsync<List<VehicleDto>>("/api/vehicles", HttpClientExtensions.Json);
        Assert.Contains(before!, v => v.FleetName == TestData.AdanaFleetName);

        await factory.WithDbAsync(db => db.Users.Where(u => u.Email == email)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.Role, Role.Operator)));

        // Same token (it still says "Admin"); the database role wins.
        var after = await client.GetFromJsonAsync<List<VehicleDto>>("/api/vehicles", HttpClientExtensions.Json);
        Assert.Equal(4, after!.Count);
        Assert.All(after, v => Assert.Equal(TestData.TarsusFleetName, v.FleetName));
        var fleets = await client.GetFromJsonAsync<List<FleetDto>>("/api/fleets", HttpClientExtensions.Json);
        Assert.Equal(TestData.TarsusFleetName, Assert.Single(fleets!).Name);
    }

    [Fact]
    public async Task OperatorPromotedToAdmin_SeesAllFleets_WithoutLoggingInAgain()
    {
        var tarsus = await factory.FleetIdAsync(TestData.TarsusFleetName);
        var (client, email) = await LoggedInNewUserAsync(Role.Operator, tarsus);

        await factory.WithDbAsync(db => db.Users.Where(u => u.Email == email)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.Role, Role.Admin)));

        var vehicles = await client.GetFromJsonAsync<List<VehicleDto>>("/api/vehicles", HttpClientExtensions.Json);
        Assert.Contains(vehicles!, v => v.FleetName == TestData.AdanaFleetName);
    }

    [Fact]
    public async Task DeletedUser_IsRejected_WhenConnectingToTheHub()
    {
        var (client, email) = await LoggedInNewUserAsync(Role.Admin);
        var token = client.DefaultRequestHeaders.Authorization!.Parameter!;
        await DeleteUserAsync(email);

        var exception = await Assert.ThrowsAsync<HttpRequestException>(() => HubTestClient.ConnectAsync(factory, token));

        Assert.Equal(HttpStatusCode.Unauthorized, exception.StatusCode);
    }

    private async Task<(HttpClient Client, string Email)> LoggedInNewUserAsync(Role role, params Guid[] fleetIds)
    {
        var email = $"user-{Guid.NewGuid():N}@test.local";
        await factory.CreateUserAsync(email, Password, role, fleetIds);
        var client = factory.CreateClient();
        await client.AuthenticateAsync(email, Password);
        return (client, email);
    }

    private Task DeleteUserAsync(string email) =>
        factory.WithDbAsync(db => db.Users.Where(u => u.Email == email).ExecuteDeleteAsync());
}
