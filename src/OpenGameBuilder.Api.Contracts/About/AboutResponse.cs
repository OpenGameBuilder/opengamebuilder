namespace OpenGameBuilder.Api.Contracts.About;

public sealed record class AboutResponse
{
    public required string ApplicationName { get; init; }
    public required string Version { get; init; }
    public required string ApiEnvironmentName { get; init; }
}
