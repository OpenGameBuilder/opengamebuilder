# Developer Setup

## Supported environment and prerequisites

The supported editor workflow in this guide is **Windows 11**, using
[PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
with either Visual Studio 2026 or VS Code. Linux, macOS, and WSL development are
not yet validated by this guide; Linux CI builds do not establish editor or
browser-certificate support on those platforms.

- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows),
  invoked as `pwsh`.
- [Git for Windows](https://git-scm.com/download/win).
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0), exactly
  **10.0.401**, as selected by [`global.json`](../../global.json). The repository
  disables SDK roll-forward and prerelease selection so a different feature band
  is a setup failure, not a substitute. Update Visual Studio if its bundled SDK
  is older.
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

When updating the SDK requirement in `global.json`, review the compatible pinned
SDK image in the API Dockerfile and the two shipped-application dependency
lockfiles together. Dependabot SDK updates are reviewed with those files; CI
builds the API image without pushing it.

## Command-line workflow (start here)

Clone the repository, then run the remaining commands from its root:

```pwsh
git clone https://github.com/OpenGameBuilder/opengamebuilder.git
Set-Location opengamebuilder
pwsh ./scripts/doctor.ps1
pwsh ./scripts/check.ps1 quick
```

`doctor.ps1` is a read-only prerequisite report. Its default `development`
scope reports PowerShell, the SDK, Aspire CLI, Git, and Bash with their remedies;
it does not install tools, trust certificates, start services, or open a browser.
Use `-Scope quick`, `full`, `content`, `format`, `browser`, or `development` when checking a narrower
workflow.

The normal solution gate is `pwsh ./scripts/check.ps1 quick`: it runs the quick
doctor check, a solution restore with `--locked-mode`, C# formatting
verification, a Release build, and the current 72 solution tests. That restore
enforces the committed API and Web Client graphs; tests and the local-only
AppHost do not opt into lockfiles and resolve dependencies normally.
`check.ps1 format` verifies C# after the same restore and checks first-party
content with Prettier and shfmt. To apply formatter changes deliberately, run
`pwsh ./scripts/check.ps1 format -Fix`, then review the diff.
Install the [content-checking prerequisites](../quality/content-checks.md) before
using `format`, `content`, or `full`:

```pwsh
npm ci --ignore-scripts
pwsh ./scripts/install-content-tools.ps1
pwsh ./scripts/check.ps1 content
```

The initial browser-debugging setup is an explicit, interactive operation:

```pwsh
dotnet dev-certs https --trust
dotnet dev-certs https --check --trust
```

Accept the certificate trust prompt, then restart any open browser. Do not bypass
certificate errors: the browser must trust both the frontend and API HTTPS
connections. See Microsoft's
[development certificate guidance](https://learn.microsoft.com/aspnet/core/security/enforcing-ssl#trust-the-aspnet-core-https-development-certificate)
if the check fails.

Ordinary builds do not restore local tools or install Git hooks. The formatter
ships with the .NET SDK; no Husky installation is needed for these checks.
CI and shared deployment validation run the same formatting verification with
`HUSKY=0`, independently of contributors' hooks.

Tests use Microsoft.Testing.Platform, selected in `global.json`. To run only one
test project, replace `--solution opengamebuilder.slnx` with, for example,
`--project tests\OpenGameBuilder.Api.Tests\OpenGameBuilder.Api.Tests.csproj`.

Direct `dotnet restore`, `build`, `test`, and `format` commands remain useful for
focused editor work. Use `--locked-mode` for a manual restore that must reproduce
the shipped applications' committed graphs. After an intentional SDK or
[`Directory.Packages.props`](../../Directory.Packages.props) change, refresh
those locks with:

```pwsh
dotnet restore opengamebuilder.slnx --force-evaluate -p:RestoreLockedMode=false
```

Review any lockfile changes and run the full check before committing. See
[NuGet's lock-file documentation](https://learn.microsoft.com/nuget/consume-packages/package-references-in-project-files#locking-dependencies)
for the restore model. The shipped API and Web Client entry points each commit
`packages.lock.json`; shared-library locks cannot constrain the graph selected
by a downstream consuming application, so shared libraries do not duplicate
them. Tests and the local-only AppHost use normal dependency resolution, so
their transitive graphs can change between restores. This gives up fixed
development-only graphs while retaining Central Package Management, exact SDK
selection, and locked shipped-application restore and packaging.

[`Directory.Build.targets`](../../Directory.Build.targets) rejects a missing
lock for an opted-in project before a locked restore can create one;
`--locked-mode` then rejects stale API or Web Client graphs. CI restores the
whole solution with `--locked-mode`, and packaging's implicit restore is locked
as well. No host-specific AppHost lock or lock refresh is required.

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

| Endpoint                           | Purpose                                                                                    |
| ---------------------------------- | ------------------------------------------------------------------------------------------ |
| `https://localhost:7001`           | Frontend; the home heading shows `OpenGameBuilder <version> (Development)` after loading   |
| `https://localhost:7000/api/about` | Application name, version, and API environment JSON                                        |
| `https://localhost:7000/api/alive` | API liveness                                                                               |
| `https://localhost:7000/scalar`    | Interactive API documentation (Development only)                                           |
| `https://localhost:17170`          | Aspire dashboard with the default HTTPS profile; use the login URL printed by the launcher |

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
The web client supports the project profile only; there is no IIS Express profile.

### Verify editor debugging from a fresh checkout

Use a fresh checkout without copied `.vs`, `bin`, `obj`, or user settings, and
complete the prerequisites and command-line checks above. Rehearse each editor
separately, stopping the previous stack before starting the next one.

1. In Visual Studio, open the solution and select **Aspire** as described above.
   In VS Code, open the repository root and select **Launch All (API + Web)**.
2. Set an API breakpoint in `AboutController.Get` in
   [`AboutController.cs`](../../src/OpenGameBuilder.Api/Controllers/AboutController.cs)
   and a frontend breakpoint on the `_title` assignment immediately after
   `await Client.GetAboutAsync()` in
   [`Home.razor.cs`](../../src/OpenGameBuilder.Web.Client/Pages/Home.razor.cs).
3. Press F5. Use the debugger's Edge or Chrome window, rather than an unrelated
   browser tab, and confirm the API and browser debug sessions attach. Open
   `https://localhost:7001`, confirm that the API breakpoint is hit, and continue.
   Blazor's debug proxy can start after the first page's `OnInitializedAsync`
   has run, so an initial missed frontend breakpoint is inconclusive. Retry
   after the browser debugger is ready and record whether the frontend
   breakpoint is hit; see [Microsoft's Blazor debugging guidance](https://learn.microsoft.com/aspnet/core/blazor/debug?view=aspnetcore-10.0#debug-a-blazor-webassembly-app-in-an-ide).
4. Continue execution and perform the browser success check above: the API
   request returns 200 and the home heading displays the Development version.
5. Stop debugging and confirm both application processes stop before switching
   editors or launch methods.

Record the source revision, Windows/editor/browser versions, launch profile,
breakpoint results, and browser request result. Build and CLI startup checks
alone do not establish F5, debugger attachment, or fresh-editor acceptance.

### Recorded setup verification

On 2026-09-22, a fresh local clone of `5c5fdbaf0930db009d4d9c6a3f3ee5644a689d60`
with the contributor-guidance, web launch-profile, and startup-HTML repairs was
opened without copied editor state or build outputs. The host was Windows 11
(build 26200), with .NET SDK 10.0.401, Aspire CLI 13.4.2, and an already trusted
development certificate. No Docker or production credentials were needed.

| Check                                                         | Result                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Solution validation in the working checkout                   | Restore, format verification, Release build (zero warnings), and all 72 tests passed; frontend Release publish and the portability guard also passed.                                                                                                             |
| Visual Studio Insiders 18.11.12210.170, shared Aspire profile | F5 built and started the fresh clone; Aspire reported both resources healthy. A browser request hit `AboutController.Get`, and continuing displayed `OpenGameBuilder 0.11.0 (Development)` in Chrome 153.0.8010.53.                                               |
| VS Code 1.138.0, Launch All (API + Web)                       | F5 started both projects. Reloading the launched Edge page hit `AboutController.Get` in VS Code; the frontend displayed the Development heading.                                                                                                                  |
| Remaining editor acceptance                                   | The frontend `Home.OnInitializedAsync` breakpoint was not hit in the externally opened Visual Studio Chrome tab. Full Blazor breakpoint verification in each editor's debugger-owned browser remains open; neither API debugging nor the heading alone proves it. |

The fresh clone's initial CLI restore hit a local NuGet scratch-lock access error;
Visual Studio subsequently restored and built it successfully. This records a
rehearsal on an existing development machine, not a clean-machine installation.
Repeat the debugger procedure above when closing the remaining editor acceptance.

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
`-warnaserror` switch; task-level warnings are handled separately.
The AppHost explicitly retains NuGet-restored orchestration dependencies and
acknowledges only `ASPIRE010`, the advisory about optional CLI bundle delegation.
This does not disable compiler warnings or change the local launch workflow.

To opt into the existing Husky pre-commit hook, run these commands from the
repository root (Git for Windows supplies its `sh` interpreter):

```pwsh
dotnet tool restore
dotnet husky install
```

The hook formats staged C# files using the same solution and formatting rules.
For staged content files it also runs the shared first-party content check against
the working tree, including unstaged work, without rewriting or staging content.
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
- **Aspire dependency mode:** `AspireUseCliBundle=false` is intentional. The
  AppHost restores orchestration dependencies from NuGet rather than requiring
  CLI bundle delegation during IDE/CI builds, and suppresses only the associated
  `ASPIRE010` advisory using the [documented opt-out](https://aspire.dev/diagnostics/aspire010/).
  Revisit that choice if adopting CLI-bundle-only features. A successful build
  alone is not a startup check; use the endpoint checks above.
