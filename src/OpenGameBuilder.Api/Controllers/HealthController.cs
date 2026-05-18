using System.Reflection;

using Microsoft.AspNetCore.Mvc;

namespace OpenGameBuilder.Api.Controllers;

/// <summary>
/// Lightweight liveness/about endpoint used by load balancers, uptime checks,
/// and for confirming which build is deployed.
/// </summary>
[ApiController]
[Route("[controller]")]
public sealed class HealthController : ControllerBase
{
    private static readonly string s_version =
        Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "0.0.0";

    [HttpGet(Name = "GetHealth")]
    [ProducesResponseType(typeof(HealthResponse), StatusCodes.Status200OK)]
    public ActionResult<HealthResponse> Get()
    {
        return Ok(new HealthResponse(
            Status: "Healthy",
            Service: "OpenGameBuilder.Api",
            Version: s_version,
            TimestampUtc: DateTimeOffset.UtcNow));
    }
}

public sealed record HealthResponse(
    string Status,
    string Service,
    string Version,
    DateTimeOffset TimestampUtc);
