using System.Buffers.Text;
using System.Globalization;
using System.Text;

namespace Fleet.Api.Vehicles;

/// <summary>
/// Position in the activity list, sorted by (OccurredAt desc, Id desc). Id breaks ties when several events share
/// a timestamp, so paging never skips or repeats an event. Clients treat the encoded string as opaque.
/// </summary>
public readonly record struct ActivityCursor
{
    private const long TicksPerMicrosecond = 10;

    public ActivityCursor(DateTimeOffset occurredAt, long id)
    {
        // Postgres timestamptz stores microseconds; .NET has 100 ns ticks. Truncating here keeps the cursor equal to
        // what the database compares against, so boundary rows are neither skipped nor repeated.
        var utcTicks = occurredAt.UtcTicks;
        OccurredAt = new DateTimeOffset(utcTicks - utcTicks % TicksPerMicrosecond, TimeSpan.Zero);
        Id = id;
    }

    public DateTimeOffset OccurredAt { get; }
    public long Id { get; }

    /// <summary>Base64url of "{microseconds since 0001-01-01 UTC}_{id}".</summary>
    public string Encode()
    {
        var microseconds = OccurredAt.UtcTicks / TicksPerMicrosecond;
        return Base64Url.EncodeToString(Encoding.UTF8.GetBytes(
            string.Create(CultureInfo.InvariantCulture, $"{microseconds}_{Id}")));
    }

    /// <summary>False for anything this API did not produce (bad base64, wrong shape, out-of-range values).</summary>
    public static bool TryDecode(string value, out ActivityCursor cursor)
    {
        cursor = default;
        string text;
        try
        {
            text = Encoding.UTF8.GetString(Base64Url.DecodeFromChars(value));
        }
        catch (FormatException)
        {
            return false;
        }

        var parts = text.Split('_');
        if (parts.Length != 2
            || !long.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var microseconds)
            || !long.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var id)
            || microseconds > DateTimeOffset.MaxValue.UtcTicks / TicksPerMicrosecond
            || id < 1)
        {
            return false;
        }

        cursor = new ActivityCursor(new DateTimeOffset(microseconds * TicksPerMicrosecond, TimeSpan.Zero), id);
        return true;
    }
}
