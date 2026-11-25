using System.Net;
using System.Net.Http.Json;
using Fleet.Api.Data.Entities;
using Fleet.Api.Tests.Infrastructure;
using Fleet.Api.Vehicles;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Tests;

[Collection(ApiCollection.Name)]
public class VehicleListTests(FleetApiFactory factory)
{
    [Fact]
    public async Task VehicleWithoutTelemetry_HasNullLocationAndIsOffline()
    {
        var client = await AdminClientAsync();
        var vehicleId = await factory.VehicleIdAsync("SN-0003");

        var vehicle = await client.GetFromJsonAsync<VehicleDto>($"/api/vehicles/{vehicleId}", HttpClientExtensions.Json);

        Assert.Equal(VehicleStatus.Offline, vehicle!.Status);
        Assert.Equal(Connectivity.Offline, vehicle.Connectivity);
        Assert.Equal(TestData.TarsusFleetName, vehicle.FleetName);
        Assert.Null(vehicle.Latitude);
        Assert.Null(vehicle.Longitude);
        Assert.Null(vehicle.SpeedKmh);
        Assert.Null(vehicle.HeadingDeg);
        Assert.Null(vehicle.BatteryPct);
        Assert.Null(vehicle.LastTelemetryAt);
        Assert.Null(vehicle.LastSeenAt);
    }

    [Fact]
    public async Task StatusFilter_Offline_ContainsSeededVehiclesWithoutTelemetry()
    {
        var client = await AdminClientAsync();

        var vehicles = await client.GetFromJsonAsync<List<VehicleDto>>(
            "/api/vehicles?status=Offline", HttpClientExtensions.Json);

        Assert.All(vehicles!, v => Assert.Equal(VehicleStatus.Offline, v.Status));
        Assert.Contains(vehicles!, v => v.SerialNumber == "SN-0003");
    }

    [Theory]
    [InlineData(VehicleState.Moving, VehicleStatus.Moving)]
    [InlineData(VehicleState.Fault, VehicleStatus.Fault)]
    public async Task StatusFilter_AndDtoStatus_Agree(VehicleState reportedState, VehicleStatus expectedStatus)
    {
        var vehicleId = await factory.VehicleIdAsync("SN-0004");
        await SetLatestStateAsync(vehicleId, Connectivity.Online, reportedState);
        try
        {
            var client = await AdminClientAsync();

            var matching = await client.GetFromJsonAsync<List<VehicleDto>>(
                $"/api/vehicles?status={expectedStatus}", HttpClientExtensions.Json);
            var offline = await client.GetFromJsonAsync<List<VehicleDto>>(
                "/api/vehicles?status=Offline", HttpClientExtensions.Json);

            var vehicle = Assert.Single(matching!, v => v.Id == vehicleId);
            Assert.Equal(expectedStatus, vehicle.Status);
            Assert.DoesNotContain(offline!, v => v.Id == vehicleId);
        }
        finally
        {
            await SetLatestStateAsync(vehicleId, Connectivity.Offline, null);
        }
    }

    [Fact]
    public async Task OfflineVehicle_ShowsOffline_EvenWithLastReportedState()
    {
        var vehicleId = await factory.VehicleIdAsync("SN-0004");
        await SetLatestStateAsync(vehicleId, Connectivity.Offline, VehicleState.Moving);
        try
        {
            var client = await AdminClientAsync();

            var vehicle = await client.GetFromJsonAsync<VehicleDto>($"/api/vehicles/{vehicleId}", HttpClientExtensions.Json);
            var moving = await client.GetFromJsonAsync<List<VehicleDto>>("/api/vehicles?status=Moving", HttpClientExtensions.Json);

            Assert.Equal(VehicleStatus.Offline, vehicle!.Status);
            Assert.DoesNotContain(moving!, v => v.Id == vehicleId);
        }
        finally
        {
            await SetLatestStateAsync(vehicleId, Connectivity.Offline, null);
        }
    }

    [Theory]
    [InlineData("Bogus")]
    [InlineData("7")]
    public async Task StatusFilter_InvalidValue_Returns400ProblemDetails(string status)
    {
        var client = await AdminClientAsync();

        var response = await client.GetAsync($"/api/vehicles?status={status}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    private Task SetLatestStateAsync(Guid vehicleId, Connectivity connectivity, VehicleState? state) =>
        factory.WithDbAsync(db => db.Vehicles.Where(v => v.Id == vehicleId).ExecuteUpdateAsync(s => s
            .SetProperty(v => v.Connectivity, connectivity)
            .SetProperty(v => v.LastReportedState, state)));

    private async Task<HttpClient> AdminClientAsync()
    {
        var client = factory.CreateClient();
        await client.AuthenticateAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);
        return client;
    }
}
