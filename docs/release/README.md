# Releases

OpenGameBuilder ships through GitHub Actions. There are exactly three release
workflows you need to know about:

| Workflow              | Trigger                                            | What it does                                                                |
| --------------------- | -------------------------------------------------- | --------------------------------------------------------------------------- |
| 🛰️ **CD Staging**    | Every push to `main`, or manual dispatch from `main` | Build, test, deploy to staging, smoke test                                  |
| 🚀 **CD Production** | Manually dispatched **from `main`**, with a separate source `ref` input | Validate, build, test, deploy to production, smoke test, tag, release, follow-up PR |
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
commit. The [hosting guide records deployment and recovery evidence](../setup/hosting.md#recorded-deployment-evidence).

For **CD Production**, the Actions branch picker must be **`main`**: it selects
the workflow definition and the run ref checked by the production environment.
The separate `ref` input selects application source: protected `main` for a
standard release or protected `patch/vX.Y.Z` for a patch. The resolver fixes that
source to a commit; tags, arbitrary SHAs, and unprotected branches are rejected.
The workflow rejects non-`main` dispatches before source resolution. See
[deployment authority](../setup/github.md#deployment-authority-and-recovery).

## Standard release (X.Y.0)

1. `main` already has `<VersionPrefix>X.Y.0</VersionPrefix>` (set by the
   post-release bump PR from the previous release).
2. Go to **Actions → 🚀 CD Production → Run workflow**. Select `main` in the
   branch picker and leave the separate `ref` input as `main`.
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

The workflow definition and shared validation action come from the dispatched
`main` workflow commit; application files and release/deployment scripts come
from the resolved protected source commit. Ensure patch branches contain
compatible deployment and release code, including the `/api/about` source
revision used by the browser smoke test. A patch release still uses `main` in
the workflow branch picker.

## What the production workflow validates

It detects whether the selected source is a standard or patch release from the
version number itself (`Z == 0` → standard, `Z > 0` → patch) and checks:

- Version in `Directory.Build.props` is plain `X.Y.Z`
- For standard: ref is `main`, version is greater than the latest stable release
- For patch: ref is `patch/v<version>`, the version is the next patch in line,
  and that line is the latest deployed line
- Any existing `vX.Y.Z` tag points at the same commit (idempotent reruns)

## What happens on failure

The tag, GitHub Release, and follow-up PR are only created **after** a
successful production deploy and smoke test. If activation or smoke testing
fails, the deployment job attempts recovery in its rollback step. An upgrade
restores the previous web/API pair; a failed first deployment returns to the
defined undeployed state. Inspect that step's result and the host's `current`,
`previous`, `pending`, and candidate `predecessor` records before rerunning; see
[the recovery procedure](../setup/hosting.md#application-activation-and-rollback).

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
