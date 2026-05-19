using System.Reflection;

using Microsoft.AspNetCore.Mvc;

namespace OpenGameBuilder.Api.Controllers;

[ApiController]
[Route("/api/version")]
public sealed class VersionController : ControllerBase
{
    private static readonly string s_version =
        Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "0.0.0";

    [HttpGet(Name = "GetVersion")]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    public ActionResult<string> Get() => s_version;
}
