using System.Security.Cryptography;
using System.Text;

namespace Fleet.Api.Telemetry;

public static class DeviceKeyHasher
{
    // Device keys are 256-bit random secrets, not passwords chosen by people, so brute-forcing a SHA-256 hash
    // is not realistic and a slow salted hash (BCrypt) adds nothing. A deterministic hash also lets ingestion
    // find the vehicle from the key with one indexed lookup, which a salted hash cannot do.
    public static string Hash(string deviceKey) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(deviceKey)));
}
