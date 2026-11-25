namespace Fleet.Api.Data.Entities;

// Named VehicleFleet (not Fleet) because a type called Fleet would clash with the root namespace "Fleet".
// The table and the API still call it "fleet".
public class VehicleFleet
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public required string Region { get; set; }

    public List<Vehicle> Vehicles { get; set; } = [];
}
