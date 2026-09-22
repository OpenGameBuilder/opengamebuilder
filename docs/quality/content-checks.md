# First-party content checks

Use PowerShell 7 and Node.js 22 or newer from the repository root. Node.js 24 is
the recommended LTS and CI baseline; newer releases are allowed even when they
have not yet become the CI baseline. Prepare the repo-local tools once, then run
the shared checks:

```pwsh
pwsh ./scripts/setup-content.ps1
pwsh ./scripts/check.ps1 content
```

The setup command runs the locked npm install and installs the checksum-pinned
native tools under the repository. It does not install global packages, require
a Docker daemon, or enable Git hooks. Re-run it after either content-tool manifest
or lockfile changes. Documentation-only contributors can run the direct npm
format and lint commands without the .NET SDK; the SDK is needed only to install
or uninstall Husky.Net hooks or to build the rendered DocFX site. Once installed,
the hook runs Node directly.

The native installer supports Windows x64 and Linux x64. It downloads into ignored
`artifacts/content-tools`, verifies both archive and executable SHA-256 hashes,
and reuses an installation only when the executable still matches the manifest.
`pwsh ./scripts/install-content-tools.ps1 -Verify` checks it without downloading.
Windows uses upstream ShellCheck's x86 executable under WoW64. No application
service, browser, or deployment credentials are needed.

`check.ps1 full` installs locked npm dependencies and includes these checks and
their rejection fixtures alongside the existing solution and packaging checks.
Native-tool installation is an explicit prerequisite; CI performs it before
the shared full command. The required `build-test` check keeps its name and fails
when any content check fails, independently of Git hooks.

## Formatter and linter ownership

| Content                                     | Formatter               | Additional checks                                                                               |
| ------------------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------- |
| C#                                          | SDK `dotnet format`     | Existing analyzers; explicit accessibility (IDE0040) and readonly fields (IDE0044) are warnings |
| Markdown, JSON/JSONC, YAML, CSS, JavaScript | Exactly pinned Prettier | Markdown structure via markdownlint-cli2's Prettier-compatible preset                           |
| Bash scripts                                | Exactly pinned shfmt    | ShellCheck, including Bash workflow run blocks through actionlint                               |
| GitHub workflows                            | Prettier                | actionlint and the protected-source cache policy                                                |
| Markdown links and images                   | None                    | Offline lychee file and anchor checks                                                           |

[EditorConfig](../../.editorconfig) and [Prettier](../../.prettierrc.json) use two
spaces for first-party content and shell scripts, LF line endings, and an 80-column
code target. Markdown preserves authored prose wrapping; Prettier still formats
tables, lists, and code fences. C# retains its existing four-space conventions.
Razor, HTML, XML, and PowerShell are outside the new formatter's scope.

Apply formatting with `pwsh ./scripts/check.ps1 format -Fix`, then inspect the diff.
That command includes C#, Prettier, and shfmt. `npm run format` applies only the
content formatters; `npm run format:check` verifies them without changing files.
Neither command rewrites prose to meet a style guide. Markdownlint's compatible
preset disables overlapping rules; MD060 is also disabled because Prettier owns
table layout. The PR body template alone permits a level-two opening heading,
since GitHub supplies the title.

The runner enumerates tracked and new non-ignored files through Git, including
root documentation and `.github` documents. It excludes generated output,
dependencies, and `.agents/skills`. Package-manager lockfiles keep their generated
formatting. [Prettier's ignore file](../../.prettierignore) and
[Markdownlint's config](../../.markdownlint-cli2.jsonc) keep editor checks within
the same boundary. Vendored skills and their provenance are preserved.

## Editor and optional hook use

The VS Code recommendations select local Prettier for its file types and the C#
extension for C#/Razor. Markdownlint reads the repository configuration. Use the
`check-content` and `format-first-party-content` tasks for the same command-line
checks, including shell formatting. Visual Studio users can invoke those commands
from its PowerShell terminal; EditorConfig remains authoritative for C#.

The opt-in Husky hook runs only the pinned Prettier against the staged bytes of
first-party Markdown, JSON, YAML, CSS, and JavaScript files, using the formatting
configuration in the current checkout. It never rewrites or stages files. C#,
native shell, workflow, link, and full-tree checks run separately. Preview it with
`node scripts/check-staged.mjs`; see
[hook setup](../setup/development.md#formatting-warnings-and-optional-git-hooks)
for the one-time npm and Husky.Net commands.

## Workflow compatibility and exceptions

GitHub supports [`cache-mode: none`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#cache-mode),
but actionlint 1.7.12 does not recognize that key. The
[actionlint configuration](../../.github/actionlint.yaml) suppresses only that
specific root-key diagnostic in the protected-source deployment workflows,
including manual documentation publication.
The [cache-policy check](../../scripts/workflow-cache-policy.mjs) independently
requires `none` and rejects job overrides that permit caching. Other workflow
errors still fail, and the regression suite covers missing/changed cache policy.
Remove these exceptions once the pinned actionlint supports the key.

ShellCheck exceptions sit next to the affected code or at the top of fixture
scripts, with a reason: intentional literal variable expressions, a sourced
library constant, the EXIT-trap callback, or deliberate glob matching. There is no
repository-wide suppression of shell diagnostics.

## Recorded validation

The contributor-tooling cleanup on 2026-09-22 passed setup, the development
doctor, the installed commit hook, and the full Windows gate using the normal
Node.js 24.18.0 installation, including all 72 .NET tests and 50 tooling tests.
The content gate and those 50 tooling tests also passed on Node.js 22.23.2 and
26.10.0. The six local browser checks passed on both Node.js 24 and 26. An
isolated committed source snapshot passed hook installation and the rendered
documentation gate. Staged-file fixtures verify partial staging, renames,
exclusions, missing-tool remedies, and preservation of the index and working
files. This is local Windows evidence; hosted CI and a fresh contributor's
editor setup have not been exercised for this cleanup.

On 2026-09-22, Windows x64 with Node.js 22.23.2 and PowerShell 7.6.5 passed the
shared full check: locked restore, format verification, Release build with zero
warnings, all 72 .NET tests, frontend publish and portability guard, smoke-package
checks, and all five isolated shell suites. After review fixes, the complete
content gate and all seven content regression groups passed again. The fixtures
reject formatting drift, skipped Markdown heading levels, missing files/images
and anchors, invalid workflow syntax, shell word splitting, and changed deployment
cache policy; formatter fixes pass the same check. They also verify Prettier's
file-type and vendor exclusions.

Injected C# accessibility defects failed the Release build with IDE0040; a
runtime-initialized mutable field failed `dotnet format` with IDE0044. The latter
is enforced by formatting verification, not by this SDK's build analyzer. Native
tool installation, reuse without downloads, and rejection of a corrupted
executable were verified on Windows.

The [Ubuntu 24.04 CI gate for PR #114](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35744440511/job/106802281361)
also passed the content checks, all seven regression groups, and the full solution
gate. The tree tested at `d5e0bb6` exactly matches merge commit `f8db700` on `main`,
including the initial mechanical formatting commit `1f646a6`.

After the merge, `pwsh ./scripts/check.ps1 format -Fix -Serial` was rerun on Windows
against `f8db700`. C# formatting, Prettier, and shfmt all completed successfully;
`git diff --exit-code` confirmed that the overall sweep produced no changes.
The separate mechanical PR originally planned is therefore already covered by
[the merged PR](https://github.com/OpenGameBuilder/opengamebuilder/pull/114).
The external-link schedule has not yet run. These formatting checks did not start
application services, deploy, or establish browser acceptance.

## Local links and external maintenance

[Local lychee configuration](../../.lychee.toml) uses offline mode and anchor
checking. Missing files, images, and fragments fail PR validation. Remote URLs
are excluded from this gate; their availability cannot block unrelated work.
Rendered HTML can be added when a documentation-site build exists.

[External-link maintenance](../../.github/workflows/content-links.yml) runs weekly
and can be dispatched manually. It has read-only permissions, four concurrent
requests, a 15-second request timeout, one retry, a 15-minute job limit, and
seven-day artifact retention. It produces a report without posting issues or
comments. Owner `ostomachion` reviews failures, distinguishes temporary outages
from stale links, and submits focused corrections. It is not a required PR check.
Run the same report locally with `pwsh ./scripts/check.ps1 external-links`.

## Maintaining tool pins

[package.json](../../package.json) records the Node.js 22 compatibility minimum
and pins npm tools with its lockfile; [`.node-version`](../../.node-version)
selects Node.js 24 as the recommended CI baseline. Dependabot checks the root
tooling package weekly. The native
[tool manifest](../../scripts/content-tools.json) records exact versions, upstream
release URLs, archive checksums, and executable checksums for each platform.
`ostomachion` reviews native-tool releases monthly and whenever workflow syntax
outgrows a pin. Verify upstream release assets and executable hashes, change the
manifest in a focused PR, and run content checks and rejection fixtures on both
platforms. A new formatter version may require a separate mechanical sweep PR.

Upstream references: [Prettier installation](https://prettier.io/docs/install),
[Markdownlint compatibility](https://github.com/DavidAnson/markdownlint/blob/main/doc/Prettier.md),
[actionlint configuration](https://github.com/rhysd/actionlint/blob/v1.7.12/docs/config.md),
[ShellCheck](https://github.com/koalaman/shellcheck),
[shfmt](https://github.com/mvdan/sh), and
[lychee anchors](https://lychee.cli.rs/recipes/anchors/).
