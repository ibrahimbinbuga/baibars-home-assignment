using System.Text.Json;
using System.Threading.Channels;
using Fleet.Api.Realtime;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.Http.Connections.Client;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;

namespace Fleet.Api.Tests.Infrastructure;

/// <summary>
/// A SignalR client connected to the in-memory test server. Messages are kept as raw JSON so tests see exactly what
/// was sent on the wire. Waiting is event-driven (no fixed sleeps): <see cref="WaitForAsync"/> reads messages in
/// arrival order until one matches.
/// </summary>
public sealed class HubTestClient : IAsyncDisposable
{
    public record Message(string Method, JsonElement Payload)
    {
        public Guid VehicleId => Payload.GetProperty(Method == "VehicleUpdated" ? "id" : "vehicleId").GetGuid();
    }

    private readonly Channel<Message> _incoming = Channel.CreateUnbounded<Message>();

    private HubTestClient(HubConnection connection) => Connection = connection;

    public HubConnection Connection { get; }

    /// <summary>Every message read so far, in arrival order.</summary>
    public List<Message> Received { get; } = [];

    /// <summary>
    /// Connects like the mobile app does: token in the access_token query parameter.
    /// Long polling, because the in-memory TestServer handler doesn't do WebSockets without extra setup.
    /// </summary>
    public static async Task<HubTestClient> ConnectAsync(
        WebApplicationFactory<Program> factory, string? accessToken, Action<HttpConnectionOptions>? configure = null)
    {
        var query = accessToken is null ? "" : "?access_token=" + Uri.EscapeDataString(accessToken);
        var connection = new HubConnectionBuilder()
            .WithUrl(new Uri(factory.Server.BaseAddress, FleetHub.Path + query), options =>
            {
                options.Transports = HttpTransportType.LongPolling;
                options.HttpMessageHandlerFactory = _ => factory.Server.CreateHandler();
                configure?.Invoke(options);
            })
            .Build();

        var client = new HubTestClient(connection);
        connection.On<JsonElement>("VehicleUpdated", p => client._incoming.Writer.TryWrite(new Message("VehicleUpdated", p)));
        connection.On<JsonElement>("ActivityRaised", p => client._incoming.Writer.TryWrite(new Message("ActivityRaised", p)));
        await connection.StartAsync();
        return client;
    }

    public async Task<Message> WaitForAsync(Func<Message, bool> match, TimeSpan? timeout = null)
    {
        using var cts = new CancellationTokenSource(timeout ?? TimeSpan.FromSeconds(10));
        try
        {
            await foreach (var message in _incoming.Reader.ReadAllAsync(cts.Token))
            {
                Received.Add(message);
                if (match(message))
                {
                    return message;
                }
            }
        }
        catch (OperationCanceledException)
        {
        }

        throw new TimeoutException(
            $"Expected message not received. Got: {string.Join(", ", Received.Select(m => $"{m.Method}({m.VehicleId})"))}");
    }

    public ValueTask DisposeAsync() => Connection.DisposeAsync();
}
