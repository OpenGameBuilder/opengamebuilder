using System.Reflection;

using Microsoft.AspNetCore.Mvc;
using OpenGameBuilder.Api.Contracts.About;

namespace OpenGameBuilder.Api.Controllers;

[ApiController]
[Route("/api/about")]
public sealed class AboutController(IWebHostEnvironment webHostEnvironment) : ControllerBase
{
    public const string ApplicationName = "OpenGameBuilder";

    private readonly IWebHostEnvironment _webHostEnvironment = webHostEnvironment;

    [HttpGet(Name = "GetAbout")]
    [ProducesResponseType(typeof(AboutResponse), StatusCodes.Status200OK)]
    public ActionResult<AboutResponse> Get() => new AboutResponse
    {
        ApplicationName = "OpenGameBuilder",
        Version = GetInformationalVersion(),
        ApiEnvironmentName = _webHostEnvironment.EnvironmentName
    };

    private static string GetInformationalVersion()
    {
        var assembly = typeof(AboutController).Assembly;
        return assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? assembly.GetName().Version?.ToString()
            ?? "?.?.?.0";
    }
}
