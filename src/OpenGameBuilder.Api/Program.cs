using Microsoft.AspNetCore.HttpOverrides;
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
if (!builder.Environment.IsDevelopment())
{
    builder.Services.AddHttpsRedirection(options => options.HttpsPort = 443);
}

var trustedProxyNetworks = builder.Configuration["ReverseProxy:KnownNetworks"]?
    .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries) ?? [];
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.ForwardLimit = 1;

    foreach (var networkText in trustedProxyNetworks)
    {
        if (!System.Net.IPNetwork.TryParse(networkText, out var network))
        {
            throw new InvalidOperationException($"ReverseProxy:KnownNetworks contains invalid CIDR '{networkText}'.");
        }

        options.KnownIPNetworks.Add(network);
    }
});

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

// Caddy terminates HTTPS and is the only deployed proxy. Process its headers
// before redirect, authentication, or endpoint middleware reads scheme/client IP.
app.UseForwardedHeaders();

// Map default Aspire endpoints: a public liveness probe at /api/alive in every environment
// (reachable through the Caddy edge "/api/*" proxy), plus the verbose /health and /alive
// endpoints in development only.
app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();

// CORS must run before authorization and endpoint execution for local Development's
// separate web/API origins. Deployed clients use their own origin through /api.
app.UseCors();

app.UseAuthorization();

app.MapControllers();

app.Run();
