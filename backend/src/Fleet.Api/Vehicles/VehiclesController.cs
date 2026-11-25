using Microsoft.AspNetCore.Mvc;

namespace Fleet.Api.Vehicles;

[ApiController]
[Route("api/vehicles")]
public class VehiclesController(VehicleQueryService queries, TimeProvider timeProvider) : ControllerBase
{
    // An invalid ?status= value fails model binding, which [ApiController] turns into a 400 ProblemDetails.
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<VehicleDto>>> List(
        Guid? fleetId, VehicleStatus? status, CancellationToken cancellationToken) =>
        Ok(await queries.ListVehiclesAsync(User, fleetId, status, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<VehicleDto>> Get(Guid id, CancellationToken cancellationToken)
    {
        var vehicle = await queries.GetVehicleAsync(User, id, cancellationToken);
        return vehicle is null ? VehicleNotFound() : Ok(vehicle);
    }

    [HttpGet("{id:guid}/telemetry")]
    public async Task<ActionResult<TelemetryResponse>> Telemetry(
        Guid id, DateTimeOffset? from, DateTimeOffset? to, int? limit, CancellationToken cancellationToken)
    {
        // Npgsql only accepts UTC values for timestamptz parameters, so normalize any offset the client sent.
        var toUtc = (to ?? timeProvider.GetUtcNow()).ToUniversalTime();
        var fromUtc = (from ?? toUtc - HistoryLimits.TelemetryDefaultWindow).ToUniversalTime();

        if (fromUtc > toUtc)
        {
            ModelState.AddModelError(nameof(from), "'from' must not be later than 'to'.");
        }
        else if (toUtc - fromUtc > HistoryLimits.TelemetryMaxWindow)
        {
            ModelState.AddModelError(nameof(from),
                $"The range between 'from' and 'to' must not exceed {HistoryLimits.TelemetryMaxWindow.TotalDays} days.");
        }

        var effectiveLimit = ResolveLimit(limit, HistoryLimits.TelemetryDefaultLimit, HistoryLimits.TelemetryMaxLimit);
        if (!ModelState.IsValid)
        {
            return ValidationProblem();
        }

        var response = await queries.GetTelemetryAsync(User, id, fromUtc, toUtc, effectiveLimit, cancellationToken);
        return response is null ? VehicleNotFound() : Ok(response);
    }

    [HttpGet("{id:guid}/activity")]
    public async Task<ActionResult<ActivityPageResponse>> Activity(
        Guid id, string? before, int? limit, CancellationToken cancellationToken)
    {
        ActivityCursor? cursor = null;
        if (before is not null)
        {
            if (ActivityCursor.TryDecode(before, out var decoded))
            {
                cursor = decoded;
            }
            else
            {
                ModelState.AddModelError(nameof(before), "Invalid cursor. Pass back a 'nextBefore' value unchanged.");
            }
        }

        var effectiveLimit = ResolveLimit(limit, HistoryLimits.ActivityDefaultLimit, HistoryLimits.ActivityMaxLimit);
        if (!ModelState.IsValid)
        {
            return ValidationProblem();
        }

        var page = await queries.GetActivityAsync(User, id, cursor, effectiveLimit, cancellationToken);
        return page is null ? VehicleNotFound() : Ok(page);
    }

    /// <summary>Missing → default; below 1 → validation error; above max → clamped to max.</summary>
    private int ResolveLimit(int? limit, int defaultLimit, int maxLimit)
    {
        if (limit is < 1)
        {
            ModelState.AddModelError(nameof(limit), "'limit' must be at least 1.");
        }

        return Math.Min(limit ?? defaultLimit, maxLimit);
    }

    // Same response for "doesn't exist" and "not yours", so existence isn't leaked (assumption A10).
    private ObjectResult VehicleNotFound() =>
        Problem(statusCode: StatusCodes.Status404NotFound, title: "Vehicle not found.");
}
