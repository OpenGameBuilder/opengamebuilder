var builder = DistributedApplication.CreateBuilder(args);

// This solution pairs an ASP.NET Core API with a *standalone* Blazor WebAssembly app. The WASM
// app runs entirely in the browser and cannot read Aspire's service-discovery environment
// variables, so it calls the API using a static URL baked into wwwroot/appsettings.{Environment}.json
// (https://localhost:7000 in Development).
//
// By default Aspire fronts every endpoint with a DCP reverse proxy on a dynamically-assigned host
// port. That breaks this setup two ways: the API's public port no longer matches the static client
// URL, and the browser page itself is served from an unpredictable origin whose dev-cert binding the
// browser silently rejects for cross-origin fetches. Either way the request dies as
// "TypeError: Failed to fetch" before it reaches Kestrel.
//
// WithHttpsEndpoint(isProxied: false) disables the proxy and binds each project directly to the fixed
// port declared in its launch profile, so the static client config and the API's CORS origins stay
// valid with no code changes. The launch profile is also passed explicitly so each project keeps its
// profile-defined bindings (and, for the WASM dev server, its /_framework/debug/ws-proxy inspectUri;
// without it Aspire launches with --no-launch-profile and Visual Studio reports
// "Failed to launch debug adapter").
var api = builder.AddProject<Projects.OpenGameBuilder_Api>("api", launchProfileName: "OpenGameBuilder.Api")
    .WithHttpsEndpoint(port: 7000, targetPort: 7000, isProxied: false);

builder.AddProject<Projects.OpenGameBuilder_Web_Client>("web", launchProfileName: "OpenGameBuilder.Web")
    .WithHttpsEndpoint(port: 7001, targetPort: 7001, isProxied: false)
    .WaitFor(api);

builder.Build().Run();

