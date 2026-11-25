using Fleet.Api.Data.Entities;

namespace Fleet.Api.Tests;

public class VehicleUpdatedAtTests
{
    private static readonly DateTimeOffset Previous = new(2026, 11, 25, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void LaterTime_IsUsed_TruncatedToMicroseconds()
    {
        var next = Vehicle.NextUpdatedAt(Previous, Previous.AddSeconds(1).AddTicks(7));

        Assert.Equal(Previous.AddSeconds(1), next);
    }

    [Fact]
    public void SameMicrosecond_StillAdvancesBy1Microsecond()
    {
        var next = Vehicle.NextUpdatedAt(Previous, Previous.AddTicks(5));

        Assert.Equal(Previous.AddMicroseconds(1), next);
    }

    [Fact]
    public void ClockSteppingBack_StillAdvances()
    {
        var next = Vehicle.NextUpdatedAt(Previous, Previous.AddMinutes(-3));

        Assert.Equal(Previous.AddMicroseconds(1), next);
    }
}
