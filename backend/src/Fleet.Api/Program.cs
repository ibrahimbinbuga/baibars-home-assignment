var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddOpenApi();

// Liveness only for now; the database check is added together with the DbContext (Phase 1).
builder.Services.AddHealthChecks();

var app = builder.Build();

// Unhandled exceptions and bare error status codes (404, 401, ...) become RFC 7807 ProblemDetails.
// Stack traces are never returned, regardless of environment.
app.UseExceptionHandler();
app.UseStatusCodePages();

// Swagger is controlled by an explicit flag instead of the environment name, because the Docker
// setup runs as Production (no developer exception page) but still wants Swagger for the demo.
if (app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.MapOpenApi();
    app.UseSwaggerUI(options => options.SwaggerEndpoint("/openapi/v1.json", "Fleet API v1"));
}

app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
