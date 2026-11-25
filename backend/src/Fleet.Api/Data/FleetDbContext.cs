using Fleet.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace Fleet.Api.Data;

public class FleetDbContext(DbContextOptions<FleetDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<VehicleFleet> Fleets => Set<VehicleFleet>();
    public DbSet<UserFleetAccess> UserFleetAccess => Set<UserFleetAccess>();
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<TelemetryRecord> TelemetryRecords => Set<TelemetryRecord>();
    public DbSet<ActivityEvent> ActivityEvents => Set<ActivityEvent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(FleetDbContext).Assembly);
    }
}
