using System.Net;
using System.Reflection;
using System.Text.Json;

namespace OpenGameBuilder.Api.Tests;

public sealed class AboutEndpointTests
{
    [Theory]
    [InlineData("Development")]
    [InlineData("Staging")]
    [InlineData("Production")]
    public async Task GetAbout_ReturnsApplicationMetadataInThePublicJsonContract(string environment)
    {
        await using var factory = new ApiFactory(environment);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/api/about", TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
        var about = json.RootElement;
        Assert.Equal("OpenGameBuilder", about.GetProperty("applicationName").GetString());
        var buildVersion = typeof(AboutEndpointTests).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()!.InformationalVersion;
        Assert.Equal(buildVersion, about.GetProperty("version").GetString());
        Assert.Equal(environment, about.GetProperty("apiEnvironmentName").GetString());
    }
}
