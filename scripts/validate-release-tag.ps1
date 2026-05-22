param(
    [string] $Tag = $env:RELEASE_TAG
)

. "$PSScriptRoot/release-utils.ps1"

if ([string]::IsNullOrWhiteSpace($Tag)) {
    throw "RELEASE_TAG was not provided."
}

$version = Get-OgbVersion
$expectedTag = "v$version"

if ($Tag -ne $expectedTag) {
    throw "Release tag '$Tag' does not match Directory.Build.props VersionPrefix '$version'. Expected tag '$expectedTag'."
}

Write-OgbGitHubOutput -Name "version" -Value $version
Write-OgbGitHubOutput -Name "tag" -Value $Tag

Write-Host "Validated $Tag against Directory.Build.props VersionPrefix $version."
