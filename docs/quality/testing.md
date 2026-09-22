# Testing

Tests exercise public behavior, not private methods or framework implementation
details. They run locally and in CI without starting Aspire, opening network
ports, trusting certificates, using Docker, or supplying production credentials.
See [developer setup](../setup/development.md) for SDK prerequisites.

## Project boundaries

| Project | Responsibility |
| --- | --- |
| `tests\OpenGameBuilder.Api.Tests` | In-process HTTP integration tests of the real API, including a real API-client round trip |
| `tests\OpenGameBuilder.Api.Client.Tests` | Client registration, configuration, JSON contracts, HTTP/transport failures, and cancellation |

Component tests and a published-app browser smoke test accompany the first
functional frontend feature, as scoped in section 6 of the
[foundation checklist](../foundation-checklist.md). The placeholder page does
not need a dedicated test project or browser infrastructure.

[`tests/Directory.Build.props`](../../tests/Directory.Build.props) imports the
repository-wide build properties and supplies the common test flags, xUnit
reference, global using, and Visual Studio adapter. Each test project declares
only its own production references and additional dependencies. Package versions
remain in [`Directory.Packages.props`](../../Directory.Packages.props), and the
same compiler warnings-as-errors policy applies to tests and production code.

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
[validation action](../../.github/actions/validate/action.yml), so restore,
formatting verification, Release build, and solution tests cannot drift between
the two paths. The local equivalents are in
[developer setup](../setup/development.md#command-line-workflow-start-here).

A failing phase fails the job. Available console logs and a formatting report
are uploaded on failure and retained for seven days; assertion details are in
`test.log`. The test command uses the repository's Microsoft.Testing.Platform
runner without adding a separate test-reporting dependency.

Release-script behavior has an additional Bash test gate:

```pwsh
bash tests/release-scripts/run.sh
```

Run this with Git Bash on Windows. The suite creates temporary local Git
repositories, mocks GitHub CLI calls and Git pushes, and never publishes a
branch, tag, or release. CI and deployment validation run it after the solution
tests and upload its log on failure.

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
Deployment additionally runs a Chromium smoke test from `tests/deploy-smoke` that
loads the published frontend, observes its API request, and checks the expected
source revision. That live test requires a deployed staging or production URL.

Supply-chain declarations have an additional deterministic check:

```pwsh
& 'C:\Program Files\Git\bin\bash.exe' tests/supply-chain/run.sh
```

It rejects third-party Actions that are not full commit SHAs, mutable API base or
edge image references, a missing explicit API user, deployment-time
`ssh-keyscan`, inherited NuGet source mappings, or missing Dependabot ecosystems.
It also checks that the API-image group patterns match Dependabot's normalized
dependency names (without their registry). CI loads the locally built API image and runs
`scripts/verify-api-image.sh`; that Docker-backed check verifies the runtime user,
application-directory permissions, startup, and `/api/alive`.

The stable required PR check is `build-test`. Workflow success alone does not
make it a merge gate: GitHub must require that check and enforce human review.
See [GitHub setup](../setup/github.md) for the inspected settings, administrator
configuration, and main/patch PR acceptance procedure.
