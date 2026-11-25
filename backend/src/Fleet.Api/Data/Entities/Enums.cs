namespace Fleet.Api.Data.Entities;

public enum Role
{
    Admin,
    Operator,
}

/// <summary>State reported by the vehicle itself.</summary>
public enum VehicleState
{
    Moving,
    Idle,
    Charging,
    Fault,
}

/// <summary>Decided by the server from when it last heard from the vehicle.</summary>
public enum Connectivity
{
    Online,
    Offline,
}

public enum ActivityEventType
{
    CameOnline,
    WentOffline,
    StateChanged,
    LowBattery,
    FaultRaised,
}
