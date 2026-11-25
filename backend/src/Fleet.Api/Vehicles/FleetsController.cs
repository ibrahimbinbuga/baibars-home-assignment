using Microsoft.AspNetCore.Mvc;

namespace Fleet.Api.Vehicles;

[ApiController]
[Route("api/fleets")]
public class FleetsController(VehicleQueryService queries) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<FleetDto>>> List(CancellationToken cancellationToken) =>
        Ok(await queries.ListFleetsAsync(User, cancellationToken));
}
