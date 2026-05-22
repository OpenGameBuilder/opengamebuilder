# Versioning

OpenGameBuilder uses plain semantic versions for production releases:

```text
MAJOR.MINOR.PATCH
```

Examples:

- `0.7.0`
- `1.9.1`
- `2.0.3`

Production release versions do not use prerelease or build metadata.

The `v` prefix is used only for Git tags and patch branch names.

## Canonical version source

The canonical source version is stored in `Directory.Build.props`. The release version is the value of:

```xml
<VersionPrefix>0.7.0</VersionPrefix>
```

`Version` is derived from `VersionPrefix`. Do not update `<Version>` directly.

## Tags

Release tags use the format: `vX.Y.Z`

The tag must match `Directory.Build.props`.

Release tags are created only by the release workflow. Do not create release tags manually.

## Standard releases

Standard releases come from `main`. Standard release versions must have patch `0`. Use the patch release flow for patch versions. After a standard release, `main` is bumped to the next minor version. The tag is the immutable record of the released commit.

## Patch releases

Patch releases come from `patch/vX.Y.Z` branches. A patch branch is named after the exact patch release it is expected to publish. Patch release versions must have patch greater than `0`. Patch releases are published only for the latest stable/deployed release line. That keeps the normal patch flow focused on fixing current production.

## Branch version expectations

`main` should hold the next standard release version.

Examples:

- after `v0.7.0` release: main should be `v0.8.0`
- after `v1.9.0` release: main should be `v1.10.0`
- after `v2.7.1` release: main should be `v2.8.0`

A patch branch should hold the exact version in its branch name.

## What counts as a successful release

A release is successful only after:

1. The source version is validated.
2. The exact source commit builds and tests successfully.
3. The exact source commit deploys to production.
4. The production smoke test passes.
5. The release tag is created.
6. The GitHub Release is created.

The release tag is not created before production succeeds.

This is intentional.

## Manual redeploys

Manual production redeploys may use an existing release tag. The manual redeploy workflow validates that the tag matches the version in `Directory.Build.props`. Manual redeploys do not create new tags, GitHub Releases, patch branches, version bump PRs, or merge-back PRs.
