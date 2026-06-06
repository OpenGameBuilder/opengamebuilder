namespace OpenGameBuilder.Api.Options;

public sealed record class CorsOptions
{
    public const string SectionName = "Cors";

    public string[] AllowedOrigins { get; set; } = [];
}
