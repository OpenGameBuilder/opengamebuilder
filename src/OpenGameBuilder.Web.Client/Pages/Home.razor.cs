using Microsoft.AspNetCore.Components;
using Microsoft.Extensions.Hosting;
using OpenGameBuilder.Api.Client.About;

namespace OpenGameBuilder.Web.Client.Pages;

public partial class Home
{
    private string _title = "Loading...";

    [Inject]
    private IAboutApiClient Client { get; init; } = default!;

    protected override async Task OnInitializedAsync()
    {
        try
        {
            var about = await Client.GetAboutAsync();
            _title = $"{about.ApplicationName} {about.Version}";
            if (about.ApiEnvironmentName != Environments.Production)
            {
                _title += $" ({about.ApiEnvironmentName})";
            }
        }
        catch (Exception)
        {
            _title = "Failed to load application information.";
            throw;
        }
    }
}
