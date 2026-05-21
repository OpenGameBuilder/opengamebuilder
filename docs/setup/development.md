# Developer Setup

- **[Visual Studio 2026+](https://visualstudio.microsoft.com/vs/)** (Community is fine) with the **ASP.NET and web development** workload (the repo ships a [`.vsconfig`](.vsconfig) so Visual Studio will offer to install missing components automatically when you open the solution.
- Alternatively, you can use **[Visual Studio Code](https://code.visualstudio.com/)** with the C# extension.
- [.NET SDK 10.0.300+](https://dotnet.microsoft.com/download) (see [global.json](global.json)). Visual Studio 2026 already includes a compatible SDK.
- [Git for Windows](https://git-scm.com/download/win) (ships the `sh` interpreter the pre-commit hook needs).

One-time setup: trust the local HTTPS dev certificate:

```pwsh
dotnet dev-certs https --trust
```

## Getting started (Visual Studio)

1. Clone the repo and open **`opengamebuilder.slnx`** in Visual Studio (open the *solution file*, not the folder).
2. When prompted, let Visual Studio install any missing components from [`.vsconfig`](.vsconfig).
3. In the Solution Explorer toolbar's startup-project dropdown, pick **Full-stack** (defined in [`opengamebuilder.slnLaunch`](opengamebuilder.slnLaunch)). This starts the API and the Blazor WASM client together.
4. Press <kbd>F5</kbd>:
   - The API launches on `https://localhost:7000` and opens **Scalar** at `/scalar`.
   - The Web client launches on `https://localhost:7001`.

To run just one project, set it as the single startup project from the same dropdown.

The first build also bootstraps local tools (Husky.NET) and installs the git pre-commit hook, no manual step required.

## Getting started (VS Code)

1. Open the repo folder in VS Code.
2. Accept the prompt to install recommended extensions ([`.vscode/extensions.json`](.vscode/extensions.json)).
3. Press <kbd>F5</kbd> and choose **Launch All (API + Web)**, or run individual configs:
   - **Launch API** - starts the API on `https://localhost:7000`, opens Scalar at `/scalar`.
   - **Launch Web (Blazor WASM)** - starts the Blazor WebAssembly app on `https://localhost:7001`.

## Debugging

Launching the projects automatically attaches the debuggers. Note that Blazor WASM debugging is only supported in Chromium-based browsers.
