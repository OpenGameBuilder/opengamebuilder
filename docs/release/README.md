# Releases

OpenGameBuilder ships through GitHub Actions. There are exactly three release
workflows you need to know about:

| Workflow              | Trigger                                            | What it does                                                                |
| --------------------- | -------------------------------------------------- | --------------------------------------------------------------------------- |
| 🛰️ **CD Staging**    | Every push to `main`                               | Build, test, deploy to staging, smoke test                                  |
| 🚀 **CD Production** | Manually dispatched from `main` with a `ref` input | Validate, build, test, deploy to production, smoke test, tag, release, follow-up PR |
| 🩹 **Prepare Patch** | Manually dispatched                                | Create `patch/vX.Y.(Z+1)` branch and a version-bump PR off the latest tag   |

The single source of truth for the version is `<VersionPrefix>` in
`Directory.Build.props`. See [versioning.md](./versioning.md).

## Standard release (X.Y.0)

1. `main` already has `<VersionPrefix>X.Y.0</VersionPrefix>` (set by the
   post-release bump PR from the previous release).
2. Go to **Actions → 🚀 CD Production → Run workflow**. Leave `ref` as `main`.
3. The `production` environment requires reviewer approval — approve when ready.
4. On success the workflow tags `vX.Y.0`, creates the GitHub Release, and opens
   `chore: bump version to X.(Y+1).0` against `main`. Merge that PR.

## Patch release (X.Y.Z, Z > 0)

1. Go to **Actions → 🩹 Prepare Patch → Run workflow**. This creates
   `patch/vX.Y.(Z+1)` from the latest release tag and opens a PR that bumps the
   `<VersionPrefix>` on that branch. Merge the prepare PR.
2. Add the fix to `patch/vX.Y.(Z+1)` via normal PRs targeted at that branch.
3. Go to **Actions → 🚀 CD Production → Run workflow**. Leave the branch picker
   on `main` (so the workflow file runs from main) and set `ref` to
   `patch/vX.Y.(Z+1)`.
4. Approve the production environment when prompted.
5. On success the workflow tags `vX.Y.(Z+1)`, creates the GitHub Release, and
   opens `chore: merge vX.Y.(Z+1) into main`. Review and merge that PR.

> **Note:** CD Production always runs the workflow file from the branch it is
> dispatched on (usually `main`), but it deploys whichever `ref` you specify.
> This lets us release patch branches that were cut from older tags without
> requiring those tags to contain the current workflow.

## What the production workflow validates

It detects whether the dispatched ref is a standard or patch release from the
version number itself (`Z == 0` → standard, `Z > 0` → patch) and checks:

- Version in `Directory.Build.props` is plain `X.Y.Z`
- For standard: ref is `main`, version is greater than the latest stable release
- For patch: ref is `patch/v<version>`, the version is the next patch in line,
  and that line is the latest deployed line
- Any existing `vX.Y.Z` tag points at the same commit (idempotent reruns)

## What happens on failure

The tag, GitHub Release, and follow-up PR are only created **after** a
successful production deploy and smoke test. If anything fails earlier, none of
the post-deploy artifacts are produced and you can fix and rerun safely.

If the post-deploy steps fail after the tag exists (e.g. release creation
hiccup), simply rerun the workflow — it is idempotent for tags that already
point at the expected commit.

## Don't do these

- Don't push `v*` tags manually.
- Don't release patch versions from `main`.
- Don't release standard versions from a `patch/*` branch.
- Don't bypass the follow-up PR without good reason — `main` is expected to hold
  the next standard release version at all times.
