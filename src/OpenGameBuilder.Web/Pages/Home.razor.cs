using Microsoft.AspNetCore.Components;

namespace OpenGameBuilder.Web.Pages;

public partial class Home
{
    [Inject]
    private IConfiguration Configuration { get; init; } = default!;

    private string Title => Configuration["Title"] ?? "Open Game Builder";
}
