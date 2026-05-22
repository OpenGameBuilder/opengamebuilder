param(
    [string] $ReleaseKind = $env:RELEASE_KIND,
    [string] $SourceRef = $env:SOURCE_REF,
    [string] $ExpectedVersion = $env:EXPECTED_VERSION,
    [string] $NextMainVersion = $env:NEXT_MAIN_VERSION
)

. "$PSScriptRoot/release-utils.ps1"

function Get-LatestReleaseFromList {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Releases
    )

    $latest = $null

    foreach ($release in $Releases) {
        if ($null -eq $latest) {
            $latest = $release
            continue
        }

        if ((Compare-OgbVersionParts -Left $release.Parts -Right $latest.Parts) -gt 0) {
            $latest = $release
        }
    }

    return $latest
}

if ($ReleaseKind -notin @("normal", "patch")) {
    throw "Release kind must be 'normal' or 'patch'. Received: '$ReleaseKind'."
}

if ([string]::IsNullOrWhiteSpace($SourceRef)) {
    throw "SOURCE_REF is required."
}

$sourceRefName = (($SourceRef.Trim() -replace '^refs/heads/', '') -replace '^origin/', '')

$version = Get-OgbVersion
$parts = ConvertTo-OgbVersionParts -Version $version
$tag = "v$version"
$sourceSha = Get-OgbNativeOutput git rev-parse HEAD
$patchBranch = ""
$previousTag = ""

if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
    Assert-OgbPlainSemVer -Version $ExpectedVersion

    if ($ExpectedVersion -ne $version) {
        throw "Expected version '$ExpectedVersion', but Directory.Build.props VersionPrefix is '$version'."
    }
}

Invoke-OgbNative git fetch --force --tags origin

$tagExistsLocally = $false
& git rev-parse -q --verify "refs/tags/$tag" *> $null

if ($LASTEXITCODE -eq 0) {
    $tagExistsLocally = $true
}

if ($tagExistsLocally) {
    $existingSha = Get-OgbNativeOutput git rev-list -n 1 $tag

    if ($existingSha -ne $sourceSha) {
        throw "Tag '$tag' already exists at '$existingSha', but source ref '$sourceRefName' is at '$sourceSha'."
    }

    Write-Host "Tag '$tag' already exists at the expected SHA. Continuing idempotently."
}

$stableReleases = @(Get-OgbStableGitHubReleases)
$stableReleasesExcludingCurrent = @($stableReleases | Where-Object { $_.TagName -ne $tag })
$latestOverallRelease = Get-LatestReleaseFromList -Releases $stableReleasesExcludingCurrent

if ($ReleaseKind -eq "normal") {
    if ($sourceRefName -ne "main") {
        throw "Normal releases must be published from main. Received source ref '$sourceRefName'."
    }

    if ($parts.Patch -ne 0) {
        throw "Normal releases must use patch 0. Received '$version'. Use the patch flow for X.Y.Z where Z > 0."
    }

    if ($null -ne $latestOverallRelease) {
        $previousTag = $latestOverallRelease.TagName

        if ((Compare-OgbVersionParts -Left $parts -Right $latestOverallRelease.Parts) -le 0) {
            throw "Normal release '$version' must be greater than latest stable release '$($latestOverallRelease.Version)'."
        }
    }

    if ([string]::IsNullOrWhiteSpace($NextMainVersion)) {
        $NextMainVersion = "$($parts.Major).$($parts.Minor + 1).0"
    }

    Assert-OgbPlainSemVer -Version $NextMainVersion
    $nextParts = ConvertTo-OgbVersionParts -Version $NextMainVersion

    if ($nextParts.Patch -ne 0) {
        throw "Next main version must use patch 0. Received '$NextMainVersion'."
    }

    if ((Compare-OgbVersionParts -Left $nextParts -Right $parts) -le 0) {
        throw "Next main version '$NextMainVersion' must be greater than released version '$version'."
    }
}

if ($ReleaseKind -eq "patch") {
    $branchMatch = [regex]::Match($sourceRefName, '^patch/(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)$')

    if (-not $branchMatch.Success) {
        throw "Patch releases must be published from patch/X.Y. Received source ref '$sourceRefName'."
    }

    $branchMajor = [int] $branchMatch.Groups["major"].Value
    $branchMinor = [int] $branchMatch.Groups["minor"].Value

    if ($parts.Major -ne $branchMajor -or $parts.Minor -ne $branchMinor) {
        throw "Patch branch '$sourceRefName' does not match Directory.Build.props version '$version'."
    }

    if ($parts.Patch -le 0) {
        throw "Patch releases must use patch > 0. Received '$version'."
    }

    $lineReleases = @($stableReleasesExcludingCurrent | Where-Object {
            $_.Parts.Major -eq $parts.Major -and $_.Parts.Minor -eq $parts.Minor
        })

    if ($lineReleases.Count -eq 0) {
        throw "Could not find a prior stable release in line $($parts.Major).$($parts.Minor). Run a normal release first."
    }

    $latestLineRelease = Get-LatestReleaseFromList -Releases $lineReleases
    $previousTag = $latestLineRelease.TagName

    if ($null -ne $latestOverallRelease) {
        $latestOverallLine = "$($latestOverallRelease.Parts.Major).$($latestOverallRelease.Parts.Minor)"
        $patchLine = "$($parts.Major).$($parts.Minor)"

        if ($latestOverallLine -ne $patchLine) {
            throw "Patch releases must patch the latest deployed release line. Latest stable release is '$($latestOverallRelease.TagName)', but this patch is for '$patchLine'."
        }
    }

    $expectedPatch = $latestLineRelease.Parts.Patch + 1

    if ($parts.Patch -ne $expectedPatch) {
        throw "Patch release '$version' must be the next patch after '$($latestLineRelease.Version)'. Expected patch '$expectedPatch'."
    }

    $NextMainVersion = ""
}

Write-OgbGitHubOutput -Name "version" -Value $version
Write-OgbGitHubOutput -Name "tag" -Value $tag
Write-OgbGitHubOutput -Name "source_sha" -Value $sourceSha
Write-OgbGitHubOutput -Name "patch_branch" -Value $patchBranch
Write-OgbGitHubOutput -Name "next_main_version" -Value $NextMainVersion
Write-OgbGitHubOutput -Name "previous_tag" -Value $previousTag

Write-Host "Validated $ReleaseKind release:"
Write-Host "  Source ref:        $sourceRefName"
Write-Host "  Source SHA:        $sourceSha"
Write-Host "  Version:           $version"
Write-Host "  Tag:               $tag"
if (-not [string]::IsNullOrWhiteSpace($patchBranch)) {
    Write-Host "  Patch branch:    $patchBranch"
}

if (-not [string]::IsNullOrWhiteSpace($previousTag)) {
    Write-Host "  Previous tag:      $previousTag"
}

if (-not [string]::IsNullOrWhiteSpace($NextMainVersion)) {
    Write-Host "  Next main version: $NextMainVersion"
}
