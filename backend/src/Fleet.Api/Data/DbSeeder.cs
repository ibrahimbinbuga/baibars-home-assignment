using System.Text.Json;
using Fleet.Api.Auth;
using Fleet.Api.Data.Entities;
using Fleet.Api.Telemetry;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Data;

/// <summary>
/// Creates the demo fleets, users and vehicles. Runs only when Seed:Enabled is true.
/// Idempotent: if any user exists the database is treated as already seeded and nothing is written.
/// </summary>
public class DbSeeder(
    FleetDbContext db,
    IOptions<SeedOptions> options,
    IHostEnvironment environment,
    TimeProvider timeProvider,
    ILogger<DbSeeder> logger)
{
    private const string TarsusFleet = "Tarsus Field Ops";
    private const string AdanaFleet = "Adana Field Ops";

    public async Task SeedAsync(CancellationToken cancellationToken)
    {
        if (await db.Users.AnyAsync(cancellationToken))
        {
            logger.LogInformation("Database already contains users; skipping seed");
            return;
        }

        var now = timeProvider.GetUtcNow();

        var fleets = new Dictionary<string, VehicleFleet>
        {
            [TarsusFleet] = new() { Id = Guid.NewGuid(), Name = TarsusFleet, Region = "Tarsus" },
            [AdanaFleet] = new() { Id = Guid.NewGuid(), Name = AdanaFleet, Region = "Adana" },
        };
        db.Fleets.AddRange(fleets.Values);

        // Demo-only passwords, documented in the README.
        User[] users =
        [
            CreateUser("admin@demo.local", "Admin123!", "Demo Admin", Role.Admin, [], now),
            CreateUser("tarsus.operator@demo.local", "Operator123!", "Tarsus Operator", Role.Operator,
                [fleets[TarsusFleet]], now),
            CreateUser("adana.operator@demo.local", "Operator123!", "Adana Operator", Role.Operator,
                [fleets[AdanaFleet]], now),
        ];
        db.Users.AddRange(users);

        var devices = await ReadDevicesAsync(cancellationToken);
        foreach (var device in devices)
        {
            if (!fleets.TryGetValue(device.Fleet, out var fleet))
            {
                throw new InvalidOperationException(
                    $"Device {device.SerialNumber} refers to unknown fleet '{device.Fleet}'.");
            }

            db.Vehicles.Add(new Vehicle
            {
                Id = Guid.NewGuid(),
                FleetId = fleet.Id,
                Name = device.Name,
                Model = device.Model,
                SerialNumber = device.SerialNumber,
                DeviceKeyHash = DeviceKeyHasher.Hash(device.DeviceKey),
                CreatedAt = now,
                // No telemetry yet: the vehicle starts Offline with no location until its first sample.
                Connectivity = Connectivity.Offline,
            });
        }

        // One SaveChanges = one transaction, so a failed seed leaves no half-seeded database behind.
        await db.SaveChangesAsync(cancellationToken);
        logger.LogInformation("Seeded {FleetCount} fleets, {UserCount} users and {VehicleCount} vehicles",
            fleets.Count, users.Length, devices.Count);
    }

    private static User CreateUser(
        string email, string password, string displayName, Role role, VehicleFleet[] fleets, DateTimeOffset now)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = AuthService.NormalizeEmail(email),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password, AuthService.BcryptWorkFactor),
            DisplayName = displayName,
            Role = role,
            CreatedAt = now,
        };
        user.FleetAccess.AddRange(fleets.Select(f => new UserFleetAccess { UserId = user.Id, FleetId = f.Id }));
        return user;
    }

    private async Task<IReadOnlyList<SeedDevice>> ReadDevicesAsync(CancellationToken cancellationToken)
    {
        var path = Path.Combine(environment.ContentRootPath, options.Value.DevicesFile);
        await using var stream = File.OpenRead(path);
        var file = await JsonSerializer.DeserializeAsync<DevicesFile>(
            stream, JsonSerializerOptions.Web, cancellationToken);

        return file?.Vehicles ?? throw new InvalidOperationException($"No vehicles found in {path}.");
    }

    // Only the fields the seeder needs; the simulator reads the start position from the same file.
    private record DevicesFile(List<SeedDevice> Vehicles);

    private record SeedDevice(string SerialNumber, string Name, string Model, string Fleet, string DeviceKey);
}
