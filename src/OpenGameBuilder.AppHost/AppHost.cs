var builder = DistributedApplication.CreateBuilder(args);

// The standalone WASM client reads its development API origin from static configuration, so the
// browser and API must keep fixed origins that match the API's CORS policy. Direct endpoints retain
// the launch-profile ports instead of Aspire's dynamic proxy ports. Passing each launch profile
// explicitly also preserves its bindings and the WASM dev server's debugger inspectUri.
var api = builder.AddProject<Projects.OpenGameBuilder_Api>("api", launchProfileName: "OpenGameBuilder.Api")
    .WithHttpsEndpoint(port: 7000, targetPort: 7000, isProxied: false);

builder.AddProject<Projects.OpenGameBuilder_Web_Client>("web", launchProfileName: "OpenGameBuilder.Web")
    .WithHttpsEndpoint(port: 7001, targetPort: 7001, isProxied: false)
    .WaitFor(api);

builder.Build().Run();
