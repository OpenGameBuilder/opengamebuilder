# Releases

OpenGameBuilder ships through GitHub Actions. There are exactly three release
workflows you need to know about:

| Workflow              | Trigger                                            | What it does                                                                |
| --------------------- | -------------------------------------------------- | --------------------------------------------------------------------------- |
| 🛰️ **CD Staging**    | Every push to `main`                               | Build, test, deploy to staging, smoke test                                  |
| 🚀 **CD Production** | Manually dispatched (usually from `main`) with a `ref` input | Validate, build, test, deploy to production, smoke test, tag, release, follow-up PR |
| 🩹 **Prepare Patch** | Manually dispatched                                | Create `patch/vX.Y.(Z+1)` branch and a version-bump PR off the latest tag   |

Host infrastructure is separate: **🌐 CD Edge** updates the selected host's
explicit edge profile, not an application release. Staging and production may
use separate hosts and SSH keys. Configure their `EDGE_PROFILE` variables before
deploying; see [hosting setup](../setup/hosting.md). Shared-host staging keeps
the production-health guard; isolated staging has no production dependency.

The single source of truth for the version is `<VersionPrefix>` in
`Directory.Build.props`. See [versioning.md](./versioning.md).

Each deployment records `releases/<release-id>/release-manifest.txt` with the resolved source commit,
the immutable API image digest reference, and the SHA-256 of the published web
archive. After validation the package job publishes the portable frontend once;
after environment approval, deployment verifies it and builds the API image once
without environment-specific frontend publishing. These identities are more
precise than the version or mutable commit-named convenience tag. Inspect the
manifest and workflow artifact when identifying an installed release. The host's
`current` and `previous` files identify the active and rollback pair; see
[hosting setup](../setup/hosting.md#application-activation-and-rollback). The
browser smoke check follows the activated page, observes its `/api/about` call,
and compares the running API's source revision with the selected protected
commit. The staging rollback rehearsal passed on 2026-09-20; the
[hosting guide records the deployment evidence](../setup/hosting.md#recorded-deployment-evidence).

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

> **Note:** CD Production runs the workflow file from the branch it is
> dispatched on (usually `main`), but it checks out the specified `ref` before
> running validation and release scripts. Ensure patch branches contain
> compatible deployment and release code for their release run, including the
> `/api/about` source revision used by the browser smoke test.

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
successful production deploy and smoke test. If activation or smoke testing
fails, the workflow attempts to restore the previous web/API pair. Inspect the
rollback job result and the host's `current` and `previous` files before rerunning.

If deployment and smoke testing succeed but tag creation, GitHub Release
creation, or the follow-up PR fails, production is already running the new pair.
Do not roll it back solely because publication failed. Read the active manifest
and workflow run to confirm the exact source SHA and image digest. After fixing
the publishing error, rerun from the same protected source branch while it still
resolves to that SHA; the release scripts accept the matching existing tag and
release. If that branch has moved, use the recorded commit and resolve the
publication state with the maintainer before dispatching another deployment.

If the post-deploy steps fail after the tag exists (e.g. release creation
hiccup), rerun the workflow from the same source branch and commit. Validation
accepts an already-published standard or patch release only when its tag still
points at that commit and it remains the latest stable release. A different tag
target, a skipped patch number, or an older release line is rejected.

If the patch merge-back encounters a conflict in `Directory.Build.props` or any
other file, the follow-up step stops without pushing a merge branch. Resolve the
merge locally and open the merge-back PR manually; preserve both sides' non-version
changes and keep main's current `VersionPrefix` if it is already at least
`X.(Y+1).0`. Do not choose the entire props file from one side. The production
release may already be published even though this follow-up PR is still missing.

## Don't do these

- Don't push `v*` tags manually.
- Don't release patch versions from `main`.
- Don't release standard versions from a `patch/*` branch.
- Don't bypass the follow-up PR without good reason — `main` is expected to hold
  the next standard release version at all times.
