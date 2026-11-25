using System.Text;
using Fleet.Api.Auth;
using Fleet.Api.Common;
using Fleet.Api.Data;
using Fleet.Api.Realtime;
using Fleet.Api.Telemetry;
using Fleet.Api.Vehicles;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddControllers()
    .AddJsonOptions(o => JsonConfiguration.Apply(o.JsonSerializerOptions));
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

// JWT is the default scheme (users). Devices use their own scheme, only on the ingest endpoint.
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer()
    .AddScheme<AuthenticationSchemeOptions, DeviceKeyAuthenticationHandler>(DeviceKeyAuthenticationHandler.SchemeName, null);
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
        bearer.Events = new JwtBearerEvents
        {
            // WebSocket clients (incl. the mobile SignalR client) can't always send an Authorization header, so they
            // pass the token as ?access_token=. Accept that ONLY for the hub path: everywhere else a token must be in
            // the header, so tokens don't end up in URLs (and logs) for normal REST calls.
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"].ToString();
                if (!string.IsNullOrEmpty(accessToken) && context.HttpContext.Request.Path.StartsWithSegments(FleetHub.Path))
                {
                    context.Token = accessToken;
                }

                return Task.CompletedTask;
            },
            // The user must still exist; their role comes from the database (see CurrentUserValidation).
            OnTokenValidated = CurrentUserValidation.OnTokenValidatedAsync,
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
builder.Services.AddScoped<VehicleQueryService>();

// --- Telemetry & real-time ---
builder.Services.AddOptions<TelemetryOptions>()
    .Bind(builder.Configuration.GetSection(TelemetryOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();
builder.Services.AddScoped<TelemetryIngestionService>();
builder.Services.AddScoped<OfflineDetector>();
builder.Services.AddHostedService<OfflineDetectorService>();
builder.Services.AddScoped<FleetChangePublisher>();
builder.Services.AddSignalR().AddJsonProtocol(o => JsonConfiguration.Apply(o.PayloadSerializerOptions));
builder.Services.AddSingleton<SignalRFleetBroadcaster>();
builder.Services.AddSingleton<IFleetBroadcaster>(services => services.GetRequiredService<SignalRFleetBroadcaster>());

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
// CloseOnAuthenticationExpiration: the connection is closed when the JWT it was opened with expires, instead of
// staying open (and receiving data) indefinitely. The app then reconnects, which requires a valid token.
app.MapHub<FleetHub>(FleetHub.Path, options => options.CloseOnAuthenticationExpiration = true);
// Anonymous so the simulator and container tooling can reach it without a token.
app.MapHealthChecks("/health").AllowAnonymous();

app.Run();
