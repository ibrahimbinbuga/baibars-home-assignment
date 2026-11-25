using System.ComponentModel.DataAnnotations;

namespace Fleet.Api.Data;

public class SeedOptions : IValidatableObject
{
    public const string SectionName = "Seed";

    /// <summary>Off by default. Turned on in appsettings.Development.json and in docker-compose (demo only).</summary>
    public bool Enabled { get; set; }

    /// <summary>Path to devices.json. A relative path is resolved against the content root.</summary>
    public string DevicesFile { get; set; } = "";

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Enabled && string.IsNullOrWhiteSpace(DevicesFile))
        {
            yield return new ValidationResult("Seed:DevicesFile is required when Seed:Enabled is true.");
        }
    }
}
