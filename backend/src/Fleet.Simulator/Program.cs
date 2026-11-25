using System.ComponentModel.DataAnnotations;
using Fleet.Simulator;
using Microsoft.Extensions.Options;

// Stands in for real vehicles: posts telemetry to the API with each vehicle's device key (CLAUDE.md Section 10).
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddOptions<SimulatorOptions>()
    .Bind(builder.Configuration.GetSection(SimulatorOptions.SectionName))
    // Same checks as ValidateDataAnnotations(), without adding the Options.DataAnnotations package.
    .Validate(
        o => Validator.TryValidateObject(o, new ValidationContext(o), null, validateAllProperties: true),
        "Invalid 'Simulator' settings: check ApiBaseUrl, DevicesFile, IntervalSeconds and dropout values.")
    .ValidateOnStart();

// One shared HttpClient for all vehicles (the recommended way to use HttpClient).
builder.Services.AddSingleton(services => new HttpClient
{
    BaseAddress = new Uri(services.GetRequiredService<IOptions<SimulatorOptions>>().Value.ApiBaseUrl),
    Timeout = TimeSpan.FromSeconds(10),
});
builder.Services.AddSingleton<TelemetrySender>();
builder.Services.AddHostedService<SimulatorWorker>();

builder.Build().Run();
