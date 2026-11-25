using System.ComponentModel.DataAnnotations;
using System.Text;

namespace Fleet.Api.Auth;

public class JwtOptions
{
    public const string SectionName = "Jwt";

    // HS256 needs a key of at least 256 bits. A shorter key is a configuration error, so the app refuses to start.
    public const int MinimumSigningKeyBytes = 32;

    [Required] public string Issuer { get; set; } = "";
    [Required] public string Audience { get; set; } = "";
    [Required] public string SigningKey { get; set; } = "";
    [Range(1, 24 * 60)] public int LifetimeMinutes { get; set; } = 60;

    public static bool HasValidKeyLength(JwtOptions options) =>
        Encoding.UTF8.GetByteCount(options.SigningKey) >= MinimumSigningKeyBytes;
}
