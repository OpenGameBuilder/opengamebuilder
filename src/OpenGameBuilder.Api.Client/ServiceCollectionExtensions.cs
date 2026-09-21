using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using OpenGameBuilder.Api.Client.About;
using OpenGameBuilder.Api.Client.Options;

namespace OpenGameBuilder.Api.Client;

public static class ServiceCollectionExtensions
{
    extension(IServiceCollection services)
    {
        public IServiceCollection AddOpenGameBuilderApiClient(IConfiguration configuration, Uri? applicationBaseAddress = null)
        {
            ArgumentNullException.ThrowIfNull(services);
            ArgumentNullException.ThrowIfNull(configuration);
            if (applicationBaseAddress is not null &&
                (!applicationBaseAddress.IsAbsoluteUri ||
                 (applicationBaseAddress.Scheme != Uri.UriSchemeHttp && applicationBaseAddress.Scheme != Uri.UriSchemeHttps)))
            {
                throw new ArgumentException("The application base address must be an absolute HTTP or HTTPS URL.", nameof(applicationBaseAddress));
            }

            services.AddOptions<OpenGameBuilderApiClientOptions>()
                .Bind(configuration.GetSection(OpenGameBuilderApiClientOptions.SectionName))
                .PostConfigure(options =>
                {
                    if (configuration[$"{OpenGameBuilderApiClientOptions.SectionName}:BaseUrl"] is null && applicationBaseAddress is not null)
                    {
                        options.BaseUrl = applicationBaseAddress.AbsoluteUri;
                    }
                })
                .Validate(options => IsValidBaseUrl(options.BaseUrl), $"{OpenGameBuilderApiClientOptions.SectionName}:BaseUrl must be a valid absolute URL with HTTP or HTTPS scheme.");

            services.AddHttpClient<IAboutApiClient, AboutApiClient>((serviceProvider, httpClient) =>
            {
                var options = serviceProvider.GetRequiredService<IOptions<OpenGameBuilderApiClientOptions>>().Value;
                httpClient.BaseAddress = new Uri(options.BaseUrl);
            });

            return services;
        }

        private static bool IsValidBaseUrl(string baseUrl) =>
            !string.IsNullOrWhiteSpace(baseUrl) &&
            Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri) &&
            (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps);
    }
}
