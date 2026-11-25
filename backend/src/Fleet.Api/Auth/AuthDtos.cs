using System.ComponentModel.DataAnnotations;
using Fleet.Api.Data.Entities;
using Fleet.Api.Vehicles;

namespace Fleet.Api.Auth;

public record LoginRequest([Required] string Email, [Required] string Password);

public record UserDto(Guid Id, string Email, string DisplayName, Role Role)
{
    public static UserDto From(User user) => new(user.Id, user.Email, user.DisplayName, user.Role);
}

public record LoginResponse(string AccessToken, DateTimeOffset ExpiresAt, UserDto User);

public record MeResponse(UserDto User, IReadOnlyList<FleetDto> Fleets);
