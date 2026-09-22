namespace OpenGameBuilder.Api.Tests;

public sealed class CiAcceptanceTests
{
    [Fact]
    public void RequiredWindowsLaneFailureIsVisible()
    {
        Assert.False(OperatingSystem.IsWindows(), "Temporary section 15 acceptance probe: Windows must fail the required CI gate.");
    }
}
