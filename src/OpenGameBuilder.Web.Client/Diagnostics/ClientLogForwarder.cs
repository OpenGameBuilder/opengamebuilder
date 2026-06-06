using System.Net.Http.Json;
using OpenGameBuilder.Api.Contracts.Diagnostics;
using OpenGameBuilder.Web.Client.Serialization;

namespace OpenGameBuilder.Web.Client.Diagnostics;

/// <summary>
/// Forwards browser-side log and error records to the API so they appear in the Aspire
/// dashboard. Failures while forwarding are swallowed (and written to the browser console)
/// to avoid recursive error reporting.
/// </summary>
internal sealed class ClientLogForwarder(HttpClient http, ILogger<ClientLogForwarder> logger)
{
    private const string Path = "api/client-logs";

    private readonly HttpClient _http = http;
    private readonly ILogger<ClientLogForwarder> _logger = logger;

    public async Task ReportAsync(ClientLogEntry entry, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entry);

        try
        {
            using var response = await _http.PostAsJsonAsync(
                Path,
                entry,
                WebClientJsonContext.Default.ClientLogEntry,
                cancellationToken).ConfigureAwait(false);

            response.EnsureSuccessStatusCode();
        }
        catch (Exception ex)
        {
            // Never let telemetry forwarding throw into the caller or loop back on itself.
            _logger.LogError(ex, "Failed to forward client log to the API.");
        }
    }

    public Task ReportExceptionAsync(Exception exception, string? source, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(exception);

        var entry = new ClientLogEntry
        {
            Level = "Error",
            Message = exception.Message,
            ExceptionType = exception.GetType().FullName,
            StackTrace = exception.StackTrace,
            Source = source,
            Timestamp = DateTimeOffset.UtcNow
        };

        return ReportAsync(entry, cancellationToken);
    }
}
