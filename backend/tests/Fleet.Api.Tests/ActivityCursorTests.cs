using Fleet.Api.Vehicles;

namespace Fleet.Api.Tests;

public class ActivityCursorTests
{
    [Fact]
    public void Encode_ThenDecode_RoundTrips()
    {
        var cursor = new ActivityCursor(new DateTimeOffset(2026, 11, 20, 12, 0, 0, TimeSpan.Zero).AddMicroseconds(7), 42);

        Assert.True(ActivityCursor.TryDecode(cursor.Encode(), out var decoded));
        Assert.Equal(cursor, decoded);
    }

    [Fact]
    public void Constructor_TruncatesToMicroseconds_AndNormalizesToUtc()
    {
        var withTicks = new DateTimeOffset(2026, 11, 20, 15, 0, 0, TimeSpan.FromHours(3)).AddTicks(9);

        var cursor = new ActivityCursor(withTicks, 1);

        Assert.Equal(new DateTimeOffset(2026, 11, 20, 12, 0, 0, TimeSpan.Zero), cursor.OccurredAt);
        Assert.Equal(TimeSpan.Zero, cursor.OccurredAt.Offset);
    }
}
