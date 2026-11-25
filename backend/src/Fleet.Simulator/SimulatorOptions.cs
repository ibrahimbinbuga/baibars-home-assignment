using System.ComponentModel.DataAnnotations;

namespace Fleet.Simulator;

public class SimulatorOptions
{
    public const string SectionName = "Simulator";

    [Required, Url] public string ApiBaseUrl { get; set; } = "";

    /// <summary>Path to devices.json; relative paths are resolved against the current directory.</summary>
    [Required] public string DevicesFile { get; set; } = "";

    [Range(1, 60)] public int IntervalSeconds { get; set; } = 2;

    /// <summary>Serial of the vehicle that periodically stops reporting, to demo offline detection. Empty = none.</summary>
    public string? DropoutSerial { get; set; }

    [Range(10, 3600)] public int DropoutEverySeconds { get; set; } = 180;
    [Range(1, 600)] public int DropoutDurationSeconds { get; set; } = 45;
}
