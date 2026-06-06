namespace OpenGameBuilder.Api.Contracts.Diagnostics;

/// <summary>
/// Represents a single client-side (browser) log or error record forwarded from the
/// Blazor WebAssembly app to the API so it can be surfaced in the Aspire dashboard.
/// </summary>
public sealed record class ClientLogEntry
{
    /// <summary>Severity of the entry, for example "Error", "Warning", or "Information".</summary>
    public required string Level { get; init; }

    /// <summary>Human-readable message describing what happened.</summary>
    public required string Message { get; init; }

    /// <summary>Optional CLR exception type name when the entry originated from an exception.</summary>
    public string? ExceptionType { get; init; }

    /// <summary>Optional stack trace associated with the entry.</summary>
    public string? StackTrace { get; init; }

    /// <summary>Optional browser document URI where the entry was produced.</summary>
    public string? Source { get; init; }

    /// <summary>UTC timestamp captured on the client when the entry was produced.</summary>
    public DateTimeOffset Timestamp { get; init; }
}
