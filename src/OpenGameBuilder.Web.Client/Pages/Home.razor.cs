using Microsoft.AspNetCore.Components;
using OpenGameBuilder.Api.Client.About;

namespace OpenGameBuilder.Web.Client.Pages;

public partial class Home
{
    private string _title = "Loading...";

    [Inject]
    private IAboutApiClient Client { get; init; } = default!;

    protected override async Task OnInitializedAsync()
    {
        var about = await Client.GetAboutAsync();
        _title = $"{about.ApplicationName} {about.Version}";
    }
}
