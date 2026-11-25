namespace Fleet.Api.Data.Entities;

public class User
{
    public Guid Id { get; set; }

    /// <summary>Always stored trimmed and lowercase, so lookups can use a plain equality on the unique index.</summary>
    public required string Email { get; set; }

    public required string PasswordHash { get; set; }
    public required string DisplayName { get; set; }
    public Role Role { get; set; }
    public DateTimeOffset CreatedAt { get; set; }

    public List<UserFleetAccess> FleetAccess { get; set; } = [];
}
