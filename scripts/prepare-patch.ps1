. "$PSScriptRoot/release-utils.ps1"

Invoke-OgbNative git fetch --force --tags origin
Invoke-OgbNative git fetch origin main

$baseRelease = Get-OgbLatestStableRelease

if ($null -eq $baseRelease) {
    throw "No stable GitHub Release was found. Publish a normal release first."
}

$nextPatch = $baseRelease.Parts.Patch + 1
$nextVersion = "$($baseRelease.Parts.Major).$($baseRelease.Parts.Minor).$nextPatch"
$nextTag = "v$nextVersion"
$patchBranch = "patch/$nextTag"
$prepareBranch = "chore/prepare-$nextTag"

if (Test-OgbRemoteTag -TagName $nextTag) {
    throw "Tag '$nextTag' already exists."
}

Invoke-OgbNative git config user.name "OpenGameBuilder Release Bot"
Invoke-OgbNative git config user.email "release-bot@users.noreply.github.com"

if (Test-OgbRemoteBranch -BranchName $patchBranch) {
    Write-Host "Patch branch '$patchBranch' already exists."

    Invoke-OgbNative git fetch origin "+refs/heads/$patchBranch:refs/remotes/origin/$patchBranch"
    Invoke-OgbNative git switch --detach "origin/$patchBranch"

    $branchVersion = Get-OgbVersion

    if ($branchVersion -eq $nextVersion) {
        Write-Host "Patch branch '$patchBranch' is already prepared for '$nextVersion'."
    }
    elseif ($branchVersion -ne $baseRelease.Version) {
        throw "Patch branch '$patchBranch' has VersionPrefix '$branchVersion', but latest stable release is '$($baseRelease.Version)'. Fix the branch before preparing another patch."
    }

    $baseRef = "origin/$patchBranch"
}
else {
    Write-Host "Creating patch branch '$patchBranch' from '$($baseRelease.TagName)'."


    Invoke-OgbNative git branch $patchBranch $baseRelease.TagName
    Invoke-OgbNative git push origin "refs/heads/$patchBranch"

    $baseRef = $patchBranch
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

$existingPr = Get-OgbNativeOutput gh pr list --base $patchBranch --head $prepareBranch --state open --json number --jq '.[0].number'

if ([string]::IsNullOrWhiteSpace($existingPr)) {
    $body = @"
Prepares patch release $nextTag.

Base release: $($baseRelease.TagName)
Patch branch: $patchBranch

After this PR is merged and any patch fixes are included on $patchBranch, run the Publish Release workflow with:

kind: patch
source_ref: $patchBranch
expected_version: $nextVersion
"@

    Invoke-OgbNative gh pr create `
        --base $patchBranch `
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
Write-Host "  Patch branch:    $patchBranch"
Write-Host "  Prepare branch:  $prepareBranch"
