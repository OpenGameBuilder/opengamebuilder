. "$PSScriptRoot/release-utils.ps1"

Invoke-OgbNative git fetch --force --tags origin
Invoke-OgbNative git fetch origin main

$baseRelease = Get-OgbLatestStableRelease

if ($null -eq $baseRelease) {
    throw "No stable GitHub Release was found. Publish a normal release first."
}

$releaseLine = "$($baseRelease.Parts.Major).$($baseRelease.Parts.Minor)"
$nextPatch = $baseRelease.Parts.Patch + 1
$nextVersion = "$($baseRelease.Parts.Major).$($baseRelease.Parts.Minor).$nextPatch"
$nextTag = "v$nextVersion"
$releaseBranch = "release/$releaseLine"
$prepareBranch = "chore/prepare-$nextTag"

if (Test-OgbRemoteTag -TagName $nextTag) {
    throw "Tag '$nextTag' already exists."
}

Invoke-OgbNative git config user.name "OpenGameBuilder Release Bot"
Invoke-OgbNative git config user.email "release-bot@users.noreply.github.com"

if (Test-OgbRemoteBranch -BranchName $releaseBranch) {
    Write-Host "Release branch '$releaseBranch' already exists."

    Invoke-OgbNative git fetch origin "+refs/heads/$releaseBranch:refs/remotes/origin/$releaseBranch"
    Invoke-OgbNative git switch --detach "origin/$releaseBranch"

    $branchVersion = Get-OgbVersion

    if ($branchVersion -eq $nextVersion) {
        throw "Release branch '$releaseBranch' is already prepared for '$nextVersion'. Run the Publish Release workflow when the patch is ready."
    }

    if ($branchVersion -ne $baseRelease.Version) {
        throw "Release branch '$releaseBranch' has VersionPrefix '$branchVersion', but latest stable release is '$($baseRelease.Version)'. Fix the branch before preparing another patch."
    }

    $baseRef = "origin/$releaseBranch"
}
else {
    Write-Host "Creating release branch '$releaseBranch' from '$($baseRelease.TagName)'."

    Invoke-OgbNative git branch $releaseBranch $baseRelease.TagName
    Invoke-OgbNative git push origin "refs/heads/$releaseBranch"

    $baseRef = $releaseBranch
}

if (Test-OgbRemoteBranch -BranchName $prepareBranch) {
    Write-Host "Prepare branch '$prepareBranch' already exists."
}
else {
    Invoke-OgbNative git switch --detach $baseRef
    Invoke-OgbNative git switch -c $prepareBranch

    Set-OgbVersion -Version $nextVersion

    $status = Get-OgbNativeOutput git status --porcelain

    if ([string]::IsNullOrWhiteSpace($status)) {
        throw "No changes were made while preparing '$nextVersion'. Directory.Build.props may already be set to that version."
    }

    Invoke-OgbNative git add Directory.Build.props
    Invoke-OgbNative git commit -m "chore: prepare $nextTag"
    Invoke-OgbNative git push origin "HEAD:refs/heads/$prepareBranch"
}

$existingPr = Get-OgbNativeOutput gh pr list --base $releaseBranch --head $prepareBranch --state open --json number --jq '.[0].number'

if ([string]::IsNullOrWhiteSpace($existingPr)) {
    $body = @"
Prepares patch release $nextTag.

Base release: $($baseRelease.TagName)
Release branch: $releaseBranch

After this PR is merged and any patch fixes are included on $releaseBranch, run the Publish Release workflow with:

kind: patch
source_ref: $releaseBranch
expected_version: $nextVersion
"@

    Invoke-OgbNative gh pr create `
        --base $releaseBranch `
        --head $prepareBranch `
        --title "chore: prepare $nextTag" `
        --body $body
}
else {
    Write-Host "Prepare patch PR already exists: #$existingPr"
}

Write-Host "Prepared patch release:"
Write-Host "  Base release:    $($baseRelease.TagName)"
Write-Host "  Next tag:        $nextTag"
Write-Host "  Release branch:  $releaseBranch"
Write-Host "  Prepare branch:  $prepareBranch"
