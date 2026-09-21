using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace OpenGameBuilder.Api.Tests;

internal sealed class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _environment;

    public ApiFactory(string environment)
    {
        _environment = environment;
        ClientOptions.BaseAddress = new Uri("https://localhost");
        ClientOptions.AllowAutoRedirect = false;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment(_environment);
        builder.UseSetting("OTEL_EXPORTER_OTLP_ENDPOINT", string.Empty);
    }
}
