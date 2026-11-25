using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Json;
using Fleet.Api.Auth;
using Fleet.Api.Data.Entities;
using Fleet.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Mvc;

namespace Fleet.Api.Tests;

[Collection(ApiCollection.Name)]
public class AuthTests(FleetApiFactory factory)
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Login_WithValidCredentials_ReturnsTokenAndUser()
    {
        var response = await _client.LoginAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<LoginResponse>(HttpClientExtensions.Json);
        Assert.NotNull(body);
        Assert.False(string.IsNullOrWhiteSpace(body.AccessToken));
        Assert.Equal(DemoUsers.AdminEmail, body.User.Email);
        Assert.Equal(Role.Admin, body.User.Role);
        Assert.True(body.ExpiresAt > DateTimeOffset.UtcNow.AddMinutes(55));
    }

    [Fact]
    public async Task Login_Token_ContainsSubEmailAndRoleClaims()
    {
        var response = await _client.LoginAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);
        var body = await response.Content.ReadFromJsonAsync<LoginResponse>(HttpClientExtensions.Json);

        var token = new JwtSecurityTokenHandler().ReadJwtToken(body!.AccessToken);
        Assert.Equal(body.User.Id.ToString(), token.Subject);
        Assert.Equal(DemoUsers.TarsusOperatorEmail, token.Claims.Single(c => c.Type == "email").Value);
        Assert.Equal("Operator", token.Claims.Single(c => c.Type == "role").Value);
    }

    [Fact]
    public async Task Login_NormalizesEmail()
    {
        var response = await _client.LoginAsync("  Admin@Demo.LOCAL ", DemoUsers.AdminPassword);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Login_WithWrongPassword_Returns401ProblemDetails()
    {
        var response = await _client.LoginAsync(DemoUsers.AdminEmail, "wrong-password");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task Login_WithUnknownEmail_ReturnsSameResponseAsWrongPassword()
    {
        var wrongPassword = await _client.LoginAsync(DemoUsers.AdminEmail, "wrong-password");
        var unknownEmail = await _client.LoginAsync("nobody@demo.local", "wrong-password");

        Assert.Equal(HttpStatusCode.Unauthorized, unknownEmail.StatusCode);
        var expected = await wrongPassword.Content.ReadFromJsonAsync<ProblemDetails>();
        var actual = await unknownEmail.Content.ReadFromJsonAsync<ProblemDetails>();
        Assert.Equal(expected!.Title, actual!.Title);
        Assert.Equal(expected.Detail, actual.Detail);
    }

    [Fact]
    public async Task Login_WithMissingFields_Returns400()
    {
        var response = await _client.PostAsJsonAsync("/api/auth/login", new { email = DemoUsers.AdminEmail });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Me_WithoutToken_Returns401()
    {
        var response = await _client.GetAsync("/api/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Me_WithTamperedToken_Returns401()
    {
        await _client.AuthenticateAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);
        var token = _client.DefaultRequestHeaders.Authorization!.Parameter!;
        _client.DefaultRequestHeaders.Authorization = new("Bearer", token[..^4] + "AAAA");

        var response = await _client.GetAsync("/api/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Me_AsTarsusOperator_ReturnsOnlyTarsusFleet()
    {
        await _client.AuthenticateAsync(DemoUsers.TarsusOperatorEmail, DemoUsers.OperatorPassword);

        var me = await _client.GetFromJsonAsync<MeResponse>("/api/auth/me", HttpClientExtensions.Json);

        Assert.Equal(DemoUsers.TarsusOperatorEmail, me!.User.Email);
        var fleet = Assert.Single(me.Fleets);
        Assert.Equal("Tarsus Field Ops", fleet.Name);
    }

    [Fact]
    public async Task Me_AsAdmin_ReturnsAllFleets()
    {
        await _client.AuthenticateAsync(DemoUsers.AdminEmail, DemoUsers.AdminPassword);

        var me = await _client.GetFromJsonAsync<MeResponse>("/api/auth/me", HttpClientExtensions.Json);

        // "Contains", not exact: tests may add a test-only fleet (see FleetApiFactory).
        Assert.Contains(me!.Fleets, f => f.Name == TestData.TarsusFleetName);
        Assert.Contains(me.Fleets, f => f.Name == TestData.AdanaFleetName);
    }
}
