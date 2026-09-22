# AI tooling maintenance

AI tools are optional. Local agents follow [AGENTS.md](../../AGENTS.md), the
[AI policy](../../AI_POLICY.md), and the same
[development and validation workflow](development.md#command-line-workflow-start-here)
as human contributors. Skills supply reference material, not permission to act.

## Repository scope

The six vendored Aspire skills form one upstream bundle: `aspire`,
`aspire-init`, `aspireify`, `aspire-orchestration`, `aspire-monitoring`, and
`aspire-deployment`. Keep the bundle together so its routing and reference links
remain intact. `dotnet-inspect` is a separate skill for inspecting .NET APIs.

Aspire is the local launcher. The generic deployment skill includes Azure, AWS,
Kubernetes, and Aspire publishing guidance; those are not approved production
workflows for this repository. Use [hosting](hosting.md) and the
[release process](../release/README.md) for the existing Compose deployment.
Installed skills do not authorize deployments, releases, credential handling,
destructive operations, new infrastructure, or changes to this architecture.
Documentation-only work does not start services.

The [MCP configuration](../../.mcp.json) invokes `aspire agent mcp`; its CLI
installation and verification belong to [development setup](development.md).
The `dotnet-inspect` skill's `dnx` examples are optional tool invocations, not
pinned build dependencies. Review any tool execution separately from updating
the skill text. Never use its source/IL inspection features on original
MyGameBuilder proprietary material; the AI policy's source restrictions apply.

## Verified provenance

All seven skills were introduced in application commit
`f69f43d9d36c26d500678f8874831b71f0459e33`. The original import did not record an
upstream pin. The following matching snapshots were reconstructed and verified
on 2026-09-22 UTC; they establish content provenance, not the original install command.

| Vendored content                       | Verified source                                                                                                                                                                                        | License and attribution                                                                               |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| Six Aspire skill directories, 36 files | [microsoft/aspire-skills at `35f41b0`](https://github.com/microsoft/aspire-skills/tree/35f41b013fb0e1cb7860c47ccc26d827ed5fba8b/skills)                                                                | [MIT, Microsoft Corporation](../licenses/aspire-skills-MIT.txt)                                       |
| `dotnet-inspect/SKILL.md`              | `DotnetInspectSkillFileContent` in [Aspire CLI 13.4.2 at `d7d0b67`](https://github.com/microsoft/aspire/blob/d7d0b6759ce4b936c76bc4775814d27db560dd6d/src/Aspire.Cli/Agents/CommonAgentApplicators.cs) | [.NET Foundation and Contributors, MIT](../licenses/aspire-MIT.txt); original skill by Richard Lander |

The original dotnet-inspect skill is from
[richlander/dotnet-inspect v0.5.0](https://github.com/richlander/dotnet-inspect/blob/0fe16f7ffc8a1ece0c9a8607ebae0db1cbb65d20/skills/dotnet-inspect/SKILL.md),
whose project declares MIT licensing. Aspire embeds an adapted copy with
frontmatter and final-newline differences; use the embedded source above to
reproduce the vendored file.

The 36 Aspire files also match the `aspire-skills-v0.0.1.tgz` bundle embedded in
that pinned CLI revision. Its SHA-256 is
`8f0aa535917bb6d2589acbf8f986c7b0d622ee7744e39c526bb7166c0664b53c`.
The current upstream `v0.0.1` release artifact differs, so a version label alone
is insufficient to reproduce these files. The dotnet-inspect file's SHA-256,
after converting CRLF to LF without adding a final newline, is
`944d0d4130c9286cbffcf7347e5127c8828c48525f6b0489c52c0e369ac0faab`.
All 37 vendored files match their recorded sources after CRLF-to-LF normalization;
there are no repository content patches. These third-party notices remain MIT;
the application repository's Apache license does not replace them.

## Reproduce or update deliberately

Use a focused branch and a separate temporary candidate directory. Do not run an
unpinned installer over the working skills or regenerate them during restore,
build, CI, or ordinary agent work.

For the current Aspire snapshot, from the repository root in PowerShell:

```pwsh
$repositoryRoot = (Get-Location).Path
$skillSource = Join-Path $env:TEMP ("ogb-aspire-skills-" + [guid]::NewGuid())
git -c core.autocrlf=false clone https://github.com/microsoft/aspire-skills.git $skillSource
git -C $skillSource checkout --detach 35f41b013fb0e1cb7860c47ccc26d827ed5fba8b
$skillNames = 'aspire', 'aspire-init', 'aspireify', 'aspire-orchestration', 'aspire-monitoring', 'aspire-deployment'
foreach ($name in $skillNames) {
    foreach ($part in 'SKILL.md', 'references') {
        git diff --no-index --ignore-cr-at-eol -- "$repositoryRoot/.agents/skills/$name/$part" "$skillSource/skills/$name/$part"
    }
}
```

No diff means the current snapshot matches. Git returns 1 for a content difference
and values above 1 for errors; inspect every comparison before copying anything.
These paths contain all 36 installed files at this revision. Upstream `evals`
directories are excluded by the bundle's install manifest and are not vendored.
For later revisions, inspect the manifest for added assets or changed exclusions.

For dotnet-inspect, retrieve `CommonAgentApplicators.cs` at the pinned Aspire
commit. Extract the C# raw string named `DotnetInspectSkillFileContent`: remove
the opening/closing delimiters and the closing delimiter's eight-space indentation
from every content line, keep blank lines, use LF, and add no trailing newline.
Compare its SHA-256 with the value above and the local skill. Do not copy the
current richlander `main` file and describe it as the embedded version.

For an update, choose explicit upstream commits and verify compatibility with the
repository's selected CLI/SDK. Review the entire candidate diff, including
commands, permissions, external references, additional files, and licenses.
Replace only the selected skill trees after review, explicitly removing obsolete
files rather than leaving them behind in an overlay. Retain full license notices
and attribution, then update this source record and checksum evidence in the same PR.

Keep repository-specific instructions in AGENTS.md and these setup documents;
avoid editing vendored text. If a local patch is necessary, record its exact files,
reason, and upstream base here, and reapply/review it deliberately on each update.

Before completing an update, compare all installed files with the chosen sources,
check referenced local assets and notices, review the diff, and run
`git diff --check`. A text-only skill or policy update does not require starting
Aspire. If the toolchain or application changes, run the documented solution gate
and any relevant runtime checks; a source match is not a runtime test.

## Cloud coding agents

Not applicable: the maintainer confirmed local agents only on 2026-09-22 UTC.
Automated Copilot review does not constitute a supported cloud coding environment.
There is no cloud setup workflow or claim of runner validation. If a cloud coding
agent is adopted, add a minimal setup using the same SDK and validation commands,
verify it on that actual runner, and record the result before calling it supported.
Keep production secrets out of that environment.
