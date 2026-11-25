using System.Text.Json;
using System.Text.Json.Serialization;

namespace Fleet.Api.Common;

/// <summary>
/// JSON settings shared by the REST API and the SignalR hub, so a VehicleDto looks the same on both
/// (camelCase, enums as strings).
/// </summary>
public static class JsonConfiguration
{
    public static void Apply(JsonSerializerOptions options)
    {
        options.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.Converters.Add(new JsonStringEnumConverter());
    }
}
