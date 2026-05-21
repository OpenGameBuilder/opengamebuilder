# OpenGameBuilder

An open-source community reimplementation of the original 2007-2011 Flash site mygamebuilder.com!

> Status: **under construction**.

## Endpoints

| Endpoint | Description |
| --- | --- |
| `GET /health` | Liveness probe — returns status, service name, version, UTC timestamp. |
| `GET /scalar` | Interactive API explorer (dev only). |
| `GET /openapi/v1.json` | OpenAPI document. |

## Common tasks

Run from Visual Studio's **Developer PowerShell** (View → Terminal), or from any shell at the repo root:

| Task | Command |
| --- | --- |
| Build everything | `dotnet build` |
| Run tests | `dotnet test` |
| Format code | `dotnet format` |
| Verify formatting (no changes) | `dotnet format --verify-no-changes` |
| Hot-reload API | `dotnet watch --project src/OpenGameBuilder.Api run` |
| Hot-reload Web | `dotnet watch --project src/OpenGameBuilder.Web run` |

For secrets in local development, prefer [`dotnet user-secrets`](https://learn.microsoft.com/aspnet/core/security/app-secrets) over `.env` files (which are gitignored but not loaded by ASP.NET Core).

## Code style & pre-commit hook

- [.editorconfig](.editorconfig) drives formatting and naming rules; Visual Studio and VS Code both honor it.
- A git **pre-commit hook** runs `dotnet format` on staged `*.cs` files via [Husky.NET](https://alirezanet.github.io/Husky.Net/). It's installed automatically on first build, or manually with:

  ```pwsh
  dotnet tool restore
  dotnet husky install
  ```
- The hook is a POSIX `sh` script. On Windows, **Git for Windows** is required so the hook can run.
- CI also runs `dotnet format --verify-no-changes` to fail PRs with unformatted code.
- To skip hooks for a single commit: `git commit --no-verify` (use sparingly).
- To disable the auto-bootstrap on a machine: set the `HUSKY=0` environment variable.

## Repository layout

```
src/
  OpenGameBuilder.Api/   ASP.NET Core API (Scalar/OpenAPI)
  OpenGameBuilder.Web/   Blazor WebAssembly client
tests/
  OpenGameBuilder.Api.Tests/
  OpenGameBuilder.Web.Tests/
```
