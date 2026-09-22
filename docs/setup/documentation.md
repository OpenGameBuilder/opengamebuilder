# Documentation site

The DocFX site renders the existing root and `docs/` Markdown with the modern
template, search, and links to the original files at the built commit. Maintain those
files directly; there is no separate wiki or copied set of guides. The temporary
foundation plan is excluded from the site and navigation.

## Build and check

Use the SDK from `global.json`, PowerShell 7, and Node.js 22. Install the
[content prerequisites](../quality/content-checks.md), then run:

```pwsh
pwsh ./scripts/check-docs.ps1
```

The command restores the exact DocFX tool from `docs/.config/dotnet-tools.json`,
builds with warnings as errors, checks rendered local links and anchors offline,
and runs deliberate-defect checks. Output and logs are untracked under
`artifacts/docs/`; no application, browser, or server starts during validation.
The separate manifest does not restore Husky or install Git hooks.

To preview the checked output, explicitly start DocFX's local server:

```pwsh
Set-Location docs
dotnet tool run docfx -- serve ../artifacts/docs/site
```

Documentation and repository-source links stay relative in Markdown. During the
site build, links to code, scripts, workflows, and repository directories are
rewritten to the exact source revision because those files are not site pages.
Links between site pages stay relative, including when hosted under a different
base path. Source links and each page's edit link use the build's Git commit,
so branch previews and releases do not silently point to newer `main` content.
Local previews include working-tree edits, but their source links point to `HEAD`.
Commit newly added pages and linked repository files before building, and push
that commit before sharing its source links. The build rejects source paths that
do not exist in the selected commit, including generated or untracked files.

DocFX reports repository-file links omitted from the site as informational
`InvalidFileLink` diagnostics. The resolver verifies these targets before rewriting
them, and the rendered-link gate still rejects missing pages, anchors, and assets.
Other build warnings remain errors.

Remote availability remains part of the separate [external-link maintenance
report](../quality/content-checks.md), not the PR gate.

## Pull requests

Both the documentation lane and the Linux full lane build and check the site.
A failed site check fails the existing required `build-test` gate. Each retains
the generated site and available diagnostic logs for seven days. Download the
site artifact to review the rendered change before publication.

## Recorded local acceptance

On 2026-09-22, `check-docs.ps1` passed on Windows 11 (build 26200), with SDK
10.0.401, Node.js 22.23.2, DocFX 2.80.1, and the pinned Lychee 0.24.2. All 27 pages
built with zero warnings; rendered local links and anchors, search entries,
original-source edit links, and four deliberate-defect regression groups passed.
The tests rejected a broken DocFX source link, missing rendered page, renamed
anchor, missing stylesheet, missing search entry, and accidental plan publication.
Fixtures for two source commits verified that page links remain relative while
repository links follow the selected commit without changing the Markdown.

The full local repository check also passed: locked restore, format, a Release
build with zero warnings, all 72 .NET tests, content and CI policy regressions,
frontend packaging, and five shell suites. The new hosted PR checks, browser
interaction with documentation search, and Pages deployment remain unverified.
No service or browser was started for these local checks.

## Publication and hosted acceptance

Publication requires explicit maintainer authorization. The manual
[publication workflow](../../.github/workflows/docs-pages.yml)
accepts only protected `main`, checks out the dispatch's exact commit, reruns the
content and site gates, and deploys that run's artifact through `github-pages`.
Only the deployment job receives Pages write and OIDC permissions. Pull requests
cannot publish and no push automatically publishes.

Before the first authorized publication:

1. Merge the reviewed implementation through the required PR checks.
2. Select **GitHub Actions** as the repository's Pages source. Restrict the
   `github-pages` environment to `main` and require a maintainer review. Disable
   administrator bypass where available; do not weaken branch or environment
   protections to run the workflow.
3. Dispatch **Publish documentation** from `main` and approve the deployment
   after reviewing its checked artifact. Do not add arbitrary ref inputs or
   reuse an artifact from an untrusted PR workflow.
4. At the URL returned by deployment, open Setup, Contribute, Architecture,
   Testing, and Operations. Reload a nested page, check its CSS and script loads,
   search for `rollback`, follow a result and a heading link, and confirm its edit
   link opens the correct Markdown at the deployed commit. Check the browser
   console for errors.
5. Record the source SHA, workflow URL, site URL, browser/version, date, and actual
   results here. A green build alone does not satisfy hosted acceptance.

An initial check on 2026-09-22 found protected `main` and no configured Pages
site (HTTP 404). Later that day, Pages was configured to publish through GitHub
Actions at <https://opengamebuilder.github.io/opengamebuilder/> with HTTPS
enforced. The `github-pages` environment is restricted to `main`, requires review
by `ostomachion`, permits that reviewer to approve their own deployment, and does
not allow administrator bypass. No publication workflow has been dispatched.
Hosted navigation, assets, search, and links remain unverified.
This follows GitHub's [custom Pages workflow requirements](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Checked examples and API reference

There is no engine implementation or executable engine example yet. Its behavior
and acceptance criteria must be selected and implemented first. With that first
slice, add the example to the solution's Release build and tests, execute it in
CI, and include its checked source in the tutorial using DocFX code snippets
instead of copying a second implementation. Add a filtered public .NET reference
when the engine exposes useful APIs; exclude internal and host-only surfaces.
The [HTTP API guide](../backend/api.md) and development-only OpenAPI/Scalar remain
the documentation for the HTTP host.

The site uses DocFX's [modern template](https://dotnet.github.io/docfx/docs/template.html),
[strict build diagnostics](https://dotnet.github.io/docfx/reference/docfx-cli-reference/docfx-build.html),
and [source snippet support](https://dotnet.github.io/docfx/docs/markdown.html).
