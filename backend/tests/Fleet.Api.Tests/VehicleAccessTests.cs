using System.Net;
using System.Net.Http.Json;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;
using Microsoft.AspNetCore.Mvc;

namespace Fleet.Api.Tests;

/// <summary>The access rule (CLAUDE.md Section 6) checked on every vehicle endpoint.</summary>
[Collection(ApiCollection.Name)]
public class VehicleAccessTests(FleetApiFactory factory)
{
    // Suffixes appended to /api/vehicles/{id}: detail, telemetry, activity.
    public static TheoryData<string> VehicleEndpoints => new() { "", "/telemetry", "/activity" };

    [Fact]
    public async Task Admin_ListContainsAllSeededVehicles()
    {
        var client = await LoggedInAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        var vehicles = await client.GetFromJsonAsync<List<VehicleDto>>("/api/vehicles", HttpClientExtensions.Json);

        Assert.Superset(TestData.AllSeededSerials.ToHashSet(), vehicles!.Select(v => v.SerialNumber).ToHashSet());
    }

    [Theory]
    [InlineData(DemoUsers.TarsusOperatorEmail, TestData.TarsusFleetName)]
    [InlineData(DemoUsers.AdanaOperatorEmail, TestData.AdanaFleetName)]
    public async Task Operator_ListsExactlyFourVehicles_AllFromOwnFleet(string email, string fleetName)
    {
        var client = await LoggedInAsync(email, DemoUsers.OperatorPassword);

        var vehicles = await client.GetFromJsonAsync<List<VehicleDto>>("/api/vehicles", HttpClientExtensions.Json);

        Assert.Equal(4, vehicles!.Count);
        Assert.All(vehicles, v => Assert.Equal(fleetName, v.FleetName));
    }

    [Fact]
    public async Task Operator_FilterByOtherFleet_ReturnsEmptyList()
    {
        var adanaFleetId = await factory.FleetIdAsync(TestData.AdanaFleetName);
        var client = await LoggedInAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        var response = await client.GetAsync($"/api/vehicles?fleetId={adanaFleetId}");

        // 200 + empty, exactly like a fleet with no vehicles, so the filter can't be used to probe other fleets.
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Empty((await response.Content.ReadFromJsonAsync<List<VehicleDto>>(HttpClientExtensions.Json))!);
    }

    [Fact]
    public async Task Operator_FilterByOwnFleet_ReturnsOwnVehicles()
    {
        var tarsusFleetId = await factory.FleetIdAsync(TestData.TarsusFleetName);
        var client = await LoggedInAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        var vehicles = await client.GetFromJsonAsync<List<VehicleDto>>(
            $"/api/vehicles?fleetId={tarsusFleetId}", HttpClientExtensions.Json);

        Assert.Equal(TestData.TarsusSerials, vehicles!.Select(v => v.SerialNumber).Order());
    }

    [Theory]
    [MemberData(nameof(VehicleEndpoints))]
    public async Task Operator_OtherFleetVehicle_Returns404(string suffix)
    {
        var adanaVehicleId = await factory.VehicleIdAsync("SN-0005");
        var client = await LoggedInAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        var response = await client.GetAsync($"/api/vehicles/{adanaVehicleId}{suffix}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Theory]
    [MemberData(nameof(VehicleEndpoints))]
    public async Task Operator_OtherFleetVehicle_LooksExactlyLikeNonexistentVehicle(string suffix)
    {
        var adanaVehicleId = await factory.VehicleIdAsync("SN-0005");
        var client = await LoggedInAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        var forbidden = await client.GetAsync($"/api/vehicles/{adanaVehicleId}{suffix}");
        var missing = await client.GetAsync($"/api/vehicles/{Guid.NewGuid()}{suffix}");

        Assert.Equal(missing.StatusCode, forbidden.StatusCode);
        var forbiddenBody = await forbidden.Content.ReadFromJsonAsync<ProblemDetails>();
        var missingBody = await missing.Content.ReadFromJsonAsync<ProblemDetails>();
        Assert.Equal(missingBody!.Title, forbiddenBody!.Title);
        Assert.Equal(missingBody.Detail, forbiddenBody.Detail);
    }

    [Theory]
    [MemberData(nameof(VehicleEndpoints))]
    public async Task Operator_OwnFleetVehicle_Returns200(string suffix)
    {
        var tarsusVehicleId = await factory.VehicleIdAsync("SN-0001");
        var client = await LoggedInAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        var response = await client.GetAsync($"/api/vehicles/{tarsusVehicleId}{suffix}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [MemberData(nameof(VehicleEndpoints))]
    public async Task Admin_AnyFleetVehicle_Returns200(string suffix)
    {
        var client = await LoggedInAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        foreach (var serial in new[] { "SN-0001", "SN-0005" })
        {
            var vehicleId = await factory.VehicleIdAsync(serial);
            var response = await client.GetAsync($"/api/vehicles/{vehicleId}{suffix}");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }
    }

    [Theory]
    [InlineData("/api/vehicles")]
    [InlineData("/api/fleets")]
    [InlineData("/api/vehicles/{id}")]
    [InlineData("/api/vehicles/{id}/telemetry")]
    [InlineData("/api/vehicles/{id}/activity")]
    public async Task Endpoints_WithoutToken_Return401(string path)
    {
        var vehicleId = await factory.VehicleIdAsync("SN-0001");

        var response = await factory.CreateClient().GetAsync(path.Replace("{id}", vehicleId.ToString()));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Fleets_Operator_SeesOnlyOwnFleet()
    {
        var client = await LoggedInAsync(DemoUsers.AdanaOperatorEmail, DemoUsers.OperatorPassword);

        var fleets = await client.GetFromJsonAsync<List<FleetDto>>("/api/fleets", HttpClientExtensions.Json);

        Assert.Equal(TestData.AdanaFleetName, Assert.Single(fleets!).Name);
    }

    [Fact]
    public async Task Fleets_Admin_SeesBothSeededFleets()
    {
        var client = await LoggedInAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        var fleets = await client.GetFromJsonAsync<List<FleetDto>>("/api/fleets", HttpClientExtensions.Json);

        Assert.Contains(fleets!, f => f.Name == TestData.TarsusFleetName);
        Assert.Contains(fleets!, f => f.Name == TestData.AdanaFleetName);
    }

    private async Task<HttpClient> LoggedInAsync(string email, string password)
    {
        var client = factory.CreateClient();
        await client.AuthenticateAsync(email, password);
        return client;
    }
}
