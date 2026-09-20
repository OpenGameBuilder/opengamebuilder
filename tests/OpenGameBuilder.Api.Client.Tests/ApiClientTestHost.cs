using System.Net;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using OpenGameBuilder.Api.Client.About;

namespace OpenGameBuilder.Api.Client.Tests;

internal sealed class ApiClientTestHost : IDisposable
{
    private readonly ConfigurationManager _configuration = new();
    private readonly StubHandler _handler;
    private readonly ServiceProvider _services;

    public ApiClientTestHost(
        Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send,
        string? baseUrl = "https://api.example.test/")
    {
        _configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["OpenGameBuilder:Api:BaseUrl"] = baseUrl
        });
        _handler = new StubHandler(send);
        var services = new ServiceCollection();
        services.AddOpenGameBuilderApiClient(_configuration);
        services.ConfigureHttpClientDefaults(http => http.ConfigurePrimaryHttpMessageHandler(() => _handler));
        _services = services.BuildServiceProvider(new ServiceProviderOptions
        {
            ValidateScopes = true,
            ValidateOnBuild = true
        });
    }

    public IAboutApiClient Client => _services.GetRequiredService<IAboutApiClient>();

    public static HttpResponseMessage JsonResponse(string json, HttpStatusCode status = HttpStatusCode.OK) =>
        new(status) { Content = new StringContent(json, Encoding.UTF8, "application/json") };

    public void Dispose()
    {
        _services.Dispose();
        _handler.Dispose();
        _configuration.Dispose();
    }

    private sealed class StubHandler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            send(request, cancellationToken);
    }
}
