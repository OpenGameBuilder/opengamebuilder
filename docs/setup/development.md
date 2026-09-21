# Developer Setup

## Supported environment and prerequisites

The supported editor workflow in this guide is **Windows 11**, using PowerShell
with either Visual Studio 2026 or VS Code. Linux, macOS, and WSL development are
not yet validated by this guide; Linux CI builds do not establish editor or
browser-certificate support on those platforms.

- [Git for Windows](https://git-scm.com/download/win).
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0), version
  **10.0.401 or a compatible later 10.0 feature band**, as selected by
  [`global.json`](../../global.json). Run `dotnet --version` from the repository
  root to check the selected SDK. Update Visual Studio if its bundled SDK is older.
- **Aspire CLI 13.4.2**, the version used for this workflow and the AppHost SDK.
  The SDK and hosting package are separately versioned in the
  [AppHost project](../../src/OpenGameBuilder.AppHost/OpenGameBuilder.AppHost.csproj)
  and [`Directory.Packages.props`](../../Directory.Packages.props).
  If the CLI is not installed, run:

  ```pwsh
  dotnet tool install --global Aspire.Cli --version 13.4.2
  aspire --version
  ```

  Reopen the terminal after installation if `aspire` is not on `PATH`.
- Microsoft Edge or Google Chrome for Blazor WebAssembly debugging.
- For Visual Studio: **[Visual Studio 2026](https://visualstudio.microsoft.com/vs/)**
  (Community is fine), with **ASP.NET and web development**. The repository's
  [`.vsconfig`](../../.vsconfig) lists the components.
- For VS Code: **[VS Code](https://code.visualstudio.com/)** with the extensions in
  [`.vscode/extensions.json`](../../.vscode/extensions.json), including C# Dev Kit
  (which installs C# support) and the Blazor WASM debugging companion.

The current AppHost starts only the API and standalone Blazor WebAssembly
development server. **Docker, a database, production credentials, and Discord
access are not required.** Aspire is the local launcher, not the production
deployment mechanism.

When updating the SDK requirement in `global.json`, keep the API Dockerfile's
SDK image compatible. CI builds the API image without pushing it.

## Command-line workflow (start here)

Clone the repository, then run the remaining commands from its root:

```pwsh
git clone https://github.com/OpenGameBuilder/opengamebuilder.git
Set-Location opengamebuilder
dotnet --version
aspire --version
dotnet dev-certs https --trust
dotnet dev-certs https --check --trust
```

Accept the certificate trust prompt, then restart any open browser. Do not bypass
certificate errors: the browser must trust both the frontend and API HTTPS
connections. See Microsoft's
[development certificate guidance](https://learn.microsoft.com/aspnet/core/security/enforcing-ssl#trust-the-aspnet-core-https-development-certificate)
if the check fails.

Restore, check formatting, build, and test before starting services:

```pwsh
dotnet restore opengamebuilder.slnx
dotnet format opengamebuilder.slnx --verify-no-changes --no-restore
dotnet build opengamebuilder.slnx --configuration Debug --no-restore
dotnet build opengamebuilder.slnx --configuration Release --no-restore
dotnet test --solution opengamebuilder.slnx --configuration Release --no-build
```

Ordinary builds do not restore local tools or install Git hooks. The formatter
ships with the .NET SDK; no Husky installation is needed for these checks.
CI and shared deployment validation run the same formatting verification with
`HUSKY=0`, independently of contributors' hooks.

Tests use Microsoft.Testing.Platform, selected in `global.json`. To run only one
test project, replace `--solution opengamebuilder.slnx` with, for example,
`--project tests\OpenGameBuilder.Api.Tests\OpenGameBuilder.Api.Tests.csproj`.

The root `NuGet.Config` deliberately has one source, `nuget.org`, and clears
both inherited package sources and inherited package-source mappings. Its `*`
mapping means every package uses that one feed; it is not a claim of namespace
isolation between multiple feeds. CI restores on a clean runner. For a local
empty-cache check without changing the normal global packages folder, choose a
new temporary directory and run:

```pwsh
$packages = Join-Path $env:TEMP "opengamebuilder-packages-$([guid]::NewGuid())"
dotnet restore opengamebuilder.slnx --packages $packages --force --no-http-cache
```

Start Aspire from the repository root:

```pwsh
aspire run
```

[`aspire.config.json`](../../aspire.config.json) selects the AppHost; its default
`https` launch profile starts the dashboard, and
[`AppHost.cs`](../../src/OpenGameBuilder.AppHost/AppHost.cs) selects the API's
`OpenGameBuilder.Api` profile and the web client's `OpenGameBuilder.Web` profile.
The latter name is intentional even though the project is `OpenGameBuilder.Web.Client`.
Use the dashboard login URL printed by Aspire, then open the web endpoint below.
Stop with Ctrl+C before rebuilding or switching launch methods.

For a background session instead, use `aspire start`, `aspire wait api`,
`aspire wait web`, and `aspire ps`; finish with `aspire stop`.

### Expected endpoints and success check

| Endpoint | Purpose |
| --- | --- |
| `https://localhost:7001` | Frontend; the home heading shows `OpenGameBuilder <version> (Development)` after loading |
| `https://localhost:7000/api/about` | Application name, version, and API environment JSON |
| `https://localhost:7000/api/alive` | API liveness |
| `https://localhost:7000/scalar` | Interactive API documentation (Development only) |
| `https://localhost:17170` | Aspire dashboard with the default HTTPS profile; use the login URL printed by the launcher |

HTTP bindings also exist at `http://localhost:5000` (API) and
`http://localhost:5001` (web); use **HTTPS** for this workflow. The AppHost profile
also reserves dashboard HTTP port 15170 and telemetry/resource-service HTTPS
ports 21170 and 22170.

In browser developer tools, reload the home page and verify that
`https://localhost:7000/api/about` returns 200 and the heading displays the
application information. A healthy liveness endpoint alone does not prove the
frontend works.

The development-only API override is set in the web client's
[`appsettings.Development.json`](../../src/OpenGameBuilder.Web.Client/wwwroot/appsettings.Development.json),
and the API permits the web origins in its
[`appsettings.Development.json`](../../src/OpenGameBuilder.Api/appsettings.Development.json).
No local secrets or configuration edits should be needed.

**Run only one local stack at a time**, including across worktrees. The fixed
7000/7001 HTTPS ports are shared by the AppHost endpoints, launch profiles,
development override, and development CORS origins. Parallel local stacks are
not supported; Aspire's isolated mode does not change the browser override.

## Visual Studio

1. Complete the prerequisites and command-line build/test steps above, and stop
   any command-line services.
2. Open [`opengamebuilder.slnx`](../../opengamebuilder.slnx), not the repository
   folder. Accept any missing-component prompt from `.vsconfig`.
3. Choose **Aspire** in the startup-profile dropdown, as defined in
   [`opengamebuilder.slnLaunch`](../../opengamebuilder.slnLaunch). It starts
   `OpenGameBuilder.AppHost`, which launches both application projects. If the
   shared profile is not shown, set AppHost as the single startup project and
   select its **https** profile.
4. Press F5. Use the dashboard and open `https://localhost:7001`; perform the
   success check above. API documentation is available at `/scalar` whether or
   not a browser tab opens automatically.
5. Stop debugging before starting another launcher.

## VS Code

1. Complete the prerequisites and command-line build/test steps above.
2. Open the repository root with `code .` and install the recommended extensions.
3. For the same Aspire workflow as the command line, run `aspire run` in VS Code's
   integrated PowerShell terminal. This starts the stack but does not attach the
   VS Code debuggers automatically.
4. **Terminal > Run Build Task** runs `build-all`. **Tasks: Run Test Task** runs
   the `test` task using Microsoft.Testing.Platform and the Release configuration.
   Stop the application before running these tasks.
5. For F5 debugging without Aspire, use the explicit alternative below.

## Intentional alternative: run the projects without Aspire

Use this when you only need API/client debugging or hot reload without the
Aspire dashboard. It uses the same Development settings and endpoints, but has no
Aspire orchestration or aggregated telemetry. Stop Aspire first; do not mix these
launch methods.

For command-line launching, use two terminals at the repository root:

```pwsh
dotnet run --project src\OpenGameBuilder.Api\OpenGameBuilder.Api.csproj --launch-profile OpenGameBuilder.Api
```

```pwsh
dotnet run --project src\OpenGameBuilder.Web.Client\OpenGameBuilder.Web.Client.csproj --launch-profile OpenGameBuilder.Web
```

Stop both with Ctrl+C. For hot reload, VS Code provides the `watch-api` and
`watch-web` tasks; terminate both tasks when finished.

In VS Code, choose **Launch All (API + Web)** in Run and Debug and press F5.
The compound in [`.vscode/launch.json`](../../.vscode/launch.json) launches the two
projects directly, **not** AppHost. `Launch API` and `Launch Web (Blazor WASM)`
are also available individually; the frontend still needs the API running to
load its application information. Stop the compound to stop both debuggers.

In Visual Studio, use **Configure Startup Projects** to select the API and web
client for a local multiple-startup configuration instead of the shared Aspire
profile. Keep their named project launch profiles and the fixed ports above.

## Formatting, warnings, and optional Git hooks

[`.editorconfig`](../../.editorconfig) defines the formatting rules. C# uses LF
line endings, matching [`.gitattributes`](../../.gitattributes), so editor saves
and command-line formatting agree across Windows and Linux CI.

`dotnet format opengamebuilder.slnx --verify-no-changes --no-restore` checks the
whole solution without editing files and fails if formatting changes are needed.
To apply fixes after restoring packages, run:

```pwsh
dotnet format opengamebuilder.slnx --no-restore
```

Review the resulting diff before staging it. The verification command is the
required check; a local pre-commit hook is only a convenience.

**Compiler warnings are errors in every project, including tests.**
[`Directory.Build.targets`](../../Directory.Build.targets) applies this policy
unconditionally after project properties are loaded. There is no test exemption.
This is the C# `TreatWarningsAsErrors` policy, not MSBuild's command-line
`-warnaserror` switch; task-level warnings such as ASPIRE010 may still be warnings.

To opt into the existing Husky pre-commit hook, run these commands from the
repository root (Git for Windows supplies its `sh` interpreter):

```pwsh
dotnet tool restore
dotnet husky install
```

The hook formats staged C# files using the same solution and formatting rules.
Review any resulting changes before committing. If `HUSKY=0` is set in your
terminal, remove that setting before opting in. To disable hook execution
temporarily in PowerShell, set `$env:HUSKY = '0'`; use
`Remove-Item Env:HUSKY` to re-enable it. To remove a previously installed Husky
hook, run `dotnet husky uninstall`. None of these opt-in operations run during
ordinary restore, build, test, or publish commands.

### Troubleshooting

- **Certificate error or failed application-information load:** check certificate
  trust, open `/api/about` over HTTPS directly, and inspect the browser's Network
  and Console tabs. Verify the web page is using the local API URL and both
  projects are running in Development.
- **Port in use or locked build output:** stop your existing debug session,
  watch tasks, or CLI-managed stack (`aspire stop`) before rebuilding. Do not
  terminate unrelated processes or start a second copy to work around a conflict.
- **Blazor breakpoint does not bind:** use Edge or Chrome, the
  `OpenGameBuilder.Web` profile, and the recommended debugger extensions. See
  [Microsoft's Blazor debugging guide](https://learn.microsoft.com/aspnet/core/blazor/debug?view=aspnetcore-10.0).
- **ASPIRE010 CLI-bundle warning:** the current AppHost SDK/hosting-package
  combination emits this warning when built without the CLI bundle. A successful
  build alone is not a startup check; use the endpoint checks above. Do not
  suppress warnings or change package versions just to follow this guide.
