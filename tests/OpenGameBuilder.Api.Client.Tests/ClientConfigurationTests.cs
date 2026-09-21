using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace OpenGameBuilder.Api.Client.Tests;

public sealed class ClientConfigurationTests
{
    [Theory]
    [InlineData("https://api.example.test", "https://api.example.test/api/about")]
    [InlineData("http://api.example.test/", "http://api.example.test/api/about")]
    [InlineData("https://api.example.test/game/", "https://api.example.test/game/api/about")]
    public async Task RegisteredClient_UsesTheConfiguredBaseAddressAndGetRoute(string baseUrl, string expectedUrl)
    {
        using var host = new ApiClientTestHost((request, _) =>
        {
            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.Equal(new Uri(expectedUrl), request.RequestUri);
            return Task.FromResult(ApiClientTestHost.JsonResponse("""
                {"applicationName":"Fixture","version":"1.0.0","apiEnvironmentName":"Testing"}
                """));
        }, baseUrl);

        await host.Client.GetAboutAsync(TestContext.Current.CancellationToken);
    }

    [Theory]
    [InlineData("https://fork.example.test/", "https://fork.example.test/api/about")]
    [InlineData("https://staging.example.test/", "https://staging.example.test/api/about")]
    [InlineData("https://fork.example.test/game/", "https://fork.example.test/game/api/about")]
    public async Task RegisteredClient_UsesHostingOriginWhenNoOverrideExists(string pageUrl, string expectedUrl)
    {
        using var host = new ApiClientTestHost((request, _) =>
        {
            Assert.Equal(new Uri(expectedUrl), request.RequestUri);
            return Task.FromResult(ApiClientTestHost.JsonResponse("""
                {"applicationName":"Fixture","version":"1.0.0","apiEnvironmentName":"Testing"}
                """));
        }, null, new Uri(pageUrl));

        await host.Client.GetAboutAsync(TestContext.Current.CancellationToken);
    }

    [Fact]
    public async Task RegisteredClient_PrefersExplicitDevelopmentOverride()
    {
        using var host = new ApiClientTestHost((request, _) =>
        {
            Assert.Equal(new Uri("https://localhost:7000/api/about"), request.RequestUri);
            return Task.FromResult(ApiClientTestHost.JsonResponse("""
                {"applicationName":"Fixture","version":"1.0.0","apiEnvironmentName":"Development"}
                """));
        }, "https://localhost:7000/", new Uri("https://localhost:7001/"));

        await host.Client.GetAboutAsync(TestContext.Current.CancellationToken);
    }

    [Fact]
    public void RegisteredClient_DoesNotSilentlyReplaceAnExplicitEmptyOverride()
    {
        using var host = new ApiClientTestHost((_, _) => throw new InvalidOperationException("No HTTP request is expected"),
            "", new Uri("https://fork.example.test/"));

        Assert.Throws<OptionsValidationException>(() => host.Client);
    }

    [Theory]
    [InlineData("/relative")]
    [InlineData("file:///local")]
    public void Registration_RejectsInvalidApplicationBaseAddress(string address)
    {
        var services = new ServiceCollection();
        using var configuration = new ConfigurationManager();

        Assert.Throws<ArgumentException>(() => services.AddOpenGameBuilderApiClient(configuration, new Uri(address, UriKind.RelativeOrAbsolute)));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("/api/")]
    [InlineData("api.example.test")]
    [InlineData("https://")]
    [InlineData("ftp://api.example.test/")]
    [InlineData("file:///local-api")]
    public void RegisteredClient_RejectsMissingOrInvalidBaseAddresses(string? baseUrl)
    {
        using var host = new ApiClientTestHost((_, _) => throw new InvalidOperationException("No HTTP request is expected"), baseUrl);

        var exception = Assert.Throws<OptionsValidationException>(() => host.Client);

        Assert.Contains(exception.Failures, failure => failure.Contains("OpenGameBuilder:Api:BaseUrl", StringComparison.Ordinal));
    }

    [Fact]
    public void Registration_RejectsNullConfiguration()
    {
        var services = new ServiceCollection();

        var exception = Assert.Throws<ArgumentNullException>(() => services.AddOpenGameBuilderApiClient(null!));

        Assert.Equal("configuration", exception.ParamName);
    }

    [Fact]
    public void Registration_RejectsNullServices()
    {
        IServiceCollection services = null!;
        using var configuration = new ConfigurationManager();

        var exception = Assert.Throws<ArgumentNullException>(() => services.AddOpenGameBuilderApiClient(configuration));

        Assert.Equal("services", exception.ParamName);
    }
}
