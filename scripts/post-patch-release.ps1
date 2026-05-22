param(
    [string] $ReleasedVersion = $env:RELEASED_VERSION,
    [string] $ReleaseBranch = $env:RELEASE_BRANCH,
    [string] $Tag = $env:TAG
)

. "$PSScriptRoot/release-utils.ps1"

if ([string]::IsNullOrWhiteSpace($ReleasedVersion)) {
    throw "RELEASED_VERSION is required."
}

if ([string]::IsNullOrWhiteSpace($ReleaseBranch)) {
    throw "RELEASE_BRANCH is required."
}

if ([string]::IsNullOrWhiteSpace($Tag)) {
    throw "TAG is required."
}

Assert-OgbPlainSemVer -Version $ReleasedVersion

$releasedParts = ConvertTo-OgbVersionParts -Version $ReleasedVersion
$expectedReleaseBranch = "release/$ReleasedVersion"

if ($ReleaseBranch -ne $expectedReleaseBranch) {
    throw "Release branch '$ReleaseBranch' does not match released version '$ReleasedVersion'. Expected '$expectedReleaseBranch'."
}

$mergeBranch = "chore/merge-$Tag-into-main"

Invoke-OgbNative git fetch --force --tags origin
Invoke-OgbNative git fetch origin main
Invoke-OgbNative git fetch origin "+refs/heads/$ReleaseBranch:refs/remotes/origin/$ReleaseBranch"

Invoke-OgbNative git config user.name "OpenGameBuilder Release Bot"
Invoke-OgbNative git config user.email "release-bot@users.noreply.github.com"

if (Test-OgbRemoteBranch -BranchName $mergeBranch) {
    Write-Host "Merge-back branch '$mergeBranch' already exists."
}
else {
    Invoke-OgbNative git switch --detach origin/main

    $mainVersion = Get-OgbVersion
    $mainParts = ConvertTo-OgbVersionParts -Version $mainVersion

    $minimumMainVersion = "$($releasedParts.Major).$($releasedParts.Minor + 1).0"
    $minimumMainParts = ConvertTo-OgbVersionParts -Version $minimumMainVersion

    if ((Compare-OgbVersionParts -Left $mainParts -Right $minimumMainParts) -lt 0) {
        $targetMainVersion = $minimumMainVersion
    }
    else {
        $targetMainVersion = $mainVersion
    }

    Write-Host "Main version before merge-back: $mainVersion"
    Write-Host "Target main version after merge-back: $targetMainVersion"

    Invoke-OgbNative git switch -c $mergeBranch

    & git merge --no-ff --no-commit "origin/$ReleaseBranch"

    if ($LASTEXITCODE -ne 0) {
        $conflicts = @(git diff --name-only --diff-filter=U)
        $nonVersionConflicts = @($conflicts | Where-Object { $_ -ne "Directory.Build.props" })

        if ($nonVersionConflicts.Count -gt 0) {
            git status --short
            throw "Merge-back has conflicts outside Directory.Build.props: $($nonVersionConflicts -join ', '). Resolve manually."
        }

        if ($conflicts -contains "Directory.Build.props") {
            Write-Host "Resolving Directory.Build.props version conflict in favor of main version policy."
            Invoke-OgbNative git checkout --ours Directory.Build.props
            Invoke-OgbNative git add Directory.Build.props
        }
    }

    Set-OgbVersion -Version $targetMainVersion

    Invoke-OgbNative git add -A

    $status = Get-OgbNativeOutput git status --porcelain

    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host "Merge-back produced no changes after preserving main version. No PR is needed."

        & git merge --abort *> $null
        exit 0
    }

    Invoke-OgbNative git commit -m "chore: merge $Tag into main"
    Invoke-OgbNative git push origin "HEAD:refs/heads/$mergeBranch"
}

$existingPr = Get-OgbNativeOutput gh pr list --base main --head $mergeBranch --state open --json number --jq '.[0].number'

if ([string]::IsNullOrWhiteSpace($existingPr)) {
    $body = @"
Merges patch release $Tag back into main.

Released version: $ReleasedVersion
Release branch: $ReleaseBranch

Version policy:
- main keeps its current VersionPrefix if it is already beyond the patched release line.
- otherwise main is bumped to $($releasedParts.Major).$($releasedParts.Minor + 1).0.

After this PR merges, the normal staging deploy should run from the push to main.
"@

    Invoke-OgbNative gh pr create `
        --base main `
        --head $mergeBranch `
        --title "chore: merge $Tag into main" `
        --body $body
}
else {
    Write-Host "Merge-back PR already exists: #$existingPr"
}
