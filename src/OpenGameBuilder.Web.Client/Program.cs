using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using OpenGameBuilder.Api.Client;
using OpenGameBuilder.Web.Client;
using OpenGameBuilder.Web.Client.Diagnostics;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

builder.Services.AddOpenGameBuilderApiClient(builder.Configuration);

// Forwards browser-side errors to the API so they surface in the Aspire dashboard.
var apiBaseUrl = builder.Configuration["OpenGameBuilder:Api:BaseUrl"]
    ?? throw new InvalidOperationException("OpenGameBuilder:Api:BaseUrl is not configured.");
builder.Services.AddHttpClient<ClientLogForwarder>(client => client.BaseAddress = new Uri(apiBaseUrl));

var host = builder.Build();

RegisterGlobalErrorForwarding(host.Services);

await host.RunAsync();

static void RegisterGlobalErrorForwarding(IServiceProvider services)
{
    var forwarder = services.GetRequiredService<ClientLogForwarder>();

    AppDomain.CurrentDomain.UnhandledException += (_, e) =>
    {
        if (e.ExceptionObject is Exception ex)
        {
            _ = forwarder.ReportExceptionAsync(ex, "AppDomain.UnhandledException");
        }
    };

    TaskScheduler.UnobservedTaskException += (_, e) =>
    {
        _ = forwarder.ReportExceptionAsync(e.Exception, "TaskScheduler.UnobservedTaskException");
        e.SetObserved();
    };
}
