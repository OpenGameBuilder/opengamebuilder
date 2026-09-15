using System.Net;
using System.Text.Json;

namespace OpenGameBuilder.Api.Client.Tests;

public sealed class AboutApiClientTests
{
    private const string ValidJson = """
        {"applicationName":"Fixture application","version":"2.3.4-test","apiEnvironmentName":"Testing"}
        """;

    [Theory]
    [InlineData(ValidJson)]
    [InlineData("""{"ApplicationName":"Fixture application","Version":"2.3.4-test","ApiEnvironmentName":"Testing","futureField":true}""")]
    public async Task GetAbout_DeserializesThePublicJsonContract(string json)
    {
        using var host = new ApiClientTestHost((_, _) => Task.FromResult(ApiClientTestHost.JsonResponse(json)));

        var about = await host.Client.GetAboutAsync(TestContext.Current.CancellationToken);

        Assert.Equal("Fixture application", about.ApplicationName);
        Assert.Equal("2.3.4-test", about.Version);
        Assert.Equal("Testing", about.ApiEnvironmentName);
    }

    [Theory]
    [InlineData("""{"applicationName":null,"version":"2.3.4","apiEnvironmentName":"Testing"}""")]
    [InlineData("""{"applicationName":"Fixture","version":null,"apiEnvironmentName":"Testing"}""")]
    [InlineData("""{"applicationName":"Fixture","version":"2.3.4","apiEnvironmentName":null}""")]
    public async Task GetAbout_RejectsNullRequiredFields(string json)
    {
        using var host = new ApiClientTestHost((_, _) => Task.FromResult(ApiClientTestHost.JsonResponse(json)));

        await Assert.ThrowsAsync<JsonException>(() => host.Client.GetAboutAsync(TestContext.Current.CancellationToken));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("not json")]
    [InlineData("{")]
    [InlineData("[]")]
    [InlineData("{}")]
    [InlineData("""{"version":"2.3.4","apiEnvironmentName":"Testing"}""")]
    [InlineData("""{"applicationName":"Fixture","apiEnvironmentName":"Testing"}""")]
    [InlineData("""{"applicationName":"Fixture","version":"2.3.4"}""")]
    [InlineData("""{"applicationName":42,"version":"2.3.4","apiEnvironmentName":"Testing"}""")]
    public async Task GetAbout_RejectsMalformedEmptyOrIncompleteJson(string json)
    {
        using var host = new ApiClientTestHost((_, _) => Task.FromResult(ApiClientTestHost.JsonResponse(json)));

        await Assert.ThrowsAsync<JsonException>(() => host.Client.GetAboutAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task GetAbout_RejectsAJsonNullResponse()
    {
        using var host = new ApiClientTestHost((_, _) => Task.FromResult(ApiClientTestHost.JsonResponse("null")));

        await Assert.ThrowsAsync<InvalidOperationException>(() => host.Client.GetAboutAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task GetAbout_RejectsNoContent()
    {
        using var host = new ApiClientTestHost((_, _) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.NoContent)));

        await Assert.ThrowsAsync<JsonException>(() => host.Client.GetAboutAsync(TestContext.Current.CancellationToken));
    }

    [Theory]
    [InlineData(HttpStatusCode.BadRequest)]
    [InlineData(HttpStatusCode.Unauthorized)]
    [InlineData(HttpStatusCode.NotFound)]
    [InlineData(HttpStatusCode.TooManyRequests)]
    [InlineData(HttpStatusCode.InternalServerError)]
    [InlineData(HttpStatusCode.ServiceUnavailable)]
    public async Task GetAbout_PropagatesHttpFailureStatus(HttpStatusCode status)
    {
        using var host = new ApiClientTestHost((_, _) => Task.FromResult(ApiClientTestHost.JsonResponse(ValidJson, status)));

        var exception = await Assert.ThrowsAsync<HttpRequestException>(() => host.Client.GetAboutAsync(TestContext.Current.CancellationToken));

        Assert.Equal(status, exception.StatusCode);
    }

    [Fact]
    public async Task GetAbout_PropagatesTransportFailure()
    {
        using var host = new ApiClientTestHost((_, _) => throw new HttpRequestException("Simulated connection failure"));

        var exception = await Assert.ThrowsAsync<HttpRequestException>(() => host.Client.GetAboutAsync(TestContext.Current.CancellationToken));

        Assert.Null(exception.StatusCode);
    }

    [Fact]
    public async Task GetAbout_RespectsAnAlreadyCanceledRequest()
    {
        using var cancellation = CancellationTokenSource.CreateLinkedTokenSource(TestContext.Current.CancellationToken);
        await cancellation.CancelAsync();
        using var host = new ApiClientTestHost((_, _) => Task.FromResult(ApiClientTestHost.JsonResponse(ValidJson)));

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => host.Client.GetAboutAsync(cancellation.Token));
    }

    [Fact]
    public async Task GetAbout_CancelsAnInFlightRequest()
    {
        using var cancellation = CancellationTokenSource.CreateLinkedTokenSource(TestContext.Current.CancellationToken);
        using var cleanup = new CancellationTokenSource();
        var started = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var host = new ApiClientTestHost(async (_, token) =>
        {
            using var lifetime = CancellationTokenSource.CreateLinkedTokenSource(token, cleanup.Token);
            started.SetResult();
            await Task.Delay(Timeout.InfiniteTimeSpan, lifetime.Token);
            return ApiClientTestHost.JsonResponse(ValidJson);
        });

        var request = host.Client.GetAboutAsync(cancellation.Token);
        try
        {
            await started.Task.WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken);
            await cancellation.CancelAsync();

            await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
                request.WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken));
        }
        finally
        {
            await cleanup.CancelAsync();
        }
    }
}
