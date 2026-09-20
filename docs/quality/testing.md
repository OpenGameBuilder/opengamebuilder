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

The stable required PR check is `build-test`. Workflow success alone does not
make it a merge gate: GitHub must require that check and enforce human review.
See [GitHub setup](../setup/github.md) for the inspected settings, administrator
configuration, and main/patch PR acceptance procedure.
