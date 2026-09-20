using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using OpenGameBuilder.Api.Client;
using OpenGameBuilder.Web.Client;
var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

// Published clients use their hosting origin; Development can override this in appsettings.Development.json.
builder.Services.AddOpenGameBuilderApiClient(builder.Configuration, new Uri(builder.HostEnvironment.BaseAddress));

await builder.Build().RunAsync();
