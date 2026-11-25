using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Threading.RateLimiting;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Auth;

public class LoginRateLimitOptions
{
    public const string SectionName = "RateLimiting:Login";

    [Range(1, 10_000)] public int PermitLimit { get; set; } = 5;
    [Range(1, 3600)] public int WindowSeconds { get; set; } = 60;
}

public static class LoginRateLimiting
{
    public const string PolicyName = "login";

    /// <summary>Fixed window per client IP, applied only to POST /api/auth/login (slows down password guessing).</summary>
    public static IServiceCollection AddLoginRateLimiting(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<LoginRateLimitOptions>()
            .Bind(configuration.GetSection(LoginRateLimitOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddRateLimiter(limiter =>
        {
            // The body is left empty on purpose: UseStatusCodePages turns the bare 429 into ProblemDetails.
            limiter.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            // Tell the client how long to wait, so the app can show a countdown instead of guessing. The fixed-window
            // limiter reports the full window length here (not the time left), so this is a safe upper bound.
            limiter.OnRejected = (context, _) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                {
                    var seconds = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds));
                    context.HttpContext.Response.Headers.RetryAfter = seconds.ToString(CultureInfo.InvariantCulture);
                }

                return ValueTask.CompletedTask;
            };

            limiter.AddPolicy(PolicyName, httpContext =>
            {
                var options = httpContext.RequestServices.GetRequiredService<IOptions<LoginRateLimitOptions>>().Value;

                // Behind a reverse proxy this would be the proxy's IP; see DECISIONS.md (forwarded headers).
                var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";

                return RateLimitPartition.GetFixedWindowLimiter(clientIp, _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = options.PermitLimit,
                    Window = TimeSpan.FromSeconds(options.WindowSeconds),
                    QueueLimit = 0,
                });
            });
        });

        return services;
    }
}
