# Dependency-update lockfile research

## Question and observed failure

Researched on 2026-09-22.

[PR #115](https://github.com/OpenGameBuilder/opengamebuilder/pull/115) updated
centrally managed OpenTelemetry versions, refreshed the API lock,
and left the API integration-test lock and the two AppHost RID-specific locks
stale. [Locked restore then failed](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35745905146/job/106807351851).
A fresh regeneration of those three locks in a temporary copy of the CI merge
commit `a74bd33288f1c6d0c57ca72a99a3c0625f7c4fd4`
followed by locked restore succeeds for both the Windows and Linux-selected
AppHost graphs. The repository now uses a narrower policy that keeps committed
locks for the shipped API and Web Client while allowing tests and the local-only
AppHost to resolve dependencies normally.

## Evidence

NuGet documents that a lock captures the resolved dependency graph, including
changes from a dependent project's files, and that locked restore rejects an
inconsistent graph. Its default lock name is `packages.lock.json`; a project can
set `NuGetLockFilePath` or use `--lock-file-path` to select a different path.
[NuGet lock files](https://learn.microsoft.com/nuget/consume-packages/package-references-in-project-files#lock-file-extensibility)

Dependabot issue [#13950](https://github.com/dependabot/dependabot-core/issues/13950)
is open and describes this exact Central Package Management plus
`ProjectReference` case: it updates some locks but not a downstream project's
lock, which makes `RestoreLockedMode=true` fail with NU1004. As of this research,
the issue has no resolution or linked fix.

GitHub supports the `nuget` Dependabot ecosystem, but its public configuration
reference has no option to run a post-update restore, select a NuGet lock-file
path, or enumerate custom/RID lock files.
[Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
This is evidence that there is no documented `dependabot.yml` remedy, rather
than proof that no internal behavior could change.

The current Dependabot NuGet updater itself runs a forced restore for a project
when it refreshes a lock.
[LockFileUpdater.cs at 098c329](https://github.com/dependabot/dependabot-core/blob/098c32944988dba7a697eda66da30c2a62b1dff6/nuget/helpers/lib/NuGetUpdater/NuGetUpdater.Core/Updater/LockFileUpdater.cs)
That does not resolve #13950's incomplete downstream selection or establish
support for this repository's custom AppHost paths.

Renovate documents NuGet `packages.lock.json` maintenance, central package
versions, and its source builds a `ProjectReference` dependency tree before
restoring dependent projects.
[Renovate NuGet manager](https://docs.renovatebot.com/modules/manager/nuget/)
[artifact updater at 3b70d5f](https://github.com/renovatebot/renovate/blob/3b70d5ffe2c2a0d5284f57d40fa687c751b56f0b/lib/modules/manager/nuget/artifacts.ts)
However, the same source derives only sibling `packages.lock.json` paths.
Therefore current source supports the test's ordinary lock more directly than
Dependabot, but does not establish support for `NuGetLockFilePath` or the
AppHost's `packages.win-x64.lock.json` and `packages.linux-x64.lock.json`.
This is a source-based inference, not a Renovate compatibility guarantee.

## Implemented policy

The lock policy is now limited to the shipped API and Web Client. Central
package versions, exact SDK selection, their committed lockfiles, and locked
packaging remain in place. Tests and the local-only AppHost no longer opt into
lockfiles, and their former locks are not retained. The AppHost remains in the
solution build, and both test projects still run in CI.

When the solution is restored with `--locked-mode`, NuGet rejects a stale or
missing lock for the opted-in API and Web Client. Projects that do not opt into
lockfiles use normal dependency resolution during that same restore. The
repository does not suppress NU1004 or keep ignored development locks.

The tradeoff is reduced repeatability for test and AppHost transitive dependency
resolution. Their resolved graphs can differ between restores and from the
shipped application graphs. Their builds and tests still run; production
dependency drift still fails locked restore. For this repository's current size,
that is a proportionate tradeoff and does not require a privileged
dependency-repair service. This policy is a project-specific judgment, not a
NuGet rule that test executables should never have lockfiles.

This removes the lockfile failure patterns demonstrated by PR #115. It does not
guarantee that Dependabot will correctly update every future production lockfile
or that a package or SDK update will pass all checks. A failure in either area
still requires investigation.

## Automation boundary

No bot write-back automation is configured. Reconsider complete lock
regeneration only if reproducible test or orchestration graphs become a
demonstrated requirement, or if ordinary shipped-application locks repeatedly
need completion and the manual cost warrants an owned automation. Such a system
would add credential maintenance, changed-head handling, and CI-trigger
behavior.

GitHub documents that PR events created by a workflow using `GITHUB_TOKEN`
require approval to run the resulting workflows; a GitHub App installation
token can trigger those checks automatically.
[Workflow triggering rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow)
Therefore fully unattended write-back would need an authentication or explicit
dispatch design beyond a lock-refresh script. CI validates the committed result
rather than silently repairing locks inside its workspace.

## Validation evidence

A fresh temporary copy of the exact PR #115 CI merge commit applied the narrowed
policy while leaving both shipped-application locks unchanged. On Windows,
`pwsh ./scripts/check.ps1 quick -Serial` passed its restore, C# formatting,
zero-warning Release build, and all 72 tests. Solution restore with
`--locked-mode` also passed with the default Windows SDK RID and with an
explicit `NETCoreSdkRuntimeIdentifier=linux-x64`; no development lockfiles were
regenerated. A deliberately mismatched API dependency still failed with NU1004,
confirming that the shipped-application guard remained active.

Missing API and Web Client locks were each rejected without regenerating them,
and a stale API lock was rejected. This historical snapshot establishes the
policy's behavior for the failure that motivated the change. It is not a
Linux-host execution or a hosted Dependabot rehearsal.

The implemented policy subsequently passed the repository's full local check,
including all 72 tests, frontend packaging, content and CI policy regressions,
and all five shell suites. The API and Web Client lockfiles were unchanged.

## Limits

This research does not claim that a GitHub App, Renovate deployment, or future
upstream release is configured or suitable here. Re-evaluate the decision when
Dependabot #13950 is resolved or when a dependency manager documents support
for custom NuGet lock paths and multi-RID regeneration.
