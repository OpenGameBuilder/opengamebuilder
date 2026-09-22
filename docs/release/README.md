# Releases

OpenGameBuilder ships through GitHub Actions. There are exactly three release
workflows you need to know about:

| Workflow             | Trigger                                                                 | What it does                                                                        |
| -------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 🛰️ **CD Staging**    | Every push to `main`, or manual dispatch from `main`                    | Build, test, deploy to staging, smoke test                                          |
| 🚀 **CD Production** | Manually dispatched **from `main`**, with a separate source `ref` input | Validate, build, test, deploy to production, smoke test, tag, release, follow-up PR |
| 🩹 **Prepare Patch** | Manually dispatched                                                     | Create `patch/vX.Y.(Z+1)` branch and a version-bump PR off the latest tag           |

Host infrastructure is separate: **🌐 CD Edge** updates the selected host's
explicit edge profile, not an application release. Staging and production may
use separate hosts and SSH keys. Configure their `EDGE_PROFILE` variables before
deploying; see [hosting setup](../setup/hosting.md). Shared-host staging keeps
the production-health guard; isolated staging has no production dependency.

The single source of truth for the version is `<VersionPrefix>` in
`Directory.Build.props`. See [versioning.md](./versioning.md).
Protected `main`, short-lived branches, draft PRs, squash merges, and merged-branch
cleanup follow [the contribution branch policy](../../CONTRIBUTING.md#branches-and-release-notes).
There is no permanent `develop` branch; `patch/vX.Y.Z` is reserved for the hotfix
path below. CD Production remains the only owner of release tags and publication;
its existing prepare/bump PRs own version changes. Changelog tools do not infer
versions from commits, create tags, or publish releases.

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

## Curated release notes

[`CHANGELOG.md`](../../CHANGELOG.md) is the curated account of notable changes.
Keep an `Unreleased` section for observable application, contributor, and operator
changes. Include breaking behavior and migration or configuration steps where
needed; leave out mechanical dependency and formatting noise. Published releases
before this changelog remain documented in GitHub Releases.

The release maintainer prepares notes in a normal source PR using Node.js 22 or
newer; Node.js 24 is the recommended LTS and CI baseline. Commands run from the
repository root:

1. Optionally generate drafting material from merged PRs with authenticated `gh`.
   Replace the example previous tag with the preceding deployed release (omit
   `--previous-tag` only for a first release). The checkout's HEAD must already
   exist on GitHub; uncommitted changes are not included:

   ```pwsh
   node scripts/changelog.mjs draft --previous-tag v0.10.0 --output artifacts/release-draft.md
   ```

   This calls GitHub's [generate-notes API](https://docs.github.com/en/rest/releases/releases#generate-release-notes-content-for-a-release)
   and writes a local file without creating a GitHub draft, tag, or release. An
   existing output file is rejected; use a new filename for another draft.
   [`.github/release.yml`](../../.github/release.yml) groups actual PR labels into
   application, operations, contributor/documentation, and remaining changes.
   `dependencies` and `internal` are excluded from this drafting aid. Review the
   full comparison too: an excluded update can still need security or migration
   guidance. Copy useful facts and PR references into `Unreleased`, remove noise,
   and write the human-facing summary there. The generated draft is disposable.

2. Review `Unreleased` against the selected source and `VersionPrefix`, then seal
   it using the intended release date (replace this example date as appropriate):

   ```pwsh
   node scripts/changelog.mjs prepare --date 2026-09-22
   node scripts/changelog.mjs check --release
   ```

   Preparation takes the version from `Directory.Build.props`, creates
   `## X.Y.Z - YYYY-MM-DD`, and leaves a fresh empty `## Unreleased` for future
   changes. It rejects an empty entry or an already prepared version without
   overwriting history. Ordinary `check` validates the structure without requiring
   the current version to be prepared; the content gate runs it on PRs.

3. Review and merge the changelog PR before dispatching CD Production. A dated
   heading records prepared notes, not proof of deployment; GitHub Releases records
   publication. If the date or scope changes before release, edit that entry in
   another PR. Do not run `prepare` a second time for the same version.

Use third-level headings such as `Added`, `Changed`, `Fixed`, and `Removed` inside
an entry, with explicit breaking changes and migration instructions where needed.
Keep Markdown links simple: inline links or reference definitions within the entry.
Publication binds repository-relative links to the selected source SHA, so they
work from GitHub Releases. Do not rely on reference definitions in another entry.

On a patch branch, start a fresh `Unreleased` if the older release lacks one, and
include only that patch's changes. Prepare its exact `VersionPrefix` entry there.
The existing merge-back returns the entry to `main`; resolve changelog conflicts
by retaining both histories and keeping main's pending changes under `Unreleased`.

Production validation rejects missing, duplicate, malformed, or empty version
entries before deployment. After deployment and browser smoke pass,
[`publish-release.sh`](../../scripts/publish-release.sh) selects the same entry
from the resolved source commit and supplies it as the complete GitHub Release
body. Generated PR notes are drafting input, not a second published summary.
Reruns accept the matching tag and existing release without duplicating or
overwriting them. Correct published wording in `CHANGELOG.md` first; any GitHub
Release body update is a separate maintainer-authorized edit. No changelog command
authorizes deployment or publication.

## Standard release (X.Y.0)

1. `main` already has `<VersionPrefix>X.Y.0</VersionPrefix>` (set by the
   post-release bump PR from the previous release). Merge its reviewed dated
   changelog entry using the process above.
2. Go to **Actions → 🚀 CD Production → Run workflow**. Select `main` in the
   branch picker and leave the separate `ref` input as `main`.
3. The `production` environment requires reviewer approval — approve when ready.
4. On success the workflow tags `vX.Y.0`, creates the GitHub Release, and opens
   `chore: bump version to X.(Y+1).0` against `main`. Merge that PR.

## Patch release (X.Y.Z, Z > 0)

1. Go to **Actions → 🩹 Prepare Patch → Run workflow**. This creates
   `patch/vX.Y.(Z+1)` from the latest release tag and opens a PR that bumps the
   `<VersionPrefix>` on that branch. Merge the prepare PR.
2. Add the fix and its reviewed dated changelog entry to `patch/vX.Y.(Z+1)` via
   normal PRs targeted at that branch.
3. Go to **Actions → 🚀 CD Production → Run workflow**. Leave the branch picker
   on `main` (so the workflow file runs from main) and set `ref` to
   `patch/vX.Y.(Z+1)`.
4. Approve the production environment when prompted.
5. On success the workflow tags `vX.Y.(Z+1)`, creates the GitHub Release, and
   opens `chore: merge vX.Y.(Z+1) into main`. Review and merge that PR.

The workflow definition and shared validation action come from the dispatched
`main` workflow commit; application files and release/deployment scripts come
from the resolved protected source commit. Ensure patch branches contain
compatible deployment and release code, including `.node-version`,
`scripts/check-node.mjs`, the changelog tooling, `publish-release.sh`, and the
`/api/about` source revision used by the browser smoke test. Backport that
tooling before releasing a patch based on a tag that predates it. A patch release
still uses `main` in
the workflow branch picker.

## What the production workflow validates

It detects whether the selected source is a standard or patch release from the
version number itself (`Z == 0` → standard, `Z > 0` → patch) and checks:

- Version in `Directory.Build.props` is plain `X.Y.Z`
- For standard: ref is `main`, version is greater than the latest stable release
- For patch: ref is `patch/v<version>`, the version is the next patch in line,
  and that line is the latest deployed line
- Any existing `vX.Y.Z` tag points at the same commit (idempotent reruns)
- A nonempty, dated changelog entry exists for that exact version

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
