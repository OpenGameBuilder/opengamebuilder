namespace OpenGameBuilder.Api.Client.Options;

public sealed record class OpenGameBuilderApiClientOptions
{
    public const string SectionName = "OpenGameBuilder:Api";

    public required string BaseUrl { get; set; }
}
