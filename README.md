# OpenGameBuilder

An open-source community reimplementation of the original 2007-2011 Flash site mygamebuilder.com!

> Status: **under construction**.

## Developer Setup

- **Visual Studio 2026+** (Community is fine) with the **ASP.NET and web development** workload — the repo ships a [`.vsconfig`](.vsconfig) so Visual Studio will offer to install missing components automatically when you open the solution.
- [.NET SDK 10.0.300+](https://dotnet.microsoft.com/download) (see [global.json](global.json)). Visual Studio 2026 already includes a compatible SDK.
- [Git for Windows](https://git-scm.com/download/win) (ships the `sh` interpreter the pre-commit hook needs).

One-time setup — trust the local HTTPS dev certificate:

```pwsh
dotnet dev-certs https --trust
```

## Getting started (Visual Studio)

1. Clone the repo and open **`opengamebuilder.slnx`** in Visual Studio (open the *solution file*, not the folder).
2. When prompted, let Visual Studio install any missing components from [`.vsconfig`](.vsconfig).
3. In the Solution Explorer toolbar's startup-project dropdown, pick **Full-stack** (defined in [`opengamebuilder.slnLaunch`](opengamebuilder.slnLaunch)). This starts the API and the Blazor WASM client together.
4. Press <kbd>F5</kbd>:
   - The API launches on `https://localhost:7000` and opens **Scalar** at `/scalar`.
   - The Web client launches on `https://localhost:7001` with the Blazor WASM JS debugger attached.

To run just one project, set it as the single startup project from the same dropdown.

The first build also bootstraps local tools (Husky.NET) and installs the git pre-commit hook — no manual step required.

## Getting started (VS Code)

1. Open the repo folder in VS Code.
2. Accept the prompt to install recommended extensions ([`.vscode/extensions.json`](.vscode/extensions.json)).
3. Press <kbd>F5</kbd> and choose **Launch All (API + Web)**, or run individual configs:
   - **Launch API** — starts the API on `https://localhost:7000`, opens Scalar at `/scalar`.
   - **Launch Web (Blazor WASM)** — starts the Blazor WebAssembly app on `https://localhost:7001`.

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
