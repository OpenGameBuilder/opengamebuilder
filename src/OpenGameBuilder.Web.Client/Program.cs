using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using OpenGameBuilder.Api.Client;
using OpenGameBuilder.Web.Client;
var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

// Published clients use their hosting origin; Development can override this in appsettings.Development.json.
// A versioned web path must still call the API at the hosting origin's /api path.
var origin = new Uri(new Uri(builder.HostEnvironment.BaseAddress).GetLeftPart(UriPartial.Authority));
builder.Services.AddOpenGameBuilderApiClient(builder.Configuration, origin);

await builder.Build().RunAsync();
