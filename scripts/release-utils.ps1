Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-OgbRepoRoot {
    $root = (& git rev-parse --show-toplevel)

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw "Could not resolve repository root."
    }

    return $root.Trim()
}

function Get-OgbDirectoryBuildPropsPath {
    return Join-Path (Get-OgbRepoRoot) "Directory.Build.props"
}

function Assert-OgbPlainSemVer {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Version
    )

    if ($Version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
        throw "Version must be plain SemVer X.Y.Z without prerelease/build metadata. Received: '$Version'."
    }
}

function ConvertTo-OgbVersionParts {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Version
    )

    Assert-OgbPlainSemVer -Version $Version

    $match = [regex]::Match($Version, '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)$')

    [pscustomobject]@{
        Major = [int] $match.Groups["major"].Value
        Minor = [int] $match.Groups["minor"].Value
        Patch = [int] $match.Groups["patch"].Value
    }
}

function Compare-OgbVersionParts {
    param(
        [Parameter(Mandatory = $true)]
        $Left,

        [Parameter(Mandatory = $true)]
        $Right
    )

    foreach ($name in @("Major", "Minor", "Patch")) {
        if ($Left.$name -lt $Right.$name) {
            return -1
        }

        if ($Left.$name -gt $Right.$name) {
            return 1
        }
    }

    return 0
}

function Get-OgbVersion {
    $propsPath = Get-OgbDirectoryBuildPropsPath
    $content = Get-Content -Path $propsPath -Raw

    $m = [regex]::Matches($content, '<VersionPrefix>(?<version>[^<]+)</VersionPrefix>')

    if ($m.Count -ne 1) {
        throw "Expected exactly one <VersionPrefix>...</VersionPrefix> in Directory.Build.props, found $($m.Count)."
    }

    $version = $m[0].Groups["version"].Value.Trim()
    Assert-OgbPlainSemVer -Version $version

    return $version
}

function Set-OgbVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Version
    )

    Assert-OgbPlainSemVer -Version $Version

    $propsPath = Get-OgbDirectoryBuildPropsPath
    $content = Get-Content -Path $propsPath -Raw

    $m = [regex]::Matches($content, '<VersionPrefix>[^<]+</VersionPrefix>')

    if ($m.Count -ne 1) {
        throw "Expected exactly one <VersionPrefix>...</VersionPrefix> in Directory.Build.props, found $($m.Count)."
    }

    $newContent = [regex]::Replace(
        $content,
        '<VersionPrefix>[^<]+</VersionPrefix>',
        "<VersionPrefix>$Version</VersionPrefix>",
        1
    )

    [System.IO.File]::WriteAllText($propsPath, $newContent)
}

function Write-OgbGitHubOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
        Write-Host "$Name=$Value"
        return
    }

    Add-Content -Path $env:GITHUB_OUTPUT -Value "$Name=$Value"
}

function Invoke-OgbNative {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Arguments
    )

    & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

function Get-OgbNativeOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Arguments
    )

    $output = & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }

    return (($output | Out-String).Trim())
}

function Test-OgbRemoteBranch {
    param(
        [Parameter(Mandatory = $true)]
        [string] $BranchName
    )

    & git ls-remote --exit-code --heads origin $BranchName *> $null
    return $LASTEXITCODE -eq 0
}

function Test-OgbRemoteTag {
    param(
        [Parameter(Mandatory = $true)]
        [string] $TagName
    )

    & git ls-remote --exit-code --tags origin "refs/tags/$TagName" *> $null
    return $LASTEXITCODE -eq 0
}

function ConvertFrom-OgbReleaseTag {
    param(
        [Parameter(Mandatory = $true)]
        [string] $TagName
    )

    $match = [regex]::Match($TagName, '^v(?<version>(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*))$')

    if (-not $match.Success) {
        return $null
    }

    $version = $match.Groups["version"].Value

    [pscustomobject]@{
        TagName = $TagName
        Version = $version
        Parts   = ConvertTo-OgbVersionParts -Version $version
    }
}

function Get-OgbStableGitHubReleases {
    $json = Get-OgbNativeOutput gh release list --limit 200 --json "tagName,isDraft,isPrerelease,publishedAt"

    if ([string]::IsNullOrWhiteSpace($json)) {
        return @()
    }

    $items = @($json | ConvertFrom-Json)
    $stable = @()

    foreach ($item in $items) {
        if ($item.isDraft -or $item.isPrerelease) {
            continue
        }

        $parsed = ConvertFrom-OgbReleaseTag -TagName $item.tagName

        if ($null -eq $parsed) {
            continue
        }

        $stable += [pscustomobject]@{
            TagName     = $parsed.TagName
            Version     = $parsed.Version
            Parts       = $parsed.Parts
            PublishedAt = $item.publishedAt
        }
    }

    return $stable
}

function Get-OgbLatestStableRelease {
    param(
        [string] $ReleaseLine = ""
    )

    $releases = @(Get-OgbStableGitHubReleases)

    if (-not [string]::IsNullOrWhiteSpace($ReleaseLine)) {
        if ($ReleaseLine -notmatch '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)$') {
            throw "Release line must look like X.Y. Received: '$ReleaseLine'."
        }

        $major = [int] $Matches["major"]
        $minor = [int] $Matches["minor"]

        $releases = @($releases | Where-Object {
                $_.Parts.Major -eq $major -and $_.Parts.Minor -eq $minor
            })
    }

    $latest = $null

    foreach ($release in $releases) {
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
