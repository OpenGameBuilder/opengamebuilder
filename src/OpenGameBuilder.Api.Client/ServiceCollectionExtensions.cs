using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using OpenGameBuilder.Api.Client.About;
using OpenGameBuilder.Api.Client.Options;

namespace OpenGameBuilder.Api.Client;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddOpenGameBuilderApiClient(this IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        services.AddOptions<OpenGameBuilderApiClientOptions>()
            .Bind(configuration.GetSection(OpenGameBuilderApiClientOptions.SectionName))
            .Validate(options => IsValidBaseUrl(options.BaseUrl), $"{OpenGameBuilderApiClientOptions.SectionName}:BaseUrl must be a valid absolute URL with HTTP or HTTPS scheme.");

        services.AddHttpClient<IAboutApiClient, AboutApiClient>((serviceProvider, httpClient) =>
        {
            var options = serviceProvider.GetRequiredService<IOptions<OpenGameBuilderApiClientOptions>>().Value;
            httpClient.BaseAddress = new Uri(options.BaseUrl);
        });

        return services;
    }

    public static bool IsValidBaseUrl(string baseUrl) =>
        !string.IsNullOrWhiteSpace(baseUrl) &&
        Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri) &&
        (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps);
}
