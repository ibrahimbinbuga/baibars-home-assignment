using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace Fleet.Api.Telemetry;

[ApiController]
[Route("api/ingest")]
[Authorize(AuthenticationSchemes = DeviceKeyAuthenticationHandler.SchemeName)]
public class IngestController(
    TelemetryIngestionService ingestion,
    TimeProvider timeProvider,
    IOptions<TelemetryOptions> options) : ControllerBase
{
    [HttpPost("telemetry")]
    public async Task<IActionResult> Telemetry(IngestTelemetryRequest request, CancellationToken cancellationToken)
    {
        // Clock skew guard: a device whose clock runs far ahead would otherwise "own" the latest state.
        var maxSkew = TimeSpan.FromSeconds(options.Value.MaxClockSkewSeconds);
        if (request.RecordedAt > timeProvider.GetUtcNow() + maxSkew)
        {
            ModelState.AddModelError(nameof(request.RecordedAt),
                $"'recordedAt' must not be more than {maxSkew.TotalMinutes} minutes in the future.");
            return ValidationProblem();
        }

        // The vehicle comes from the device key, never from the request body.
        var vehicleId = Guid.Parse(User.FindFirstValue(DeviceKeyAuthenticationHandler.VehicleIdClaim)!);

        var result = await ingestion.IngestAsync(vehicleId, request.ToSample(), cancellationToken);
        return result switch
        {
            IngestResult.Accepted => Accepted(new IngestResponse(Duplicate: false)),
            IngestResult.Duplicate => Ok(new IngestResponse(Duplicate: true)),
            _ => Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Vehicle state is being updated concurrently.",
                detail: "Retry the same sample; it will not be stored twice."),
        };
    }
}
