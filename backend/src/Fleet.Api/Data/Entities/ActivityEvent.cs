namespace Fleet.Api.Data.Entities;

public class ActivityEvent
{
    public long Id { get; set; }
    public Guid VehicleId { get; set; }
    public ActivityEventType Type { get; set; }
    public DateTimeOffset OccurredAt { get; set; }

    /// <summary>Short human-readable text, e.g. "Idle → Moving".</summary>
    public required string Details { get; set; }
}
