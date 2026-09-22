# Versioning

OpenGameBuilder uses plain semantic versions:

```text
MAJOR.MINOR.PATCH
```

No prerelease or build metadata is used for release versions. The `v` prefix is
used only for Git tags and `patch/v*` branch names.

## Source of truth

The version lives in `Directory.Build.props`:

```xml
<VersionPrefix>1.9.0</VersionPrefix>
```

`Version` is derived from `VersionPrefix`. Do not edit `<Version>` directly.

## Branch policy

- `main` holds the **next** standard release version (patch is always `0`).
  - After releasing `v1.9.0`, `main` is bumped to `1.10.0`.
- `patch/vX.Y.Z` branches hold the exact version named in the branch.
  - `patch/v1.9.1` must have `<VersionPrefix>1.9.1</VersionPrefix>`.

Normal work uses short-lived PR branches from protected `main`; there is no
permanent `develop`. See [contribution guidance](../../CONTRIBUTING.md#branches-and-release-notes)
for drafts, descriptive PR titles, squash merges, and branch cleanup. Changelog
preparation reads `VersionPrefix`; it never chooses or bumps a version. The
existing prepare-patch and post-release PRs remain responsible for version changes.

## Tags

Release tags have the form `vX.Y.Z`. They are created exclusively by the
**CD Production** workflow after a successful production deploy. Do not create
release tags manually.

## What counts as a successful release

A release is only successful after, in order:

1. Version and prepared changelog validation pass
2. The release commit builds and tests pass
3. The release commit deploys to production
4. The production smoke test passes
5. The `vX.Y.Z` tag is created
6. The GitHub Release is created
7. The follow-up PR (bump or merge-back) is opened

Steps 5–7 happen only when steps 1–4 succeed. This is intentional.
