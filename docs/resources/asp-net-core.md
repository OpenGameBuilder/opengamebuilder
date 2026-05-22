# ASP.NET Core Resources

ASP.NET Core is a cross-platform, high-performance, open-source framework for building modern web apps using .NET.
This page includes a curated list of links on ASP.NET Core relevant to OpenGameBuilder.
These links are some of the best documentation around.

OpenGameBuilder's API back-end is an ASP.NET Core 10 Web API. The front-end is a [Blazor](./blazor.md) web app,
but many links on this page are still relevant for the front-end since Blazor is a part of ASP.NET Core.

- [Overview of ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/overview?view=aspnetcore-10.0)
- [Website](https://dotnet.microsoft.com/en-us/apps/aspnet)
- [ASP.NET documentation](https://learn.microsoft.com/en-us/aspnet/core/?view=aspnetcore-10.0)
- [ASP.NET Core fundamentals overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/?view=aspnetcore-10.0&tabs=windows)

## Learn
- [Getting started with ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/get-started?view=aspnetcore-10.0)
- [ASP.NET Core for Beginners](https://www.youtube.com/playlist?list=PLdo4fOcmZ0oW8nviYduHq7bmKode-p8Wy)
- [Front-end Web Development with .NET for Beginners](https://learn.microsoft.com/en-us/shows/frontend-web-development-with-dotnet-for-beginners/)
- [Back-end Web Development with .NET for Beginners](https://learn.microsoft.com/en-us/shows/back-end-web-development-with-dotnet-for-beginners/)
- [Create a web API with ASP.NET Core controllers](https://learn.microsoft.com/en-us/training/modules/build-web-api-aspnet-core/)

## What's New

Like [.NET](./dotnet.md), ASP.NET Core has a new major release every November, with even-numbered releases begin Long Term Support (LTS) releases and odd-numbered releases being Short Term Support (STS) releases. OpenGameBuilder currently uses ASP.NET Core 10, but will stay up to date with each release, both LTS and STS.

- *(Upcoming) [What's new in ASP.NET Core 11](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-11?view=aspnetcore-10.0)*
- [What's new in ASP.NET Core 10](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-10.0?view=aspnetcore-10.0)
- [What's new in ASP.NET Core 9](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-9.0?view=aspnetcore-10.0)
- [What's new in ASP.NET Core 8](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-8.0?view=aspnetcore-10.0)

## ASP.NET Core Specifics

### Fundamentals
- [Best practices](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/best-practices?view=aspnetcore-10.0)
- [App startup](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/startup?view=aspnetcore-10.0)
- [Dependency Injection](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection?view=aspnetcore-10.0)
- [Middleware](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-10.0)
- [Write custom middleware](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/write?view=aspnetcore-10.0)
- [.NET Generic Host](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/generic-host?view=aspnetcore-10.0)
- [Web Host](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/web-host?view=aspnetcore-10.0)
- [Configuration](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-10.0)
- [Options pattern](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/options?view=aspnetcore-10.0)
- [Runtime environments](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/environments?view=aspnetcore-10.0)
- [Logging](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging/?view=aspnetcore-10.0)
- [Health checks](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0) - *Not yet implemented in OpenGameBuilder.*
- [Routing](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/routing?view=aspnetcore-10.0)
- [Handle errors](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling?view=aspnetcore-10.0)
- [Make HTTP requests with IHttpClientFactory](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/http-requests?view=aspnetcore-10.0)
- [Static files](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/static-files?view=aspnetcore-10.0)
- [Session and state management](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/app-state?view=aspnetcore-10.0)
- [OpenAPI support](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/overview?view=aspnetcore-10.0)

## APIs
- [APIs overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/apis?view=aspnetcore-10.0)
- [Minimal API quick reference](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis?view=aspnetcore-10.0)
- [WebApplication and WebApplicationBuilder](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/webapplication?view=aspnetcore-10.0)
- [Route handlers](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/route-handlers?view=aspnetcore-10.0)
- [Parameter binding](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/parameter-binding?view=aspnetcore-10.0)
- [Create responses](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/responses?view=aspnetcore-10.0)
- [Unit and integration tests](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/test-min-api?view=aspnetcore-10.0)
- [Authentication and Authorization](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/security?view=aspnetcore-10.0)

### Models
- [Model binding](https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding?view=aspnetcore-10.0)
- [Model validation](https://learn.microsoft.com/en-us/aspnet/core/mvc/models/validation?view=aspnetcore-10.0)

### Development, Debugging, and Testing
- [.NET Hot Reload support](https://learn.microsoft.com/en-us/aspnet/core/test/hot-reload?view=aspnetcore-10.0)
- [Unit test controller logic](https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/testing?view=aspnetcore-10.0)
- [Integration tests](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-10.0&pivots=xunit)
- [Debugging](https://learn.microsoft.com/en-us/aspnet/core/test/debug-aspnetcore-source?view=aspnetcore-10.0)
- [Troubleshoot and debug](https://learn.microsoft.com/en-us/aspnet/core/test/troubleshoot?view=aspnetcore-10.0)

### Hosting and Deploying
- [Host and deploy](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/?view=aspnetcore-10.0)
- [DevOps](https://github.com/dotnet-architecture/eBooks/blob/1ed30275281b9060964fcb2a4c363fe7797fe3f3/current/devops-aspnet-core/DevOps-for-ASP.NET-Core-Developers.pdf)
- [Host in Docker containers](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/docker/?view=aspnetcore-10.0)

### Security
- [Security topics](https://learn.microsoft.com/en-us/aspnet/core/security/?view=aspnetcore-10.0)
- [Overview of authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/?view=aspnetcore-10.0)
- [Introduction to authorization](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/introduction?view=aspnetcore-10.0)
- [Data protection overview](https://learn.microsoft.com/en-us/aspnet/core/security/data-protection/introduction?view=aspnetcore-10.0)
- [Safe storage of app secrets in development](https://learn.microsoft.com/en-us/aspnet/core/security/app-secrets?view=aspnetcore-10.0&tabs=windows%2Cpowershell)
- [Enforce HTTPS](https://learn.microsoft.com/en-us/aspnet/core/security/enforcing-ssl?view=aspnetcore-10.0&tabs=visual-studio%2Clinux-ubuntu)
- [Hosting images with Docker Compose over HTTPS](https://learn.microsoft.com/en-us/aspnet/core/security/docker-compose-https?view=aspnetcore-10.0)

### Performance
- [Overview of caching](https://learn.microsoft.com/en-us/aspnet/core/performance/caching/overview?view=aspnetcore-10.0)
- [Memory management and garbage collection](https://learn.microsoft.com/en-us/aspnet/core/performance/memory?view=aspnetcore-10.0)
- [Response compression](https://learn.microsoft.com/en-us/aspnet/core/performance/response-compression?view=aspnetcore-10.0)

## See also
- [Blazor Resources](./blazor.md)
- [Entity Framework Core Resources](./entity-framework-core.md)
- [.NET Resources](./dotnet.md)
- [C# Resources](./csharp.md)
