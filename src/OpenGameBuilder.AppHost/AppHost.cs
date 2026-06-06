var builder = DistributedApplication.CreateBuilder(args);

// ASP.NET Core Web API.
// The launch profile is passed explicitly so the API keeps its fixed Kestrel bindings
// (https://localhost:7000, http://localhost:5000) and its Development environment/CORS config.
//
// A standalone Blazor WebAssembly app runs in the browser and cannot read Aspire's
// service-discovery environment variables, so it calls the API using a static URL baked into
// wwwroot/appsettings.{Environment}.json (https://localhost:7000). By default Aspire proxies
// every endpoint through DCP on a dynamically-assigned port, so that static URL no longer
// matches the public port and the browser's fetch fails with "TypeError: Failed to fetch".
//
// WithHttpsEndpoint(isProxied: false) tells Aspire not to put a proxy in front of this endpoint:
// the API is exposed directly on the fixed host port the browser expects, keeping the static
// client configuration and the API's CORS origins valid without any code changes.
var api = builder.AddProject<Projects.OpenGameBuilder_Api>("api", launchProfileName: "OpenGameBuilder.Api")
    .WithHttpsEndpoint(port: 7000, targetPort: 7000, isProxied: false);

// Standalone Blazor WebAssembly frontend, served by its dev server on https://localhost:7001.
// The browser calls the API directly using the client's static configuration, so Aspire's
// service-discovery environment variables are not consumed here; we only order startup after the API.
// The launch profile is passed explicitly so the dev server keeps its "inspectUri"
// (/_framework/debug/ws-proxy) endpoint. Without it Aspire launches with --no-launch-profile,
// the WASM debug proxy is never exposed, and Visual Studio reports "Failed to launch debug adapter".
//
// The dev server is also bound to a direct, non-proxied endpoint on the same fixed port as the
// launch profile (https://localhost:7001). By default Aspire fronts the resource with a reverse
// proxy on a random host port, which means the browser page is served from an unpredictable origin
// whose certificate binding the browser silently rejects for cross-origin fetches to the API
// (the request fails as "TypeError: Failed to fetch" before it ever reaches Kestrel). Pinning the
// endpoint keeps the page on the trusted https://localhost:7001 dev-cert origin so direct fetches
// to the API on https://localhost:7000 succeed.
builder.AddProject<Projects.OpenGameBuilder_Web_Client>("web", launchProfileName: "OpenGameBuilder.Web")
    .WithHttpsEndpoint(port: 7001, targetPort: 7001, isProxied: false)
    .WaitFor(api);

builder.Build().Run();
