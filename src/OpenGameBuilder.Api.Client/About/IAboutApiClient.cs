using OpenGameBuilder.Api.Contracts.About;

namespace OpenGameBuilder.Api.Client.About;

public interface IAboutApiClient
{
    Task<AboutResponse> GetAboutAsync(CancellationToken cancellationToken = default);
}
