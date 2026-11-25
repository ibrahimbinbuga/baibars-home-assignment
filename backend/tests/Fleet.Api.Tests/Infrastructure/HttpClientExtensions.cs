using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Fleet.Api.Tests.Infrastructure;

public static class HttpClientExtensions
{
    // Same shape as the API's JSON: camelCase and enums as strings.
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    public static Task<HttpResponseMessage> LoginAsync(this HttpClient client, string email, string password) =>
        client.PostAsJsonAsync("/api/auth/login", new { email, password });

    /// <summary>Logs in and sets the bearer token on the client for the following requests.</summary>
    public static async Task AuthenticateAsync(this HttpClient client, string email, string password)
    {
        var response = await client.LoginAsync(email, password);
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<Fleet.Api.Auth.LoginResponse>(Json);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", body!.AccessToken);
    }
}
