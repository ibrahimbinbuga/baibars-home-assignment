namespace Fleet.Api.Data.Entities;

/// <summary>Grants an operator access to every vehicle in one fleet (assumption A1).</summary>
public class UserFleetAccess
{
    public Guid UserId { get; set; }
    public Guid FleetId { get; set; }

    public User? User { get; set; }
    public VehicleFleet? Fleet { get; set; }
}
