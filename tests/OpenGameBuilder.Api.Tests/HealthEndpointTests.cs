using System.Net;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace OpenGameBuilder.Api.Tests;

public sealed class HealthEndpointTests
{
    [Theory]
    [InlineData("Development")]
    [InlineData("Staging")]
    [InlineData("Production")]
    public async Task PublicLiveness_IsAvailableInEveryDeploymentEnvironment(string environment)
    {
        await using var factory = new ApiFactory(environment);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/api/alive", TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/plain", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task PublicLiveness_DoesNotDependOnReadinessChecks()
    {
        await using var factory = new ApiFactory("Development");
        await using var unhealthyFactory = factory.WithWebHostBuilder(builder =>
            builder.ConfigureServices(services => services.AddHealthChecks()
                .AddCheck("unavailable-dependency", () => HealthCheckResult.Unhealthy("Readiness-only failure"))));
        using var client = unhealthyFactory.CreateClient();

        using var readiness = await client.GetAsync("/health", TestContext.Current.CancellationToken);
        using var liveness = await client.GetAsync("/api/alive", TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, readiness.StatusCode);
        Assert.Equal(HttpStatusCode.OK, liveness.StatusCode);
        Assert.Equal("Healthy", await liveness.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task PublicLiveness_ReportsFailureWithoutExposingHealthCheckDetails()
    {
        await using var factory = new ApiFactory("Production");
        await using var unhealthyFactory = factory.WithWebHostBuilder(builder =>
            builder.ConfigureServices(services => services.AddHealthChecks()
                .AddCheck("failed-live-check", () => HealthCheckResult.Unhealthy("Private diagnostic detail"), ["live"])));
        using var client = unhealthyFactory.CreateClient();

        using var response = await client.GetAsync("/api/alive", TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("text/plain", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal("Unhealthy", await response.Content.ReadAsStringAsync(TestContext.Current.CancellationToken));
    }
}
