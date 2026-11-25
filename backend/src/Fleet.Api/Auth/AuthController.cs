using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Fleet.Api.Auth;

[ApiController]
[Route("api/auth")]
public class AuthController(AuthService authService) : ControllerBase
{
    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(LoginRateLimiting.PolicyName)]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var response = await authService.LoginAsync(request.Email, request.Password, cancellationToken);
        if (response is null)
        {
            // Same answer for unknown email and wrong password, so the response doesn't reveal which one it was.
            return Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Invalid email or password.");
        }

        return Ok(response);
    }

    [HttpGet("me")]
    public async Task<ActionResult<MeResponse>> Me(CancellationToken cancellationToken)
    {
        var me = await authService.GetMeAsync(User, cancellationToken);
        if (me is null)
        {
            // Valid token, but the user has been deleted since it was issued.
            return Problem(statusCode: StatusCodes.Status401Unauthorized, title: "User no longer exists.");
        }

        return Ok(me);
    }
}
