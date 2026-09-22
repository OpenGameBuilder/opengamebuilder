# OpenGameBuilder agent guidance

## Start here

Use [developer setup](docs/setup/development.md) for the supported Windows workflow
and [testing guidance](docs/quality/testing.md) for test boundaries. The normal
local gate is:

```pwsh
dotnet restore opengamebuilder.slnx
dotnet format opengamebuilder.slnx --verify-no-changes --no-restore
dotnet build opengamebuilder.slnx --configuration Release --no-restore
dotnet test --solution opengamebuilder.slnx --configuration Release --no-build
```

The selected .NET SDK comes from `global.json`. Install the Aspire CLI required
by `.mcp.json` before using an Aspire MCP client or local orchestration, then
verify it from the repository root:

```pwsh
dotnet tool install --global Aspire.Cli --version 13.4.2
aspire --version
```

If `aspire` is newly installed, reopen the terminal if it is not on `PATH`.
The setup guide is authoritative for prerequisites, certificate trust, endpoint
checks, and editor debugging.

Before changing vendored skills or agent setup, read
[AI tooling maintenance](docs/setup/ai-tooling.md) for source pins, licenses,
update steps, and supported local-agent scope. Generic cloud/deployment skills
do not override this repository's workflows or authorization requirements.

## Project map and boundaries

- `src/OpenGameBuilder.Api.Contracts`: browser-compatible API DTOs; no server or
  UI behavior.
- `src/OpenGameBuilder.Api.Client`: typed HTTP client and configuration; depends
  on Contracts, not the API host.
- `src/OpenGameBuilder.Api`: ASP.NET Core host and endpoints; depends on Contracts
  and ServiceDefaults.
- `src/OpenGameBuilder.Web.Client`: standalone Blazor WebAssembly UI; depends on
  Api.Client and uses static environment configuration.
- `src/OpenGameBuilder.ServiceDefaults`: shared service resilience and telemetry
  defaults for service hosts.
- `src/OpenGameBuilder.AppHost`: local Aspire orchestration for the API and web
  client; it is not production hosting.
- `tests`: API integration and API-client behavior tests. Keep game logic
  independent of Blazor, HTTP, and storage as engine work begins.

The original-client archive is separate from this implementation. Follow
[AI policy](AI_POLICY.md) and [MyGameBuilder documentation](docs/mygamebuilder/)
for preservation and source-material boundaries; do not derive implementation
code from decompiled original-client source.

## Scope and operations

Before v1, prefer the simplest current design. Breaking changes are acceptable;
remove superseded code and configuration rather than adding compatibility layers.
Add infrastructure only for a current feature, and document current behavior and
decisions instead of retaining obsolete guidance.

Aspire is the local launcher. Production currently uses Compose files under
`deploy`; see [hosting](docs/setup/hosting.md) and [GitHub setup](docs/setup/github.md).
Obtain explicit authorization before deploying, releasing, handling credentials,
or performing destructive operations. Documentation-only work does not start
Aspire, Docker, browsers, or other services.

For behavior, testing, security, privacy, and AI-use requirements, follow
[AI_POLICY.md](AI_POLICY.md), [CONTRIBUTING.md](CONTRIBUTING.md), and the
repository's CI configuration. Review the diff and run the relevant validation
before reporting completion.
