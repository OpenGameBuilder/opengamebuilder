# Testing

Tests exercise public behavior, not private methods or framework implementation
details. They run locally and in CI without starting Aspire, opening network
ports, trusting certificates, using Docker, or supplying production credentials.
See [developer setup](../setup/development.md) for SDK prerequisites.

## Project boundaries

| Project                                  | Responsibility                                                                                |
| ---------------------------------------- | --------------------------------------------------------------------------------------------- |
| `tests\OpenGameBuilder.Api.Tests`        | In-process HTTP integration tests of the real API, including a real API-client round trip     |
| `tests\OpenGameBuilder.Api.Client.Tests` | Client registration, configuration, JSON contracts, HTTP/transport failures, and cancellation |

The existing deployment smoke below checks published frontend startup and a
real API round trip in Chromium. Component tests and broader browser coverage
for loading, success, network failure, and invalid responses accompany the first
functional frontend feature. See the
[browser and accessibility matrix](../frontend/browser-support.md) for recorded
evidence, unverified targets, and the manual checks required as the editor develops.

[`tests/Directory.Build.props`](../../tests/Directory.Build.props) imports the
repository-wide build properties and supplies the common test flags, xUnit
reference, global using, and Visual Studio adapter. Each test project declares
only its own production references and additional dependencies. Package versions
remain in [`Directory.Packages.props`](../../Directory.Packages.props), and the
same compiler warnings-as-errors policy applies to tests and production code.

## Frontend asset cleanup evidence

On 2026-09-22, source inspection found no consumers for the removed form-validation,
Bootstrap placeholder, or `code` styles in
[`app.css`](../../src/OpenGameBuilder.Web.Client/wwwroot/css/app.css).
Loading and error styles remain. C# and startup HTML changes were limited to
comments; active service defaults, endpoints, and launch profiles were preserved.
Restore, format verification, Release build (zero warnings), all 72 .NET tests,
frontend Release publish, and the published-configuration guard passed. Local
documentation paths and anchors also resolved. This establishes local cleanup
and packaging evidence, not a new browser or accessibility acceptance result.

## CodeQL build coverage

The repository-owned [CodeQL workflow](../../.github/workflows/codeql.yml) traces
a real Release build of the solution for C#, including Razor-generated sources.
It installs the SDK selected by `global.json`, restores without a persistent
dependency cache, and forces a non-incremental build after initializing CodeQL.
This avoids the synthetic Razor compilation used by no-build extraction, which
logged a compiler exit-code error even in successful analyses. Actions analysis
still uses no-build mode because it does not compile C#.

A passing local Release build does not prove CodeQL extraction or upload. Check
the first hosted PR run's C# build, analysis output, and source coverage after
changing this workflow. Do not treat a green check as proof that its logs contain
no extraction errors.

GitHub's separately managed **CodeQL - Code Quality** workflow is configured
outside this repository. Its documented settings do not expose the same manual
build-mode control. Keep that coverage enabled; if its synthetic Razor compiler
diagnostic persists, retain the run URL for GitHub Support rather than disabling
analysis or claiming this repository change fixed that managed workflow. See
[Code Quality configuration](https://docs.github.com/en/code-security/how-tos/maintain-quality-code/enable-code-quality).

## CI and deployment validation

[CI](../../.github/workflows/ci.yml) and
[deployment validation](../../.github/workflows/_deploy.yml) use the same
[validation action](../../.github/actions/validate/action.yml) and canonical
commands. Start with the local equivalents:

```pwsh
pwsh ./scripts/check.ps1 quick
pwsh ./scripts/check.ps1 full
pwsh ./scripts/check.ps1 full -Serial
```

See [first-party content checks](content-checks.md) for the pinned tool setup,
formatter ownership, offline link checks, and separate external-link reports.
Run `pwsh ./scripts/setup-content.ps1` once before those checks. `content` runs
that gate without requiring .NET or deployment tools. `full` includes it, its
deliberate-defect regression tests, and the CI selection/gate regressions in
[`tests/ci-policy`](../../tests/ci-policy/check.test.mjs).

### PR lanes and the required gate

CI starts for every PR, with no workflow-level path filter. Its selection job
compares the full Git merge-base-to-head range with rename detection disabled,
so both sides of a rename are checked. Only changes consisting entirely of
Markdown files at the repository root or under `docs/` select the documentation
lane. An empty range, any other path, patch-branch push, or manual run selects
full validation. A failed comparison fails selection and the required gate;
it cannot silently skip validation. The selector logs the paths and decision.

| Selection     | Required validation                                                                                                                                                                                                                                 |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Documentation | Ubuntu runs `check.ps1 content` and `check-docs.ps1`: source formatting, lint, workflow/shell checks, local Markdown links, and the DocFX site with rendered link/anchor and search checks. No application solution build or container runs.        |
| Full          | Windows runs `check.ps1 quick -Serial` for locked restore, C# format, Release build, and tests. Ubuntu runs `check.ps1 full`, `check-docs.ps1`, the published-browser harness in Chromium/Firefox/WebKit, then builds and checks the API container. |

Both platforms restore and build the entire solution, including the AppHost,
and run both test projects. Only the shipped API and Web Client have committed
NuGet locks. Tests and the local-only AppHost resolve their dependencies normally;
their transitive graphs are not frozen. See the
[lockfile policy](../setup/development.md#command-line-workflow-start-here).
The shared action installs the exact SDK in a fresh runner-temporary directory
using [`DOTNET_INSTALL_DIR`](https://github.com/actions/setup-dotnet#environment-variables).
This prevents preinstalled Visual Studio workload manifests from selecting an
older WebAssembly pack and breaking locked restore despite a matching SDK version.
Shell suites, frontend packaging, browser checks, and Docker runtime checks
stay in the Linux lane. Deployment still uses the full shared action, with its
separate required frontend packaging job. Neither path starts Aspire.

The stable **`build-test`** check aggregates selection and all three possible
lanes. Its `always()` job condition lets it evaluate failed or skipped dependencies,
as described by [GitHub's job dependency rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs).
It requires selection and every selected lane to report `success`, and each
unselected lane to report `skipped`. Failure, cancellation, missing results, and
unexpected skips fail the gate. Whole-run cancellation or runner loss may stop
the gate itself; neither supplies a passing required check. Require `build-test`
in branch protection, not the conditional lane names.

Run the selector and aggregate regression checks independently with:

```pwsh
node --test tests/ci-policy/check.test.mjs
```

These tests exercise real temporary Git histories and lane-result combinations;
they do not prove GitHub scheduling or merge enforcement. The hosted acceptance
procedure is in [GitHub setup](../setup/github.md#ci-merge-gate).

### Documentation site validation

Run `pwsh ./scripts/check-docs.ps1` after installing the content prerequisites.
It restores the pinned DocFX tool, builds the existing guides with warnings as
errors, checks rendered links and anchors offline, and verifies search entries
and edit links against the original Markdown. Regression fixtures require an
unresolved document, missing rendered page, renamed anchor, missing stylesheet,
missing search entry, and accidentally included temporary plan to fail.
Additional fixtures check relative page links and repository-source links at two
different commits, reject omitted documentation and assets, and preserve the
source Markdown. See the [link resolution rules](../setup/documentation.md#build-and-check).

Both selected Ubuntu lanes run this command through the documentation action;
the required `build-test` check cannot pass when it fails. The `ci-docs` artifact
retains the rendered site and available logs for seven days. The command does
not start an application or browser. See [documentation maintenance](../setup/documentation.md)
for preview, publication, and the separate hosted acceptance procedure. It is
separate from `check.ps1 full`, so application deployment validation does not
acquire an unrelated site build.

### Recorded platform CI acceptance

The [clean hosted run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35748017596)
at `1bb104c` passed both Windows and Linux lanes and the required `build-test`
aggregate on 2026-09-22. Each platform passed locked restore, format verification,
a Release solution build, and all 72 .NET tests. Linux also passed content and
policy regressions, frontend packaging, all five shell suites, and the API image
runtime/liveness check. The temporary failing test is absent from this revision.

| Platform           | Runner image                  | Selected SDK |
| ------------------ | ----------------------------- | ------------ |
| Windows 10.0.26100 | `win25-vs2026 20260907.229.1` | 10.0.401     |
| Ubuntu 24.04.5 LTS | `ubuntu24 20260907.300.1`     | 10.0.401     |

On 2026-09-22, the [Windows restore failure](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35747546367)
demonstrated that a failed required lane makes `build-test` fail even when Linux
passes. The pinned SDK was 10.0.401, but the preinstalled Windows workload
manifests requested WebAssembly pack 10.0.11 instead of the locked 10.0.12.
The shared action now installs the SDK in a fresh temporary directory to avoid
that machine-level input. Lockfiles were not regenerated to accept the mismatch.
The seven-day Windows diagnostic artifact retained the restore error.

The [documentation-only run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35747186192)
passed content checks and `build-test` while both build lanes were skipped.
Its [temporary PR](https://github.com/OpenGameBuilder/opengamebuilder/pull/118)
targeted the implementation branch and was closed without merging.
Thirteen local policy regression groups cover Git change selection, failures,
cancellation, missing or unexpected results, and workflow wiring. Cancellation
coverage is deterministic regression evidence, not a hosted cancellation rehearsal.

GitHub's `main` rule still requires `build-test` from Actions app ID 15368;
`gh pr checks 117 --required` reported the failed aggregate as required.
The draft PR also reported `BLOCKED`; draft status is an additional independent
merge blocker. These checks do not establish Visual Studio/VS Code F5 support,
browser acceptance, deployment behavior, or a new non-bypass contributor rehearsal.

Local Windows validation also passed restore, format, a zero-warning Release
build, all 72 tests, the content gate and its seven regression groups, thirteen
CI policy groups, frontend publish/portability, smoke-package installation/syntax,
and all five isolated shell suites. This local evidence is separate from the
hosted runs above.

### Shared command coverage and diagnostics

`quick` is the normal solution gate: quick doctor checks, locked restore,
format verification, Release build, and the current 72 tests. `full` includes
that gate plus frontend Release publish and its portability guard, `npm ci`,
the deployment-smoke syntax check, PR browser-test discovery, and all five Bash
script suites. It requires Git for Windows/Git Bash, Git, Node.js 22 or newer,
npm, and the Docker CLI with Compose support. Node.js 24 is the recommended LTS
and CI baseline. It does not require a Docker daemon, deployment credentials,
services, or a browser.

Use `-Serial` when Windows task-host or pipe contention affects validation. It
serializes restore, build, and publish work and disables MSBuild node reuse;
the checks and their scope are otherwise unchanged.

Full PR validation also publishes the frontend in Release using the completed build
and runs [the portability guard](../../scripts/verify-web-publish.sh). Deployment
disables this extra publish in the shared action because its required `package`
job already publishes and checks the frontend before any deployment job runs.
Both paths reject environment-specific configuration in the published artifact.

The Node portion of `full` installs the locked smoke dependencies and parses
`smoke.mjs`; it does not install or launch a browser. These build/package checks
need no deployment credentials or public URL and do not establish browser
acceptance. The deployment job installs its dependencies and Chromium on its own
runner before activation. Live browser smoke runs after activation and can
trigger recovery if it fails.

A failing phase fails its lane and the required gate. Available console logs and a formatting report
are uploaded on failure and retained for seven days; assertion details are in
`test.log`. The shared action also captures `web-publish.log`,
`web-configuration.log`, `smoke-dependencies.log`, and `smoke-syntax.log` for
these checks when they run. `environment.log` records the OS, architecture,
runner image when available, command mode, and serialization setting;
`doctor.log` records selected SDK, PowerShell, and relevant tool versions.
Artifacts are named per lane and run attempt. API image runtime failures retain
`api-image.log` separately because that check follows the shared action. The
test command uses the repository's
Microsoft.Testing.Platform runner without adding a separate test-reporting dependency.

The five Bash suites exercised by `full` are `release-scripts`, `deploy-edge`,
`deploy-topology`, `deploy-app`, and `supply-chain`. Run an individual suite
with Git Bash when working on it, for example:

```pwsh
& 'C:\Program Files\Git\bin\bash.exe' tests/release-scripts/run.sh
```

The release-script suite creates temporary local Git
repositories, mocks GitHub CLI calls and Git pushes, and never publishes a
branch, tag, or release. CI and deployment validation run it after the solution
tests and upload its log on failure.

The release suite needs Node.js 22 or newer and the root tooling dependencies
(`npm ci --ignore-scripts`). It also runs [`tests/changelog`](../../tests/changelog/changelog.test.mjs)
and checks standard/patch publication with the selected curated entry, revision-bound
links, missing notes before mutation, tag-only recovery, completed reruns,
conflicting tags, failed lookups/pushes, and existing draft releases. Workflow
contract tests keep publication dependent on successful deployment and validation.
These are local fixtures and parsed-workflow checks, not hosted publication evidence.
The ordinary content gate validates changelog structure, including documentation-only
PRs; production validation additionally requires the exact version's prepared entry.

The host-edge apply script also has an isolated Bash test:

```pwsh
& 'C:\Program Files\Git\bin\bash.exe' tests/deploy-edge/run.sh
```

It mocks Docker and verifies invalid-candidate rejection, Caddyfile-only reload,
failed-reload restoration, intentional Compose updates, first-time setup, and
recovery of a stopped edge even when the candidate files are unchanged.
It also verifies environment/profile ownership and explicit migration approval.
CI runs it without SSH, Docker, deployment credentials, or service changes.
Live staging and production availability must still be checked by the deployment
smoke tests after the workflow change reaches `main`.

Host topology has a separate gate requiring the **Docker Compose CLI**, but not
a running Docker daemon, SSH, or deployment credentials:

```pwsh
& 'C:\Program Files\Git\bin\bash.exe' tests/deploy-topology/run.sh
```

It renders shared, staging-only, and production-only candidates and checks real
Compose normalization, image pins, stable certificate volumes, relative mounts,
and absence of the other environment from isolated profiles. Invalid/missing
profiles fail closed. Mocked curl tests ensure the edge readiness check targets
the selected SSH host even before DNS cutover. CI/deployment validation run it;
ordinary .NET tests still do not require Docker.

Application activation and rollback have an isolated host-script test:

```pwsh
& 'C:\Program Files\Git\bin\bash.exe' tests/deploy-app/run.sh
```

It uses temporary releases and a mocked Docker command to check legacy
migration, asset retention, rollback, API startup failure, and archive rejection.
First-deployment cases cover partial startup failure, recovery after activation
(the browser-smoke failure boundary), successful retry, cleanup failure, and
missing or corrupt expected predecessor state. These checks run without SSH or
Docker services; they do not establish live browser or staging acceptance.
Deployment additionally runs a Chromium smoke test from `tests/deploy-smoke` that
loads the published frontend, observes its API request, and checks the expected
source revision. That live test requires a deployed staging or production URL.

### Reproducible command validation

On 2026-09-22, a fresh source snapshot passed `pwsh ./scripts/check.ps1 full -Serial`
with SDK 10.0.401, PowerShell 7.6.5, and Node.js 22.23.2/npm 10.9.9. This covered
locked restore, format verification, a Release build with zero warnings, all 72
.NET tests, frontend Release publish and its portability guard, locked smoke
dependencies and syntax, and all five isolated shell suites. The serialized
option avoided a Windows MSBuild task-host failure; it did not omit checks.

Deliberately missing shipped-application locks and changed package requirements
stop restore before build. Doctor fixtures rejected a missing SDK,
wrong SDK selection/policy, Node 24, and non-exact or mismatched Playwright pins.
Missing smoke URL inputs failed before launching Chromium. PowerShell/YAML
parsing, changed documentation targets/anchors, and diff checks passed.

These were local command checks. Later hosted platform evidence is recorded in
[platform CI acceptance](#recorded-platform-ci-acceptance). No services,
deployments, certificate trust changes, or editor rehearsals were performed for
this local validation.

### Shipped-application lock policy validation

The narrower policy was tested against a fresh copy of the failing
[PR #115 CI revision](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35745905146/job/106807351851)
with its OpenTelemetry 1.19.1 update. Removing the test and AppHost lock opt-ins
and their four locks made solution restore pass with both Windows and
Linux-selected SDK RIDs. These restores ran on Windows; they are not Linux-host
execution evidence. The same snapshot passed `check.ps1 quick -Serial`, including
format verification, a Release build with zero warnings, and all 72 tests.

The implementation also passed `check.ps1 full -Serial` locally: the solution
gate, content checks and regressions, frontend publish/portability checks,
smoke-package checks, and all five isolated shell suites. Both committed
production lockfiles remained unchanged.

Missing API and Web Client locks were each rejected before restore could
regenerate them. A deliberately stale API dependency was rejected with NU1004.
No test or AppHost lockfiles were regenerated. These checks verify that the
shipped applications retain their lock guards while development graphs restore
normally; they do not guarantee that every future Dependabot update succeeds.

### Published-application browser checks

The [Playwright Test harness](../../tests/deploy-smoke/playwright.config.mjs)
runs in the Linux PR lane after the shared full check. It reuses that check's
Release-published frontend, publishes the real API without rebuilding, and runs
the three pinned engines. Browser failures fail the Linux lane and the required
`build-test` gate. Documentation-only PRs keep their content-only lane.

For a local run, use Node.js 22 or newer and the SDK from `global.json`; Node.js
24 is the recommended baseline. From the repository root, build and publish the
current source, then explicitly install the browser binaries and run the harness:

```pwsh
pwsh ./scripts/check.ps1 quick -Serial
dotnet publish src/OpenGameBuilder.Web.Client/OpenGameBuilder.Web.Client.csproj --configuration Release --no-restore --output artifacts/web -m:1
dotnet publish src/OpenGameBuilder.Api/OpenGameBuilder.Api.csproj --configuration Release --no-build --output artifacts/browser-api -m:1
npm ci --prefix tests/deploy-smoke
node tests/deploy-smoke/node_modules/playwright/cli.js install chromium firefox webkit
npm run test:pr --prefix tests/deploy-smoke
```

On Linux, install the engines' OS dependencies explicitly with Playwright's
`install --with-deps chromium firefox webkit`, as CI does. The test command does
not install software. `check.ps1 full` checks harness discovery with `--list`
without starting servers or browsers; the browser run remains a separate command.
The frontend publish must run its incremental build targets: `--no-build` can
leave Blazor's HTML asset placeholders unresolved. `--no-restore` reuses the
locked restore while retaining those required targets.

The harness serves a copy of the published frontend with a versioned release
base path and forwards same-origin `/api/*` requests to the real published API.
It supplies the checkout's source SHA through the API's existing `SOURCE_SHA`
deployment input. That checks the expected revision response; it is not an
independent binary-provenance check. Rebuild and republish after source changes.
Playwright owns the local server lifecycle and refuses to reuse existing servers.
This local proxy does not validate Caddy, TLS, SSH, or a public deployment.

The harness uses one worker, forbids focused tests, and allows at most one retry.
A pass on retry is reported as flaky and still fails the command. Deployment's
six-attempt startup policy stays in `smoke.mjs` and does not apply to PR tests.
Reports include exact browser, Playwright, OS, and source versions. The
`ci-browser-<attempt>` artifact retains HTML/JSON results, server/test logs,
failure screenshots, and traces for seven days, including reports from passing
runs. Local results are under `artifacts/browser/`.

No interactive application feature exists yet. Add a test of a meaningful action
and its visible result with the first such feature; startup coverage does not
complete that future acceptance. See [browser evidence](../frontend/browser-support.md)
for recorded runs and manual coverage boundaries.

For a focused check that the harness rejects broken deployments, run
`npm run test:negative --prefix tests/deploy-smoke` after publishing and installing
the engines. It injects four local faults: wrong `/api/about` routing, a broken
release base path, missing CSS, and a page that cannot start the application.
Each Chromium run must fail the intended assertion while retaining a successful
`/api/alive` response. The runner checks structured results rather than accepting
any nonzero exit, and retains each failure's log, report, screenshot, and trace
under `artifacts/browser/negative/`. All four cases passed on 2026-09-22 using
the [recorded local engine environment](../frontend/browser-support.md#recorded-local-engine-results).
This deliberate-failure check is separate from the normal three-engine PR run.

The implementation passed `check.ps1 full -Serial` on 2026-09-22: locked restore,
C# format, a zero-warning Release build, all 72 .NET tests, the content gate and
seven regression groups, fourteen CI-policy groups, fresh frontend publish and
portability checks, package/discovery checks, and all five shell suites. The
fresh publish then passed the six browser tests with no retries or flaky passes.
The first hosted run of the new browser steps remains unverified.

### Browser-smoke dependency updates

`pwsh ./scripts/check.ps1 browser` runs the existing
[`smoke.mjs`](../../tests/deploy-smoke/smoke.mjs) Chromium test against an
authorized, already deployed HTTPS release. It requires the pinned Playwright
Chromium browser to be installed and these environment variables:

```pwsh
$env:SMOKE_TEST_BASE_URL = 'https://authorized-release.example'
$env:EXPECTED_SOURCE_SHA = '<source-sha>'
$env:EXPECTED_RELEASE_ID = '<release-id>'
pwsh ./scripts/check.ps1 browser
```

Install the pinned test dependency and Chromium explicitly when needed:

```pwsh
npm ci --prefix tests/deploy-smoke
node tests/deploy-smoke/node_modules/playwright/cli.js install chromium
```

The browser command never deploys, installs a browser, or installs operating
system packages. On Linux, `--with-deps` remains an explicit operating-system
installation decision, as in the workflow. This smoke is evidence for the
specified release only; it is not broader browser or hosted acceptance.

[Dependabot](../../.github/dependabot.yml) checks `/tests/deploy-smoke` weekly,
using the repository's dependency-update cadence and cooldowns. Its npm entry
targets the directory containing both `package.json` and `package-lock.json`, as
described in [GitHub's configuration reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#directories-or-directory).
After merging configuration changes, check GitHub's Dependabot update-job list
for that npm directory and inspect its first run for configuration errors.

For an intentional Playwright update, use the exact-version command below,
review the release notes and manifest/lockfile diff, then run `full` with Node.js
22 or newer. Dependency PRs receive the same required `build-test` validation.

```pwsh
npm install --save-dev --save-exact playwright@<version> @playwright/test@<version> --prefix tests/deploy-smoke
```

Keep both packages at the same exact version; Dependabot groups them and doctor
checks their manifest and lockfile pins. Reinstall all three engines and run the
local harness after updates. Package installation, syntax, and discovery checks
do not establish compatibility with the updated browser builds.
Review the browser smoke result from an authorized staging deployment: the
release URL and base path, successful `/api/about` request, expected source
revision, API-backed heading, and absence of page errors. Record that workflow
run separately from the package checks; if it has not run, browser acceptance
remains unverified.

### Supply-chain declarations

Supply-chain declarations have an additional deterministic check:

```pwsh
& 'C:\Program Files\Git\bin\bash.exe' tests/supply-chain/run.sh
```

It rejects third-party Actions that are not full commit SHAs, mutable API base or
edge image references, a missing explicit API user, deployment-time
`ssh-keyscan`, inherited NuGet source mappings, or missing Dependabot ecosystems.
The npm declaration must cover `/tests/deploy-smoke` in the same update entry;
the check does not depend on a particular Playwright version.
It also checks that the API-image group patterns match Dependabot's normalized
dependency names (without their registry). CI loads the locally built API image and runs
`scripts/verify-api-image.sh`; that Docker-backed check verifies the runtime user,
application-directory permissions, startup, and `/api/alive`.

The stable required PR check is `build-test`. Workflow success alone does not
make it a merge gate: GitHub must require that check and enforce human review.
See [GitHub setup](../setup/github.md) for the inspected settings, administrator
configuration, and main/patch PR acceptance procedure.
