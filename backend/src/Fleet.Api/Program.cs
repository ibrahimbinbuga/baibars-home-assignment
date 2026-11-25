using System.Text;
using System.Text.Json.Serialization;
using Fleet.Api.Auth;
using Fleet.Api.Data;
using Fleet.Api.Vehicles;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddProblemDetails();
builder.Services.AddOpenApi();
builder.Services.AddSingleton(TimeProvider.System);

// --- Database ---
// The connection string is read when the DbContext is first created (not here), so tests can override it.
builder.Services.AddDbContext<FleetDbContext>((services, options) =>
{
    var connectionString = services.GetRequiredService<IConfiguration>().GetConnectionString("Fleet")
        ?? throw new InvalidOperationException("ConnectionStrings:Fleet is not configured.");
    options.UseNpgsql(connectionString);
});
builder.Services.AddOptions<SeedOptions>()
    .Bind(builder.Configuration.GetSection(SeedOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();
builder.Services.AddScoped<DbSeeder>();
builder.Services.AddHostedService<DatabaseInitializer>();

// --- Authentication ---
builder.Services.AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection(JwtOptions.SectionName))
    .ValidateDataAnnotations()
    .Validate(JwtOptions.HasValidKeyLength,
        $"Jwt:SigningKey must be at least {JwtOptions.MinimumSigningKeyBytes} bytes for HS256.")
    .ValidateOnStart();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<JwtOptions>>((bearer, jwtOptions) =>
    {
        var jwt = jwtOptions.Value;
        // Keep the claim names from the token ("sub", "role") instead of mapping them to long Microsoft URIs.
        bearer.MapInboundClaims = false;
        bearer.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            NameClaimType = JwtRegisteredClaimNames.Sub,
            RoleClaimType = AuthClaims.Role,
            ClockSkew = TimeSpan.FromSeconds(30),
        };
    });

// Every endpoint requires a logged-in user unless it explicitly opts out with [AllowAnonymous].
// Safer default: a new endpoint can't be exposed by forgetting an attribute.
builder.Services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

builder.Services.AddLoginRateLimiting(builder.Configuration);
builder.Services.AddScoped<JwtTokenIssuer>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<IVehicleAccessService, VehicleAccessService>();

builder.Services.AddHealthChecks().AddDbContextCheck<FleetDbContext>();

var app = builder.Build();

// Unhandled exceptions and bare error status codes (401, 404, 429, ...) become RFC 7807 ProblemDetails.
// Stack traces are never returned, regardless of environment.
app.UseExceptionHandler();
app.UseStatusCodePages();

// Swagger is controlled by an explicit flag instead of the environment name, because the Docker
// setup runs as Production (no developer exception page) but still wants Swagger for the demo.
if (app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.MapOpenApi().AllowAnonymous();
    app.UseSwaggerUI(options => options.SwaggerEndpoint("/openapi/v1.json", "Fleet API v1"));
}

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapControllers();
// Anonymous so the simulator and container tooling can reach it without a token.
app.MapHealthChecks("/health").AllowAnonymous();

app.Run();
