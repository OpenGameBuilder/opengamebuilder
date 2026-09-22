# AI tooling maintenance

AI tools are optional. Local agents follow [AGENTS.md](../../AGENTS.md),
[AI policy](../../AI_POLICY.md), and the same
[validation workflow](development.md#command-line-workflow-start-here) as human
contributors. Skills provide reference material; they do not grant permissions.

## Toolchain and commands

Aspire CLI, AppHost SDK, and `Aspire.Hosting.AppHost` are aligned at **13.5.4**.
The [local .NET tool manifest](../../.config/dotnet-tools.json) pins the CLI;
`AspireUseCliBundle=false` retains NuGet-restored orchestration for IDE/CI builds.
Restore tools explicitly from the repository root:

```pwsh
dotnet tool restore
dotnet tool run aspire -- --version
```

Use `dotnet tool run aspire -- <arguments>` wherever upstream skills say
`aspire <arguments>`. This prevents an unrelated global CLI from shadowing the
selected version. Tool restore also installs the existing Husky tool but does
not enable hooks. Application restore, build, test, and publish do not install
or invoke these tools. AI remains optional, including when using Aspire locally.

`dotnet-inspect` is an optional global tool pinned to **0.25.0** in the
[provenance manifest](../../.config/ai-tooling-provenance.json). Install or update
it deliberately, then verify the executable selected by PATH:

```pwsh
dotnet tool install --global dotnet-inspect --version 0.25.0
# For an existing installation, use tool update with the same exact version.
dotnet-inspect --version
dotnet-inspect skill
```

Reopen the terminal/editor if the global tool directory is newly added to PATH.
Use `dotnet-inspect <arguments>` for the upstream entry point's unversioned
`dnx dotnet-inspect -y -- <arguments>` examples. Load `dotnet-inspect skill`
before substantive inspection: the installed executable supplies its own
version-matched guide. The short vendored entry point remains upstream text;
this repository command selection is a documented override, not a vendor patch.
Neither the optional executable nor a successful API lookup proves application
compatibility. Inspect only permitted inputs under the AI policy, never original
MyGameBuilder proprietary source or binaries to derive implementation.

## Local client discovery

AGENTS.md is the authoritative project guidance. The supported local clients are
Codex, VS Code Copilot, and Visual Studio Copilot. Cloud coding agents are not
supported. Configuration support and completed client acceptance are distinct;
see the recorded evidence below.

| Client                | Instruction and skill discovery                                                        | Aspire MCP configuration                                                      |
| --------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Codex app/CLI         | Root `AGENTS.md`, repository `.agents/skills`                                          | [`.codex/config.toml`](../../.codex/config.toml), loaded for trusted projects |
| VS Code Copilot       | Root `AGENTS.md`, shared Copilot adapter, repository `.agents/skills`                  | [`.vscode/mcp.json`](../../.vscode/mcp.json), `servers` with explicit `stdio` |
| Visual Studio Copilot | Shared Copilot adapter points to AGENTS.md; check repository skill paths in the client | [`.mcp.json`](../../.mcp.json), `servers` with explicit `stdio`               |

The short `.github/copilot-instructions.md` adapter directs both
editors to the shared guidance without duplicating it. Visual Studio does not
use AGENTS.md as an automatically loaded instruction file, so verify that the
agent follows the adapter's reference. Open the repository root (or its solution)
so MCP starts with the local tool manifest and `aspire.config.json` in scope.
The three configurations invoke the same pinned command. A root `.mcp.json`
alone is not Codex configuration. No secrets, user-specific paths, model settings,
trust declarations, or permission bypasses belong in these adapters.

After updating configuration, start a new Codex session in this trusted checkout.
Run `codex mcp get aspire --json` and use `/mcp` to confirm the server connects.
Ask the agent to identify its loaded project guidance and repository skill paths;
compare them with this checkout. A configuration listing alone does not prove an
MCP handshake or that an agent applied instructions correctly. The installed
Codex app-server's `skills/list` and `mcpServerStatus/list` can also inspect actual
discovery without submitting a model task.

Codex's [MCP documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
and [instruction discovery rules](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
explain its project scope. Consult the
[Copilot support matrix](https://docs.github.com/en/copilot/reference/custom-instructions-support),
[VS Code MCP guide](https://code.visualstudio.com/docs/agent-customization/mcp-servers),
and [Visual Studio MCP guide](https://learn.microsoft.com/en-us/visualstudio/ide/mcp-servers?view=visualstudio)
for each editor's discovery rules. In VS Code, use **MCP: List Servers**, select
`aspire`, and inspect its output and tools. In Visual Studio's Copilot Agent mode,
check the tools picker for Aspire and inspect the loaded instruction references.
Confirm that skill paths belong to this checkout, not a personal skill directory.
Handle any client trust prompt yourself; repository configuration does not grant
trust. A listed server or skill name alone does not establish successful loading.

Use the client's filesystem sandbox, command approvals, and MCP trust controls in
addition to repository instructions. Keep production credentials out of local
agent sessions. Extra MCP servers, cloud environments, repository plugins, and
agent fleets need a recurring workflow and a separate reviewed decision.

## Provenance and deliberate updates

The six Aspire skills (`aspire`, `aspire-init`, `aspireify`,
`aspire-orchestration`, `aspire-monitoring`, and `aspire-deployment`) are one
upstream bundle. Keep their routing and reference files together. The short
`dotnet-inspect` entry point is embedded in the selected Aspire CLI source and
loads the installed inspection tool's guide on demand.

The [provenance manifest](../../.config/ai-tooling-provenance.json) records
immutable source commits, release artifact hashes, source paths, license sources,
and SHA-256 for every installed skill and notice. Hashes normalize CRLF and CR
to LF, preserving all other text and final-newline differences. The third-party
notices retain their own licenses; the application's Apache license does not
replace them. There are no local content patches to the vendored skills.

Aspire skills 0.0.2 use 13.5.3 in examples; their bundle manifest declares CLI
compatibility `>=13.5.0 <13.6.0`. CLI/SDK 13.5.4 is within that declared range
and passed the local rehearsal below. The candidate review excluded two
telemetry hook scripts, ten evaluation assets, and three Copilot CLI extension
families (`aspire-apphosts`, `aspire-doctor`, and `aspireify`). Their source and
bundle entries were inspected separately; none were installed or enabled.
Upstream references can still link to mutable branches, and `aspire agent init`
can replace checked-in files: neither is an approved automatic update path.
Production continues to use
[Compose hosting](hosting.md), not the generic skill's deployment commands.
Deployments, releases, credential handling, destructive operations, and changes
to production hosting still require explicit authorization under AGENTS.md.

**Owner and cadence:** `ostomachion` reviews these pins monthly and before any
Aspire toolchain or agent-client upgrade. Dependabot covers the configured
package/SDK ecosystems, but does not replace review of vendored skill commits,
embedded entry points, global executable pins, client adapters, or tool bundles.
Use a focused reviewed PR for an update; never regenerate unpinned skills during
builds or routine agent work.

1. Select exact candidate versions and resolve tags to full commits. Download
   source and release artifacts into a separate ignored candidate directory.
2. Verify the artifact digest, installation manifest, exclusions, notices, and
   every installed file against those pinned sources. Review all command,
   permission, hook, extension, and external-reference changes before copying.
   For the embedded dotnet-inspect entry point, extract the C# raw string named
   `DotnetInspectSkillFileContent`, remove its delimiter indentation, retain its
   exact content, and add no newline beyond the source string.
3. Replace the selected skill trees, explicitly remove obsolete files, and update
   the source record, normalized hashes, tool pins, notices, and commands together.
   Store repository-specific instructions in AGENTS.md or this guide.
4. Run the offline check below, the normal solution gate, relevant content/script
   checks, and the manual rehearsal. Review the final diff and retain a concise
   result in this guide. Record source matching separately from runtime success.

## Read-only checks

```pwsh
node scripts/check-ai-tooling.mjs
node scripts/check-ai-tooling.mjs --installed
node scripts/check-ai-tooling.mjs --installed --require-inspect
node --test tests/ai-tooling/check.test.mjs
```

The default check is offline: it compares source pins, normalized file hashes,
exact file inventory, CLI/SDK/hosting versions, and the MCP adapters. It does not
install tools, change files, start services, or regenerate hashes. Content
validation includes this default check. `--installed` additionally executes
version commands; a missing optional dotnet-inspect is reported without failing
unless `--require-inspect` is specified. Native tools may write their normal
user-cache logs; the checker itself never modifies the checkout.

A passing manifest check proves consistency with the reviewed record, not fresh
upstream source comparison, safe vendor behavior, runtime readiness, or client
instruction discovery. The deliberate-defect tests keep drift failures visible.

## Manual rehearsal and acceptance

After significant tooling changes, rehearse these three small tasks and record
the source base, tool/client versions, commands, result, and limitations:

1. **Guidance and focused edit:** identify loaded AGENTS.md and skill paths;
   make a bounded documentation or code change, choose its applicable gate, and
   review the diff for unrelated edits and unsupported claims.
2. **API lookup:** obtain the installed dotnet-inspect guide, inspect a known
   public type in the built Contracts assembly offline, and compare the result
   with source. Keep UI, HTTP, and host responsibilities in their own projects.
3. **Local orchestration:** use the pinned CLI to start the existing AppHost,
   wait for API/web health, verify HTTPS endpoints, connect through the client's
   Aspire MCP adapter, and list resources. Stop the stack and confirm it stopped.
   Do not deploy or enable generic upstream hooks during the rehearsal.

Record editor AI adoption separately: verify loaded instructions/references and
MCP tools in that actual client. API health and CLI success do not establish
browser rendering, debugger attachment, fresh-machine setup, or another client's
discovery behavior.

### Recorded rehearsal: 2026-09-22

Base: `abd184efc9f10ba4e6b63137dc844877b97f199b` plus this section 19 change.
Windows source review matched all 37 Aspire skill files to the pinned 0.0.2
bundle, extracted the short dotnet-inspect entry point from the pinned Aspire
CLI source, and verified both unchanged license notices. The offline checker
covers those 40 files. Source provenance is separate from the runtime results:

- **Focused edit and guidance:** this bounded toolchain/documentation update used
  the repository AGENTS.md and reviewed the resulting diff. Codex
  `0.155.0-alpha.9.2` app-server discovery returned all seven enabled repository
  skills from this checkout. Its Aspire adapter connected to server 13.5.4 and
  discovered 14 tools without a tool-list error.
- **API lookup:** dotnet-inspect 0.25.0 supplied its installed guide. An offline
  `type OpenGameBuilder.Api.Contracts.About.AboutResponse --library
src/OpenGameBuilder.Api.Contracts/bin/Release/net10.0/OpenGameBuilder.Api.Contracts.dll
--offline` lookup matched the public type and its four properties in source.
- **Local orchestration:** the pinned CLI started the existing AppHost on
  Windows; API and web reached Healthy, and the configured HTTPS API-about and
  frontend endpoints returned 200. An MCP handshake and resource listing
  succeeded. The rehearsal stopped the stack and confirmed no running AppHosts.
- **VS Code Copilot:** VS Code 1.138.0 discovered `aspire` from
  `.vscode/mcp.json`, started CLI 13.5.4, completed MCP initialization, and
  reported 14 discovered tools. Copilot displayed **Credit Limit Reached**;
  a response applying the project instructions remains unverified.
- **Visual Studio Copilot:** the adapter uses the documented root MCP schema.
  The editor exposed skill names, but its displayed Aspire 13.4 description did
  not prove discovery of this updated checkout, and its tools picker returned
  no Aspire match. Current guidance and MCP tool discovery still require a
  fresh editor session and an in-editor check; existing unsaved buffers were
  preserved instead of reloading the solution.

The normal local gate passed: locked restore, format verification, Release build
with no warnings or errors, and all 72 .NET tests. The installed-version check
and 11 tooling regression tests also passed. Configuration checks do not close
the outstanding Copilot instruction acceptance. Content checks passed; the
27-page documentation build, rendered links, and source inventory passed against
a temporary local snapshot containing the new files. All four documentation
regression groups passed separately with their own Git fixtures. The working
branch and index were unchanged; source-link validation against its current
HEAD requires committing the new files first.

Once Copilot is available,
start a fresh session in each editor, ask it to identify the loaded instruction
and skill paths and list Aspire tools, and record the observed references and
result here. No hosted, cloud-agent, browser-rendering, or fresh-machine
acceptance is implied.
