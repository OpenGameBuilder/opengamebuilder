namespace OpenGameBuilder.Api.Client.Tests;

public sealed class CiGateVerificationTests
{
    [Fact]
    public void IntentionalFailure_BlocksMainAndPatchMerges()
    {
        Assert.Fail("Intentional section 7 merge-gate verification failure. Do not merge this commit.");
    }
}
