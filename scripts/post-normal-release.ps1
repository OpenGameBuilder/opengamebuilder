param(
    [string] $ReleasedVersion = $env:RELEASED_VERSION,
    [string] $NextVersion = $env:NEXT_VERSION,
    [string] $Tag = $env:TAG
)

. "$PSScriptRoot/release-utils.ps1"

if ([string]::IsNullOrWhiteSpace($ReleasedVersion)) {
    throw "RELEASED_VERSION is required."
}

if ([string]::IsNullOrWhiteSpace($NextVersion)) {
    throw "NEXT_VERSION is required."
}

if ([string]::IsNullOrWhiteSpace($Tag)) {
    throw "TAG is required."
}

Assert-OgbPlainSemVer -Version $ReleasedVersion
Assert-OgbPlainSemVer -Version $NextVersion

Invoke-OgbNative git fetch --force --tags origin
Invoke-OgbNative git fetch origin main

Invoke-OgbNative git config user.name "OpenGameBuilder Release Bot"
Invoke-OgbNative git config user.email "release-bot@users.noreply.github.com"

$bumpBranch = "chore/bump-version-to-$NextVersion"

if (Test-OgbRemoteBranch -BranchName $bumpBranch) {
    Write-Host "Bump branch '$bumpBranch' already exists."
}
else {
    Invoke-OgbNative git switch --detach origin/main
    Invoke-OgbNative git switch -c $bumpBranch

    Set-OgbVersion -Version $NextVersion

    $status = Get-OgbNativeOutput git status --porcelain

    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "No version change was needed."
    }
    else {
        Invoke-OgbNative git add Directory.Build.props
        Invoke-OgbNative git commit -m "chore: bump version to $NextVersion"
        Invoke-OgbNative git push origin "HEAD:refs/heads/$bumpBranch"
    }
}

$existingPr = Get-OgbNativeOutput gh pr list --base main --head $bumpBranch --state open --json number --jq '.[0].number'

if ([string]::IsNullOrWhiteSpace($existingPr)) {
    $body = @"
Post-release version bump after $Tag.

Released version: $ReleasedVersion
Next main version: $NextVersion
"@

    Invoke-OgbNative gh pr create `
        --base main `
        --head $bumpBranch `
        --title "chore: bump version to $NextVersion" `
        --body $body
}
else {
    Write-Host "Version bump PR already exists: #$existingPr"
}
