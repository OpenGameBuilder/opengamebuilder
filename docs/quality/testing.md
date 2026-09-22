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
formatting verification, Release build, solution tests, and smoke-package checks
cannot drift between the two paths. The solution commands are in
[developer setup](../setup/development.md#command-line-workflow-start-here).

PR validation also publishes the frontend in Release using the completed build
and runs [the portability guard](../../scripts/verify-web-publish.sh). Deployment
disables this extra publish in the shared action because its required `package`
job already publishes and checks the frontend before any deployment job runs.
Both paths reject environment-specific configuration in the published artifact.

After the solution gate, run these local equivalents from the repository root
with Git Bash and Node.js 22/npm available:

```pwsh
dotnet publish src/OpenGameBuilder.Web.Client/OpenGameBuilder.Web.Client.csproj --configuration Release --no-build --output artifacts/web
& 'C:\Program Files\Git\bin\bash.exe' scripts/verify-web-publish.sh artifacts/web/wwwroot
npm ci --prefix tests/deploy-smoke
node --check tests/deploy-smoke/smoke.mjs
```

The Node checks install the locked smoke dependencies and parse `smoke.mjs`;
they do not install or launch a browser. These build/package checks need no
deployment credentials or public URL and do not establish browser acceptance.
The deployment job still installs dependencies and Chromium on its own runner
before activation. Live browser smoke runs after activation and can trigger
recovery if it fails.

A failing phase fails the job. Available console logs and a formatting report
are uploaded on failure and retained for seven days; assertion details are in
`test.log`. The shared action also captures `web-publish.log`,
`web-configuration.log`, `smoke-dependencies.log`, and `smoke-syntax.log` for
the new checks when they run. The test command uses the repository's
Microsoft.Testing.Platform runner without adding a separate test-reporting dependency.

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
First-deployment cases cover partial startup failure, recovery after activation
(the browser-smoke failure boundary), successful retry, cleanup failure, and
missing or corrupt expected predecessor state. These checks run without SSH or
Docker services; they do not establish live browser or staging acceptance.
Deployment additionally runs a Chromium smoke test from `tests/deploy-smoke` that
loads the published frontend, observes its API request, and checks the expected
source revision. That live test requires a deployed staging or production URL.

### Browser-smoke dependency updates

[Dependabot](../../.github/dependabot.yml) checks `/tests/deploy-smoke` weekly,
using the repository's dependency-update cadence and cooldowns. Its npm entry
targets the directory containing both `package.json` and `package-lock.json`, as
described in [GitHub's configuration reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#directories-or-directory).
After merging configuration changes, check GitHub's Dependabot update-job list
for that npm directory and inspect its first run for configuration errors.

For Playwright updates, review the release notes and the manifest/lockfile diff,
then run the `npm ci` and syntax commands above with Node.js 22. Dependency PRs
receive the same required `build-test` validation. Package installation and
syntax checks do not establish compatibility with the updated Chromium build.
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
