# Patch release

A patch release publishes a fix or small change for the currently deployed release.

Patch releases use versions like:

- `0.7.1`
- `1.0.2`
- `2.9.3`

Patch releases are made from a `patch/vX.Y.Z` branch, not from `main`.

## Summary

If the latest stable release is vX.Y.Z, a patch release does this
- prepare `patch/vX.Y.(Z+1)` branch
- open PR bumping `patch/vX.Y.(Z+1)` to **X.Y.(Z+1)**
- merge patch fixes into `patch/vX.Y.(Z+1)`
- deploy exact `patch/vX.Y.(Z+1)` commit to production
- smoke test production
- create `vX.Y.(Z+1)` tag
- create GitHub Release
- open merge-back PR from `patch/vX.Y.(Z+1)` into `main`

The release tag is created only after production deploys successfully and the production smoke test passes.

Do not create patch tags manually.

## When to use this

Use a patch release when production needs a bug fix but `main` may already contain unreleased work.

## Step 1: Prepare the patch

Go to:

```text
GitHub -> Actions -> 🩹 Prepare Patch -> Run workflow
```

The workflow uses the latest stable GitHub Release as the base.

For example, if the latest stable release is `v1.9.0`, the workflow prepares:

- **patch branch:** `patch/v1.9.1`
- **next patch version:** `1.9.1`
- **next patch tag:** `v1.9.1`

That PR updates `Directory.Build.props` on `patch/v1.9.1`:

```xml
<VersionPrefix>1.9.1</VersionPrefix>
```

Merge the prepare PR.

## Step 2: Add the patch fix

Add the actual patch fix to the patch branch through normal PRs.

The target branch should be `patch/vX.Y.(Z+1)`.

Keep the patch narrow. A patch release should fix the production issue or be a minor change, not sneak in a pile of unrelated improvements wearing a fake mustache.

## Step 3: Publish the patch release

When the patch branch is ready, go to:

```text
GitHub -> Actions -> 🚀 Publish Release -> Run workflow
```

Use these inputs:

- **kind:** patch
- **source_ref:** `patch/v1.9.1`
- **expected_version:** `1.9.1`
- **next_main_version:** *leave blank*

The workflow validates:

- The source branch is `patch/vX.Y.Z`.
- The branch name matches the version.
- The patch number is greater than `0`.
- The version is the next patch after the latest release in that line.
- The patch is for the latest stable/deployed release line.
- The tag does not already exist at a different commit.

## Step 4: Approve production deployment

The workflow deploys to the `production` GitHub Environment.

Production has required reviewers configured, wait for an assigned reviewer to approve.

The workflow deploys the exact validated commit SHA from the patch branch.

## What happens after approval

The workflow will:

1. Build and test the release commit.
2. Deploy the release commit to production.
3. Run the production smoke test.
4. Create the immutable release tag, such as `v1.9.1`.
5. Create the GitHub Release.
6. Open a merge-back PR from `patch/v1.9.1` into `main`.

## Step 5: Merge the patch back into main

Review the merge-back PR carefully.

The merge-back PR should bring the patch fix into `main`.

After the merge-back PR merges, the normal staging deployment should run automatically from the push to `main`.

## Failed patch releases

If validation fails:
- no production deploy
- no release tag
- no GitHub Release
- no merge-back PR

If build or tests fail:
- no production deploy
- no release tag
- no GitHub Release
- no merge-back PR

- If production deploy fails:
- no release tag
- no GitHub Release
- no merge-back PR

If the production smoke test fails:
- no release tag
- no GitHub Release
- no merge-back PR

If GitHub Release creation fails after the tag is created, rerun the workflow.

## Do not do these

Do not manually push `v*` tags.

Do not release patch versions from `main`.

Do not make broad feature changes on patch branches.

Do not skip the merge-back PR unless the patch already exists on `main`.

Do not let `main` keep an older version than the patched release.
