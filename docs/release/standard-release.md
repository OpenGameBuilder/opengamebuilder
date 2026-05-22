# Standard release

A standard release publishes a new minor release from `main`.

Standard releases use versions like:

- `0.7.0`
- `1.9.0`
- `3.0.0`

The patch number must be `0`.

Patch releases such as `2.7.1` use the patch release flow instead.

## Summary

A standard release does this:
- validate version
- build and test
- deploy exact commit to production
- smoke test production
- create `vX.Y.0` tag
- create GitHub Release
- open PR bumping main to `X.(Y+1).0`

The release tag is created only after production deploys successfully and the production smoke test passes.

Do not create release tags manually.

## Before starting

Make sure:

- `main` is green.
- `Directory.Build.props` has the release version in `<VersionPrefix>`.
- The version is plain `X.Y.0`.
- There is no existing `vX.Y.0` tag.
- The release is ready to deploy to production.

Example:

```xml
<VersionPrefix>1.9.0</VersionPrefix>
```

## Run the release workflow

Go to:

```text
GitHub -> Actions -> 🚀 Publish Release -> Run workflow
```

Use these inputs:

- **kind:** normal
- **source_ref:** `main`
- **expected_version:** `1.9.0`
- **next_main_version:** *leave blank unless overriding*

Usually, leave `next_main_version` blank.

The workflow will default the next main version to `X.(Y+1).0`. For example, if the released version is `1.9.0`, main will be updated to `1.10.0`.

## Approve production deployment

The workflow deploys to the `production` GitHub Environment.

Production has required reviewers configured, wait for an assigned reviewer to approve.

The workflow deploys the exact validated commit SHA. It does not deploy a moving branch name.

## What happens after approval

The workflow will:

1. Build and test the release commit.
2. Deploy the release commit to production.
3. Run the production smoke test.
4. Create the immutable release tag, such as `v1.9.0`.
5. Create the GitHub Release.
6. Create or confirm the release branch, such as `release/1.9`.
7. Open a PR to bump `main` to the next minor version.

Example post-release PR:

```text
chore: bump version to 1.10.0
```

Review and merge that PR.

After it merges, the normal staging deployment should run from the push to `main`.

## Failed releases

If validation fails:

- no production deploy
- no release tag
- no GitHub Release
- no version bump PR

If build or tests fail:

- no production deploy
- no release tag
- no GitHub Release
- no version bump PR

If production deploy fails:

- no release tag
- no GitHub Release
- no version bump PR

If the production smoke test fails:

- no release tag
- no GitHub Release
- no version bump PR

If GitHub Release creation fails after the tag is created, rerun the workflow. The workflow is intended to be idempotent for already-created tags/releases that point to the expected commit.

## Do not do these

Do not manually push `v*` tags.

Do not release patch versions from `main`.

Do not manually create a GitHub Release before the workflow creates the tag.

Do not bypass the post-release version bump PR unless there is a specific reason.

Do not keep the old tag-triggered production workflow enabled.
