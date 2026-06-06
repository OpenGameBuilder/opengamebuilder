using Microsoft.AspNetCore.Mvc;
using OpenGameBuilder.Api.Contracts.Diagnostics;

namespace OpenGameBuilder.Api.Controllers;

[ApiController]
[Route("/api/client-logs")]
public sealed class ClientLogsController(ILogger<ClientLogsController> logger) : ControllerBase
{
    private readonly ILogger<ClientLogsController> _logger = logger;

    [HttpPost(Name = "PostClientLog")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public IActionResult Post([FromBody] ClientLogEntry entry)
    {
        if (entry is null || string.IsNullOrWhiteSpace(entry.Message))
        {
            return BadRequest();
        }

        var level = ParseLevel(entry.Level);

#pragma warning disable CA2254 // Template should be a static expression - client message is forwarded telemetry.
        _logger.Log(
            level,
            "Browser client log [{ClientLevel}] from {ClientSource} at {ClientTimestamp}: {ClientMessage}{ClientExceptionType}{ClientStackTrace}",
            entry.Level,
            entry.Source ?? "(unknown)",
            entry.Timestamp,
            entry.Message,
            entry.ExceptionType is null ? string.Empty : $" | Exception: {entry.ExceptionType}",
            entry.StackTrace is null ? string.Empty : $"{Environment.NewLine}{entry.StackTrace}");
#pragma warning restore CA2254

        return NoContent();
    }

    private static LogLevel ParseLevel(string? level) => level?.Trim().ToLowerInvariant() switch
    {
        "critical" or "fatal" => LogLevel.Critical,
        "error" => LogLevel.Error,
        "warning" or "warn" => LogLevel.Warning,
        "information" or "info" => LogLevel.Information,
        "debug" => LogLevel.Debug,
        "trace" or "verbose" => LogLevel.Trace,
        _ => LogLevel.Error
    };
}
