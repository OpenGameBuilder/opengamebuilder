using System.Net.Http.Json;
using OpenGameBuilder.Api.Client.Serialization;
using OpenGameBuilder.Api.Contracts.About;

namespace OpenGameBuilder.Api.Client.About;

internal sealed class AboutApiClient(HttpClient http) : IAboutApiClient
{
    private const string Path = "api/about";

    private readonly HttpClient _http = http;

    public async Task<AboutResponse> GetAboutAsync(CancellationToken cancellationToken = default)
    {
        var about = await _http.GetFromJsonAsync(Path, OpenGameBuilderApiJsonContext.Default.AboutResponse, cancellationToken)
            .ConfigureAwait(false);

        return about ?? throw new InvalidOperationException("Failed to get about information from the API.");
    }
}
