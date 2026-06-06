using OpenGameBuilder.Api.Options;
using OpenGameBuilder.ServiceDefaults;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add .NET Aspire service defaults (OpenTelemetry, health checks, service discovery, resilient HTTP).
builder.AddServiceDefaults();

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var corsOptions = builder.Configuration.GetSection(CorsOptions.SectionName).Get<CorsOptions>() ?? new();

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(corsOptions.AllowedOrigins)
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Map default Aspire endpoints (health checks at /health and /alive in development).
app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();

// CORS must run before authorization and endpoint execution so the configured
// Access-Control-* headers are written for both the browser's preflight (OPTIONS)
// request and the actual response. The standalone Blazor WebAssembly client calls
// this API from a different origin (https://localhost:7001) in every environment,
// so the default policy is applied unconditionally rather than only in Development.
app.UseCors();

app.UseAuthorization();

app.MapControllers();

app.Run();
