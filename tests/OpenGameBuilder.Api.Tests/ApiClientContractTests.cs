using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using OpenGameBuilder.Api.Client;
using OpenGameBuilder.Api.Client.About;

namespace OpenGameBuilder.Api.Tests;

public sealed class ApiClientContractTests
{
    [Theory]
    [InlineData("Development")]
    [InlineData("Staging")]
    [InlineData("Production")]
    public async Task RegisteredClient_CanReadTheRealApiResponse(string environment)
    {
        await using var factory = new ApiFactory(environment);
        using var configuration = new ConfigurationManager
        {
            ["OpenGameBuilder:Api:BaseUrl"] = "https://localhost/"
        };
        var services = new ServiceCollection();
        services.AddOpenGameBuilderApiClient(configuration);
        services.ConfigureHttpClientDefaults(http =>
            http.ConfigurePrimaryHttpMessageHandler(factory.Server.CreateHandler));
        await using var provider = services.BuildServiceProvider(new ServiceProviderOptions
        {
            ValidateScopes = true,
            ValidateOnBuild = true
        });
        var client = provider.GetRequiredService<IAboutApiClient>();

        var about = await client.GetAboutAsync(TestContext.Current.CancellationToken);

        Assert.Equal("OpenGameBuilder", about.ApplicationName);
        Assert.False(string.IsNullOrWhiteSpace(about.Version));
        Assert.Equal(environment, about.ApiEnvironmentName);
    }
}
