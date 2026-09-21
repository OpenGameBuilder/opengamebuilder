using System.Net;

namespace OpenGameBuilder.Api.Tests;

public sealed class DevelopmentEndpointTests
{
    [Theory]
    [InlineData("Development", "/health", HttpStatusCode.OK)]
    [InlineData("Development", "/alive", HttpStatusCode.OK)]
    [InlineData("Development", "/openapi/v1.json", HttpStatusCode.OK)]
    [InlineData("Development", "/scalar/v1", HttpStatusCode.OK)]
    [InlineData("Staging", "/health", HttpStatusCode.NotFound)]
    [InlineData("Staging", "/alive", HttpStatusCode.NotFound)]
    [InlineData("Staging", "/openapi/v1.json", HttpStatusCode.NotFound)]
    [InlineData("Staging", "/scalar/v1", HttpStatusCode.NotFound)]
    [InlineData("Production", "/health", HttpStatusCode.NotFound)]
    [InlineData("Production", "/alive", HttpStatusCode.NotFound)]
    [InlineData("Production", "/openapi/v1.json", HttpStatusCode.NotFound)]
    [InlineData("Production", "/scalar/v1", HttpStatusCode.NotFound)]
    public async Task DiagnosticEndpoints_AreOnlyExposedInDevelopment(string environment, string path, HttpStatusCode expectedStatus)
    {
        await using var factory = new ApiFactory(environment);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync(path, TestContext.Current.CancellationToken);

        Assert.Equal(expectedStatus, response.StatusCode);
    }
}
