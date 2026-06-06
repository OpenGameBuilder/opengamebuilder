using Microsoft.AspNetCore.Components;
using Microsoft.Extensions.Hosting;
using OpenGameBuilder.Api.Client.About;
using OpenGameBuilder.Web.Client.Diagnostics;

namespace OpenGameBuilder.Web.Client.Pages;

public partial class Home
{
    private string _title = "Loading...";

    [Inject]
    private IAboutApiClient Client { get; init; } = default!;

    [Inject]
    private ClientLogForwarder LogForwarder { get; init; } = default!;

    [Inject]
    private NavigationManager Navigation { get; init; } = default!;

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
        catch (Exception ex)
        {
            _title = "Failed to load application information.";
            await LogForwarder.ReportExceptionAsync(ex, Navigation.Uri);
            throw;
        }
    }
}
