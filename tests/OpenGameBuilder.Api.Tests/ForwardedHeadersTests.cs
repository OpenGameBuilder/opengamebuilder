using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace OpenGameBuilder.Api.Tests;

public sealed class ForwardedHeadersTests
{
    [Fact]
    public async Task HttpRequest_IsRedirectedToHttps()
    {
        await using var factory = new ApiFactory("Production");
        using var client = CreateHttpClient(factory);

        using var response = await client.GetAsync("/api/about", TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.TemporaryRedirect, response.StatusCode);
        Assert.Equal("https", response.Headers.Location?.Scheme);
    }

    [Fact]
    public async Task TrustedProxyHttpsHeader_PreventsAnHttpsRedirect()
    {
        await using var factory = new ApiFactory("Production");
        await using var trustedFactory = WithRemoteIp(factory, IPAddress.Loopback);
        using var client = CreateHttpClient(trustedFactory);
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/about");
        request.Headers.Add("X-Forwarded-Proto", "https");

        using var response = await client.SendAsync(request, TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task UntrustedProxyHttpsHeader_IsIgnored()
    {
        await using var factory = new ApiFactory("Production");
        await using var untrustedFactory = factory.WithWebHostBuilder(builder =>
            builder.ConfigureServices(services =>
            {
                services.AddSingleton<IStartupFilter>(new RemoteIpStartupFilter(IPAddress.Loopback));
                services.PostConfigure<ForwardedHeadersOptions>(options =>
                {
                    options.KnownIPNetworks.Clear();
                    options.KnownProxies.Clear();
                    options.KnownIPNetworks.Add(System.Net.IPNetwork.Parse("10.0.0.0/24"));
                });
            }));
        using var client = CreateHttpClient(untrustedFactory);
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/about");
        request.Headers.Add("X-Forwarded-Proto", "https");

        using var response = await client.SendAsync(request, TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.TemporaryRedirect, response.StatusCode);
    }

    private static HttpClient CreateHttpClient(WebApplicationFactory<Program> factory) =>
        factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false,
            BaseAddress = new Uri("http://localhost"),
        });

    private static WebApplicationFactory<Program> WithRemoteIp(
        WebApplicationFactory<Program> factory,
        IPAddress remoteIp) =>
        factory.WithWebHostBuilder(builder =>
            builder.ConfigureServices(services =>
                services.AddSingleton<IStartupFilter>(new RemoteIpStartupFilter(remoteIp))));

    private sealed class RemoteIpStartupFilter(IPAddress remoteIp) : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use((context, nextMiddleware) =>
            {
                context.Connection.RemoteIpAddress = remoteIp;
                return nextMiddleware();
            });
            next(app);
        };
    }
}
