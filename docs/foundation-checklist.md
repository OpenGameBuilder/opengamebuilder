# Foundation checklist

This is a temporary implementation plan, to be deleted when the foundation work
is complete. Other repository files must not link to it or depend on its step
numbers. Put lasting procedures, decisions, support promises, and acceptance
evidence in the appropriate permanent guide or issue as each step is completed.

The plan combines the audit of `1bdc1c4` with the community-infrastructure review
on 2026-09-22. The application is still an API/frontend shell; the first engine
milestone has not been selected. Recommendations below are planned changes, not
claims that the tools, settings, or support coverage already exist.

Prefer one focused PR per step, splitting implementation from human or hosted
acceptance when necessary. Check off work only after its acceptance check passes.
Record a short result and evidence link, not a running history. An unchecked item
is planned work, not a claim that this documentation change implemented it.

Step numbers are stable identifiers for work already in progress. Use this
delivery order; the first engine slice need not wait for the entire checklist:

| When                                | Work                                                                                                                                                                                          |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Now                                 | Operational and documentation repairs (1-6), repeatable commands and formatting (13-14), AI tooling alignment (19), targeted security enforcement (20), maintained-deployment monitoring (22) |
| Before inviting wider contributions | Windows CI and browser smoke (15-16), useful starter work and contributor rehearsal (9-10), documented branching rules (18)                                                                   |
| Alongside the first engine slice    | Behavior and implementation (7-8), searchable/executable documentation (17), curated release notes (18)                                                                                       |
| When the stated need exists         | Feature accessibility (11), release maintenance (12), richer engine checks (21), persistent-data recovery (22), distributed packages (23)                                                     |
| Finish                              | Preserve durable outcomes, transfer genuinely future work, and delete this file (24)                                                                                                          |

Do not leave this plan open indefinitely for hypothetical features. A future item
may be explicitly deferred to a durable issue with its owner, trigger, and
acceptance criteria; deferral is not implementation and must not be marked as a
passing check. Step 24 defines completion and deletion.

## Baseline to preserve

- Keep the Contracts, API Client, API, Web Client, ServiceDefaults, and local
  AppHost boundaries. They separate real responsibilities without an engine framework.
- Keep central package/build settings, public-behavior tests, the shared validation
  action, and the protected `build-test` merge gate. The audit confirmed no bypass
  for that gate; the sole-maintainer review exception is separate.
- Keep immutable action/image references, pinned SSH trust, the non-root API,
  versioned release identities, and separation of edge and application deployment.
- Keep the archive separate and use independently created implementation fixtures.
  Preserve the existing source-material, privacy, and licensing policies.

**Audit validation:** restore, format verification, Release build with no warnings,
72 .NET tests, all five release/deployment shell suites, frontend Release publish,
and the published-configuration guard passed. Relative Markdown file targets
resolved. A separate mocked first-deployment failure exposed the recovery defect
in step 1 despite those passing suites. The audit did not start services, deploy,
or establish fresh-editor, browser, or live-host acceptance.

Use [development setup](setup/development.md) and [testing guidance](quality/testing.md)
for validation commands. Code changes need the normal solution gate and relevant
script checks; documentation-only changes need link, reference, and diff checks.
Workflow changes also need their actual hosted checks before hosted success is claimed.
Deployments, releases, credential handling, and destructive operations still need
explicit authorization under [AGENTS.md](../AGENTS.md).

## Phase 1: Close operational gaps

Address these before relying on fresh-host deployment or expanding deployment
capabilities. They do not require adding new hosting infrastructure.

### 1. Recover a failed first deployment

**Finding:** [activation](../scripts/deploy-app.sh) writes `pending` even without a
predecessor. Rollback requires `previous`, fails when it is absent, and leaves
subsequent activations blocked. Existing tests always seed a legacy installation.

- [x] Add explicit transaction state for an initial deployment. Distinguish a
      legitimately absent predecessor from a missing or corrupt expected predecessor.
- [x] On initial failure, stop any partially started candidate and restore a
      defined undeployed state. Clear `pending` only after successful recovery;
      preserve useful diagnostics. Do not just ignore a missing `previous` file.
- [x] Extend [deployment tests](../tests/deploy-app/run.sh) for first-start failure,
      first-deployment smoke failure after activation, successful retry, and failed
      cleanup. Preserve existing upgrade and rollback behavior.
- [x] Document initial-deployment recovery in [hosting](setup/hosting.md).

**Acceptance:** mocked failure/recovery/retry scenarios pass without SSH or Docker
services. An expected predecessor disappearing still fails safely. A live staging
rehearsal, when authorized, is recorded separately from local regression evidence.

**Result (2026-09-22):** The [mocked deployment suite](../tests/deploy-app/run.sh)
passes all ten scenario groups, covering initial failure/recovery/retry, failed
container and file cleanup, missing candidate files, and missing or corrupt
predecessor records and manifests. Restore, format verification, Release build
(zero warnings), and all 72 .NET tests passed. The
[recovery procedure](setup/hosting.md#application-activation-and-rollback) describes
the undeployed state, retained diagnostics, and retry. No live staging rehearsal
was performed for this step.

### 2. Validate frontend packaging before merge

**Finding:** PR CI builds the web project, but Release publishing and the existing
portability guard run only in [deployment](../.github/workflows/_deploy.yml).
Smoke JavaScript and its package are also absent from PR validation.

- [x] Add frontend Release publish and [verify-web-publish.sh](../scripts/verify-web-publish.sh)
      to PR validation, reusing existing checks and avoiding unnecessary duplicate work.
- [x] Validate the smoke package with `npm ci` and check `smoke.mjs` syntax before
      deployment. Preserve the stable required `build-test` check and failure diagnostics.
- [x] Document local equivalents and distinguish build/package checks from browser
      acceptance. Dependency installation already precedes activation; browser smoke
      execution follows activation and can trigger recovery.

**Acceptance:** CI rejects a broken publish or leaked environment-specific web
configuration before merge. Smoke dependency/syntax errors fail validation.
These checks require no deployment credentials or public deployment.

**Result (2026-09-22):** [Shared validation](../.github/actions/validate/action.yml)
now publishes and checks the frontend in PR CI and validates the smoke package
in both callers. Deployment retains its required packaging job without an extra
publish. Restore, format verification, Release build (zero warnings), all 72 .NET
tests, all five script suites, Release publish, portability checks, and Node 22
dependency/syntax checks passed locally. Nine injected packaging/configuration,
dependency, and syntax failures were rejected with their diagnostics retained.
[Local commands and browser boundaries](quality/testing.md#ci-and-deployment-validation)
are documented. The first hosted PR `build-test` run remains unverified; no
deployment or live browser acceptance was performed for this step.

### 3. Maintain browser-smoke dependencies

**Finding:** [Playwright is pinned](../tests/deploy-smoke/package.json), but
[Dependabot](../.github/dependabot.yml) has no npm entry for this package.

- [x] Add version updates for `/tests/deploy-smoke` using the existing update cadence.
- [x] Extend the [supply-chain declaration check](../tests/supply-chain/run.sh) to
      catch omission of this package without tying the check to a particular version.
- [x] Validate the package/lockfile and review browser-smoke behavior when updating
      Playwright; version-update configuration alone is not a browser acceptance test.

**Acceptance:** the declaration check passes and Dependabot recognizes the npm
directory after merge. Dependency updates receive the checks from step 2.

**Result (2026-09-22):** Weekly npm updates now cover the smoke package with the
existing dependency cooldowns. The declaration suite passes; isolated cases
reject omitted coverage, the wrong directory or ecosystem, and coverage split
across unrelated entries. Node 22 `npm ci` and syntax checks passed with
Playwright 1.63.0 unchanged. Restore, format verification, Release build (zero
warnings), and all 72 .NET tests passed. The existing smoke assertions were
reviewed, and [maintenance guidance](quality/testing.md#browser-smoke-dependency-updates)
records the package checks and browser evidence needed for future updates.
Dependabot recognition of the npm directory remains unverified until merge;
no deployment or live browser acceptance was performed for this step.

### 4. Correct operational documentation and unresolved host evidence

**Finding:** [GitHub setup](setup/github.md) describes a separate unprivileged
smoke job and old timeouts; smoke now runs in the 45-minute deployment job with
`packages: write`, after SSH setup. Its opening unpublished-workflow snapshot and
[hosting's](setup/hosting.md) "before merging" instructions are also obsolete.

- [x] Describe the actual job, token, and on-disk credential boundaries. Review
      whether the combined job is intentional; record that decision or make a focused
      change with recovery coverage. Do not imply this audit demonstrated exploitation.
- [x] State that production workflows must be dispatched from `main`, separately
      from the protected application source `ref`, in [release guidance](release/README.md).
- [x] Replace completed rollout instructions and conflicting verification diaries
      with current procedures and concise evidence links. Keep unresolved host adoption
      explicit rather than assuming merge means host configuration was applied.
- [x] Carry forward administrator confirmation of the SSH host key's trusted
      source and [host verification](setup/hosting.md#host-caddy-conflicts-and-read-only-verification)
      of the running Caddy digest and competing native-service boot state.

**Acceptance:** workflow code, instructions, and any inspected settings agree.
Every remaining host action names its owner and unverified state. Documentation
work does not perform a deployment; successful SSH use alone does not establish
how the original host key was authenticated.

**Result (2026-09-22):** [GitHub setup](setup/github.md#deployment-job-credential-boundary)
now matches the workflow's job permissions, retained Docker/SSH credentials,
timeouts, and combined activation/smoke/recovery decision. Release guidance
requires `main` dispatch separately from protected application source. Read-only
GitHub checks confirmed environment branch rules, production approval settings,
both shared-profile variables, and the completed edge adoption run. The
[hosting evidence](setup/hosting.md#recorded-deployment-evidence) distinguishes
that run from the earlier staging browser check; original host-key provenance,
current Caddy digest/boot state, and application acceptance after adoption remain
explicitly unverified and assigned to `ostomachion`. Documentation link, anchor,
workflow-reference, and diff checks passed. No workflow code, credentials,
services, or deployment state were changed; no new deployment was performed.

## Phase 2: Make the supported contributor path accurate

### 5. Repair development instructions and launch leftovers

**Finding:** [CONTRIBUTING](../CONTRIBUTING.md) promises commit-time formatting,
although Husky is opt-in. The web project's IIS Express profile advertises origins
not allowed by development CORS. Fresh-checkout editor acceptance remains open.

- [x] Say that format verification is required and hooks are optional; link the
      authoritative setup commands instead of duplicating them.
- [x] Remove the unsupported IIS Express profile, or explicitly support and test
      it with matching configuration. Preserve the documented direct and Aspire paths.
- [x] Correct the old `OpenGameBuilder.Web` startup title and scoped-CSS filename
      hint in [index.html](../src/OpenGameBuilder.Web.Client/wwwroot/index.html).
- [ ] Follow the setup guide from a fresh checkout in Visual Studio and VS Code,
      including F5, debugger attachment, frontend startup, and the API request.

**Acceptance:** the solution gate passes after configuration changes. Both
documented editor paths work without undocumented steps, Docker, or production
credentials; record actual editor verification separately from CLI results.

**Result (2026-09-22, editor acceptance partial):** CONTRIBUTING now requires
format verification and links the optional-hook setup. The unsupported web IIS
Express profile/settings are removed, and the startup title and scoped-CSS hint
match the application and project. Restore, format verification, Release build
(zero warnings), all 72 .NET tests, frontend Release publish, and the portability
guard passed. Fresh-checkout Visual Studio and VS Code F5 rehearsals started the
API and frontend, hit the API breakpoint, and displayed the Development heading.
[Setup verification evidence](setup/development.md#recorded-setup-verification)
records the editor versions, successful checks, and remaining Blazor debugger
acceptance; the full editor item remains unchecked.

### 6. Remove unused scaffolding and duplicate documentation

**Finding:** root placeholders, unused configuration, template examples, and
repeated contributor prose still create maintenance work without current benefit.

- [x] Remove or give a useful contributors pointer to `CONTRIBUTORS.md`. Replace
      the empty `CHANGELOG.md` with the curated release process in step 18.
- [x] Remove `.browserslistrc` while it has no consumer and update its references.
      Keep the actual [browser policy and acceptance matrix](frontend/browser-support.md).
- [x] Remove unused gRPC/Azure/service-discovery examples, unused Bootstrap/form
      CSS, and stale template hints. Shorten AppHost history while retaining the
      explanation of its current fixed-port, CORS, and launch-profile constraints.
- [x] Consolidate significant-change guidance in CONTRIBUTING. Keep SUPPORT
      focused on choosing a contact route; link policies and forms instead of repeating
      them. Retain short source-material/privacy reminders at submission points.
- [x] Replace local reunion rosters and unowned forum-reconstruction plans with
      useful pointers to the owning archive/community location. Preserve substantive
      material until an appropriate destination is agreed.
- [x] Finish the reviewed shared-resource move tracked by [issue #56](https://github.com/OpenGameBuilder/opengamebuilder/issues/56)
      and [organization PR #1](https://github.com/OpenGameBuilder/.github/pull/1), then
      replace the temporary shared-content pointer. Recheck their status first.

**Acceptance:** no empty promises or unused declarations remain in scope, and all
affected local paths/anchors resolve. Code/style removal preserves existing
behavior. Record cross-repository completion separately from local cleanup.

**Result (2026-09-22):** Root contributor and changelog placeholders now provide
useful contributor links and a [curated release-note process](release/README.md#curated-release-notes).
Unused browser configuration, template examples, and form styles are removed;
contribution/support guidance is consolidated. Community/archive pointers retain
the historical roster at an existing public revision without claiming current
membership or promising forum reconstruction. The
[local cleanup checks](quality/testing.md#frontend-asset-cleanup-evidence) passed,
including the solution gate, 72 tests, frontend publish, configuration guard,
and local documentation paths/anchors. No new browser acceptance was performed.

Cross-repository result: [organization PR #1](https://github.com/OpenGameBuilder/.github/pull/1)
was merged after standards and scope reviews found no issues; all 211 original
external links, the source license, and local links were verified. Its published
resources tree matches the reviewed revision, and the documentation index now
links to `main/resources`. [Issue #56](https://github.com/OpenGameBuilder/opengamebuilder/issues/56)
remains open until the application-side removal and pointer changes reach `main`;
these local changes have not been published. Automated changelog selection for
releases remains in step 18.

## Phase 3: Deliver the first engine slice

Begin this once the supported development path is usable. Do not wait for optional
documentation cleanup, new hosting capabilities, or additional governance machinery.

### 7. Choose the first engine milestone

**Finding:** the project has useful application boundaries but no selected engine
behavior, independent fixture, or acceptance contract.

- [ ] Choose one observable behavior and explicit non-goals; decide whether the
      slice concerns playback, import, or another narrowly defined capability.
- [ ] Write a small independently created fixture with provenance and expected
      outputs, including relevant invalid-input behavior. Use no decompiled source.
- [ ] Record the contract in a short public issue or engine document and update
      the README's next milestone. Link the existing repository map rather than
      creating another architecture inventory.

**Acceptance:** another contributor can understand what to implement and how to
judge it without designing the whole engine, renderer, storage layer, or editor.

### 8. Implement and test that slice

**Depends on:** step 7's accepted behavior and fixture.

- [ ] Implement the selected behavior in a plain library testable without Blazor,
      HTTP, or a database. Introduce rendering/input/time/randomness seams only when
      the implemented behavior needs them.
- [ ] Test the agreed observable results and relevant failure cases. Verify
      deterministic behavior where the contract requires it.
- [ ] Add the project/tests to normal validation and document the runnable example
      and remaining limits. Use the independently authored fixture as a small reference
      scene or game and a checked documentation example (step 17). Do not infer broad
      original-game compatibility from it.

**Acceptance:** the fixture works through the normal test gate and demonstrates
the agreed behavior. No empty generic engine framework or speculative services
are prerequisites. Further foundation work responds to actual engine needs.

## Phase 4: Prepare for wider participation

### 9. Publish an actionable contributor backlog

**Finding:** the audit found no open `good first issue` or `help wanted` tasks.
The open database, blob-storage, API-subdomain, and Minimal API proposals describe
large additions or alternatives rather than bounded onboarding work.

- [ ] Triage [database #37](https://github.com/OpenGameBuilder/opengamebuilder/issues/37),
      [blob storage #36](https://github.com/OpenGameBuilder/opengamebuilder/issues/36),
      [API subdomains #46](https://github.com/OpenGameBuilder/opengamebuilder/issues/46),
      and [Minimal APIs #38](https://github.com/OpenGameBuilder/opengamebuilder/issues/38).
      Record decisions or concrete deferral triggers; do not present speculative
      infrastructure or a controller rewrite as required engine work.
- [ ] Prepare three to five small tasks with acceptance criteria, likely files,
      validation commands, and a willing maintainer contact. Apply the appropriate
      newcomer/help labels after checking the tasks are actually approachable.
- [ ] Include non-code work: setup verification, independent behavior examples,
      documentation, or accessibility checks for implemented features. Keep consequential
      decisions public and align README/contribution links with the real queue.
- [ ] Verify native Project auto-add/status workflows handle agreed issue/PR
      bookkeeping. Keep triage human-owned; do not close valid reports merely for
      inactivity or add bots that generate unreviewed issues and comments.

**Acceptance:** a newcomer can select useful work without first designing a major
subsystem. Preparing task text alone does not count as publishing a usable backlog.

### 10. Establish continuity and rehearse a contribution

**Finding:** [stewardship](community/stewardship.md) records no agreed backup
operator or independent private-reporting contact. Written procedures do not
establish another person's access or a newcomer's successful experience.

- [ ] Before broader participation or operational handoff, the primary maintainer
      obtains a willing delegate's agreement on repository, hosting, domain, release,
      and recovery responsibilities; verify necessary access and rehearse recovery.
- [ ] Establish an independent private route for concerns involving the primary
      contact. Keep sensitive account-recovery details private.
- [ ] Add CODEOWNERS only when actual area owners accept responsibility. Revisit
      the sole-maintainer review exception when a second trusted reviewer can routinely
      review maintainer PRs; preserve the no-bypass CI gate.
- [ ] Have someone unfamiliar with the repo follow setup and complete a small
      contribution through the actual review/check process; fix the friction found.

**Acceptance:** agreed people and contact routes are recorded, a backup can perform
the agreed recovery, and an independent contributor completes the workflow.
Owner until delegation: `ostomachion`. This remains open until people and access
are available; no additional committee or policy framework is needed.

## Work tied to a specific trigger

### 11. Complete frontend failure handling and accessibility

**Trigger:** the first functional frontend feature. The placeholder catches HTTP
errors but lets malformed/null-response exceptions escape; loading, recovery,
focus, and error controls also have [documented gaps](frontend/browser-support.md).

- [ ] Define loading, success, expected transport/timeout failures, invalid
      responses, and recovery. Handle known failures without broadly hiding defects;
      retain useful diagnostics without sensitive response data.
- [ ] Add meaningful component coverage for those states. Extend the existing
      published-app PR harness from step 16, sharing applicable assertions with the
      deployment smoke test. Keep component, browser, and live-deployment evidence
      separate; this feature-triggered work does not postpone the basic PR harness.
- [ ] Fix the heading/focus mismatch, loading/error announcements, and keyboard
      semantics of error controls. Verify the implemented workflow against the browser,
      keyboard, assistive-technology, and mobile matrix; record unverified targets.
- [ ] Add axe-based checks to meaningful rendered states, including failures and
      dialogs when present. Perform manual keyboard, focus, zoom, screen-reader, and
      touch checks; automated accessibility results do not establish conformance.

**Acceptance:** a wrong API URL or unusable frontend fails the browser check even
with healthy API liveness. Expected failures offer accessible recovery, and exact
browser/manual acceptance evidence accompanies the feature.

### 12. Reassess release maintenance only when needed

**Trigger:** supporting an older released version, handing off operations, or
release accumulation creating measurable operational cost. Owner: `ostomachion`.

- [ ] Decide whether the current standard/patch/tag/merge-back automation earns
      its maintenance cost. Retaining it with a concrete support need is a valid
      decision; simplify only with one documented replacement and regression coverage.
- [ ] Before removing legacy in-place migration code, verify that every supported
      installation has migrated. Do not infer host state from merged code.
- [ ] Define release retention/cleanup when needed, preserving active/rollback
      artifacts and assets needed by older browser sessions. No speculative cleanup job.
- [ ] Consider a merge queue when concurrent merges cause repeated update/retest
      work. Add `merge_group` handling to required workflows and verify the gate before
      enabling it; a queue is not needed to establish the branching policy in step 18.

**Acceptance:** a recorded keep/simplify decision answers an actual need. Any
change preserves artifact identity, recovery, authorization, and required checks.
This step does not block engine development or justify further deployment expansion.

## Additional contributor and maintenance infrastructure

### 13. Make setup and validation reproducible

- [x] Add a small `doctor` command that reports selected SDK/tool versions,
      missing prerequisites, and actionable remedies. Keep installation and trust
      changes explicit; ordinary checks must not change the developer's environment.
- [x] Provide documented formatting, quick-check, full-check, and browser-test
      commands, with shared implementations used locally and by CI. Keep the headless
      build/test path usable without deployment credentials or running services.
- [x] Replace accidental SDK drift from `global.json`'s `latestMinor` roll-forward
      with a deliberate supported baseline for formatting, analyzers, and builds.
      Log the selected SDK and update it through reviewed dependency changes.
- [x] Introduce committed NuGet lockfiles for shipped application entry points and locked
      CI restores after SDK selection is settled. Keep npm tools exactly pinned with
      committed lockfiles. Document how intentional dependency updates refresh them;
      a library lockfile does not constrain downstream consumers.

**Acceptance:** a clean checkout runs the documented commands with the declared
toolchain. Missing prerequisites produce useful diagnostics, CI rejects missing
or stale shipped-application locks, and local/CI checks have equivalent scope. A fresh editor rehearsal remains
the separate acceptance in step 5. See [NuGet lockfiles](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#locking-dependencies).

**Result (2026-09-22):** The read-only doctor and shared formatting, quick, full,
and browser commands are documented in [development setup](setup/development.md)
and used by CI. SDK selection is exact; the shipped API and Web Client have
committed locks covering CI, CodeQL, and packaging. Tests and the local-only
AppHost restore normally and remain in the solution build/test gates; their
transitive dependency graphs are not frozen. This avoids maintaining custom
platform locks or a bot that repairs dependency PRs; see the
[dependency-update rationale](quality/dependency-update-research.md).
A fresh source snapshot passed the full local
gate with serialized MSBuild: zero build warnings, 72 tests, frontend packaging,
smoke-package checks, and all five shell suites. Missing prerequisites, incorrect
versions, and missing/stale dependency locks were rejected. The
[validation evidence](quality/testing.md#reproducible-command-validation) separates
these results from the unverified hosted CI and live browser runs. No deployment
or editor rehearsal was performed.

### 14. Format and lint first-party content consistently

- [x] Keep `dotnet format` and existing analyzers for C#. Promote selected useful
      style rules to enforced warnings rather than enabling a large rule set wholesale.
- [x] Add exactly pinned Prettier for Markdown, JSON, YAML, CSS, and JavaScript;
      choose explicit indentation/prose wrapping consistent with scoped EditorConfig
      settings. Use markdownlint-cli2's Prettier-compatible preset for structural rules.
- [x] Add actionlint for workflows, ShellCheck for shell defects, and shfmt for
      shell formatting. Use versions compatible with the workflow syntax in this repo.
- [x] Add pinned lychee checks for local file/image links and anchors, including
      root and first-party GitHub documents. Check generated HTML when step 17 lands.
      Schedule bounded external-link reports separately; remote outages must not block
      unrelated PRs. Keep exclusions narrow and explained.
- [x] Share configurations between editor, optional hooks, command line, and CI.
      Exclude generated artifacts, dependencies, and vendored skills; avoid competing
      formatters for a file type.
- [x] Publish and verify the initial formatting sweep. Formatting commit `1f646a6`
      was included with the tooling in [PR #114](https://github.com/OpenGameBuilder/opengamebuilder/pull/114).
      Rerunning the configured formatters on merged `main` (`f8db700`) produced no
      changes; the originally planned separate mechanical PR has no remaining diff.

**Acceptance:** deliberate formatting, Markdown-structure, missing-target/anchor,
workflow, and shell defects fail their appropriate checks with clear fixes. Clean
files pass on Windows and Linux. CI enforces the rules without requiring hooks.
Defer aggressive prose-style linting unless a recurring problem warrants it.
Sources: [Prettier](https://prettier.io/docs/install),
[markdownlint compatibility](https://github.com/DavidAnson/markdownlint/blob/main/doc/Prettier.md),
[actionlint](https://github.com/rhysd/actionlint/blob/main/docs/checks.md),
[ShellCheck](https://github.com/koalaman/shellcheck), [shfmt](https://github.com/mvdan/sh),
[lychee](https://lychee.cli.rs/guides/cli/).

**Result (2026-09-22, implementation and formatting acceptance complete):** The
[shared content workflow](quality/content-checks.md) pins and verifies the tools,
preserves formatter ownership, checks local links offline, and schedules bounded
external reports. The full Windows gate passed with zero build warnings and 72
.NET tests; all seven content regression groups and the final content gate passed.
[Validation evidence](quality/content-checks.md#recorded-validation) records the
injected C# failures, installer checks, and narrow actionlint cache-mode exception.
The [Ubuntu CI gate](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35744440511/job/106802281361)
also passed content checks, all seven regression groups, and the full solution
gate for the exact tree merged in PR #114. A fresh Windows formatter pass over
that merged tree produced no changes. The external-link schedule has not yet run;
it is separate from the required formatting and local-link gate. No application
services or deployments were started by this formatting verification.

### 15. Validate the supported platform and keep CI understandable

- [x] Add a Windows restore/format/Release-build/test lane alongside Linux. Keep
      Linux shell/container checks in their suitable environment; do not multiply
      every job across an unnecessary OS matrix.
- [x] Use the commands from step 13, with focused document checks for document
      changes and full relevant checks for application/workflow changes. Path-based
      selection must not silently omit required validation or strand required checks.
- [x] Preserve the stable `build-test` gate. If it becomes an aggregate, explicitly
      verify every required dependency's result, including failure/cancellation cases.
      Retain actionable logs, reports, selected versions, and bounded artifact retention.

**Acceptance:** real hosted Windows and Linux runs pass, a failed required lane
prevents merging, and a documentation-only PR receives its intended checks.
Record local results separately; Windows CI does not establish F5/debugger support.

**Result (2026-09-22):** The [hosted Windows/Linux run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35748017596)
passed both solution lanes (72 tests each), Linux full/container checks, and the
stable aggregate. A real Windows restore failure was rejected by the required
gate while Linux passed; an isolated SDK installation fixed the runner's older
WebAssembly workload-manifest input without changing lockfiles. The
[documentation-only run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35747186192)
passed content and the aggregate with both build lanes skipped. Thirteen policy
regression groups cover complete Git ranges, lane selection, failures,
cancellation, missing results, and workflow wiring. Local solution, content,
packaging, smoke-package, and all five shell-suite checks also passed.
[Permanent acceptance evidence](quality/testing.md#recorded-platform-ci-acceptance)
records the required-check inspection, diagnostic retention, and evidence limits;
the temporary acceptance PR was closed unmerged. No deployment or editor
acceptance was performed.

### 16. Exercise the published application in PRs

**Depends on:** step 2's packaging checks; this adds browser behavior, not another
claim that syntax or publication proves rendering.

- [ ] Add an `@playwright/test` harness that serves the Release-published frontend
      and real API locally with the intended same-origin API path and release base path.
      Reuse appropriate deployment assertions; require no SSH, registry write access,
      production secrets, or public deployment.
- [ ] Run Chromium, Firefox, and WebKit checks for startup, API-backed content,
      expected revision, routes/reload, assets, and unhandled page errors. Manage local
      server lifecycle in the harness and start with a small predictable worker count.
- [ ] When an interactive feature exists, exercise a meaningful user action and
      assert its visible result. Add this with the feature rather than inventing an
      interaction for the current placeholder or postponing the startup/API harness.
- [ ] Retain failure screenshots, traces, and a readable report. Forbid focused
      tests; bound retries and surface flaky passes rather than treating retries as
      proof of health. Keep deployment retry policy separate from PR test policy.
- [ ] Revise the permanent browser policy to distinguish checked current-stable
      targets from aspirational previous-version/device coverage. Record exact browser
      and OS versions; Playwright engines, branded browsers, emulation, and physical
      Safari/iOS checks are different evidence. Promise only coverage that is performed.

**Acceptance:** wrong API routing, a broken release base path, missing assets, or
an unusable frontend fails PR validation even when API liveness is healthy. Three
engine results are recorded; live hosting and manual accessibility remain separate.
Sources: [Playwright servers](https://playwright.dev/docs/test-webserver),
[browser coverage](https://playwright.dev/docs/browsers),
[accessibility checks](https://playwright.dev/docs/accessibility-testing).

### 17. Publish searchable documentation and checked examples

- [ ] Build a DocFX site with its modern template from the existing Markdown.
      Keep one source copy per document, generated HTML untracked, and concise
      navigation for setup, contribution, architecture, testing, and operations.
      Exclude this temporary plan from site content and navigation.
- [ ] Add search and edit links, a PR site build, and checks of rendered local
      links/anchors. Use appropriate failing diagnostic severities for broken content.
      Keep external-link maintenance separate as described in step 14.
- [ ] Configure publication from validated protected content when authorized,
      and verify the actual hosted navigation, assets, search, and links. Do not treat
      a successful local site build as publication acceptance.
- [ ] Make the engine example from step 8 compile/run in CI and reuse its checked
      content in tutorials. Add filtered public .NET API reference when meaningful
      engine APIs exist; keep HTTP OpenAPI/Scalar documentation in its appropriate role.

**Acceptance:** contributors can find supported setup and an executable example
without maintaining a separate wiki or copied guides. Site build/link failures are
actionable, and hosted acceptance is recorded separately. Custom branding and API
generation do not block the first engine slice.
Sources: [DocFX template](https://dotnet.github.io/docfx/docs/template.html),
[.NET reference](https://dotnet.github.io/docfx/docs/dotnet-api-docs.html).

### 18. Clarify branches and make release notes useful

- [ ] Document protected `main`, short-lived branches, draft PRs, squash merges,
      and deletion of merged branches in permanent contribution/release guidance.
      Reserve `patch/vX.Y.Z` for the existing released-hotfix path and its merge-back.
      Do not introduce a permanent `develop` branch without a demonstrated need.
- [ ] Make `CHANGELOG.md` the canonical curated account of notable changes.
      Prepare a reviewed entry before tagging, covering observable changes, breaking
      behavior, and migration guidance; omit mechanical maintenance noise.
- [ ] Feed the selected version's entry into the existing production release
      workflow after deployment validation. Use its existing generated PR notes as
      drafting material or supplemental references/credits, with `.github/release.yml`
      categories based on actual PR labels. Avoid two separately maintained summaries.
- [ ] Keep one owner of version numbers, tags, and publication. Do not bolt
      Release Please or semantic-release onto the current deploy/smoke/tag contract.
      Require descriptive PR titles; enforce commit grammar only if a chosen workflow
      actually uses it. Preserve idempotency and patch-flow regression coverage.

**Acceptance:** a contributor can select a branch/PR path, and a rehearsed release
selects the correct reviewed changelog entry without changing tag timing or creating
duplicate releases. Actual publication still requires release authorization.
Sources: [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow),
[Common Changelog](https://common-changelog.org/),
[generated notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes).

### 19. Align AI tooling and verify that it helps

**Finding (2026-09-22):** documented Aspire CLI and AppHost SDK are 13.4.2 while
the hosting package is 13.5.4. The vendored Aspire skills describe 13.4, and the
dotnet-inspect guide derives from 0.5.0 without pinning the executable. Verified
upstream candidates are [Aspire 13.5.4](https://github.com/microsoft/aspire/releases/tag/v13.5.4),
[skills 0.0.2](https://github.com/microsoft/aspire-skills/releases/tag/v0.0.2)
(describing 13.5.3), and [dotnet-inspect 0.25.0](https://github.com/richlander/dotnet-inspect/releases/tag/v0.25.0).
These are update candidates, not proven compatible upgrades; recheck at execution.

- [ ] Update the compatible CLI, AppHost SDK, skill bundle, and documented
      commands together using [AI tooling maintenance](setup/ai-tooling.md). Preserve
      source pins, licenses, checksums, local-only scope, and Compose production.
      Review newly supplied hook/extension assets separately rather than enabling them.
- [ ] Replace the long dotnet-inspect reference with the upstream entry point
      that retrieves its installed tool's version-matched guide. Decide and document
      how the optional executable is pinned/updated without making AI mandatory.
- [ ] Keep AGENTS.md authoritative and concise; add client-specific adapters only
      for supported clients that need them. Verify actual instruction/MCP discovery;
      do not assume a configuration filename works in every client.
- [ ] Add a read-only tool/version/provenance check and an owned review cadence
      for pins not covered by Dependabot. Changes arrive as bounded reviewed updates,
      not unpinned regeneration during build or routine agent work.
- [ ] Rehearse two or three representative tasks after significant tooling
      changes, checking commands, repository boundaries, reviewability, and truthful
      evidence. Use a small manual checklist, not an agent-evaluation service.

**Acceptance:** source checks and the normal gate pass, Windows Aspire startup
and MCP discovery work on the selected toolchain, and supported clients load the
intended guidance. Record runtime evidence separately from text provenance.
Defer extra MCP servers, cloud environments, agent fleets, and repository plugins
until a recurring workflow justifies them. Enforce permissions outside prompts too.
Sources: [Codex instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[Copilot support](https://docs.github.com/en/copilot/reference/custom-instructions-support).

### 20. Enforce the remaining supply-chain boundaries

**Finding:** secret scanning, push protection, private vulnerability reporting,
and dependency security updates are already enabled. Full-SHA action references
exist, but the GitHub setting requiring them was disabled at the audit.

- [ ] Enable the repository's full-SHA action-pinning requirement and verify it
      rejects an unpinned external action before execution. Keep declaration checks
      as complementary coverage; review reusable-workflow policy separately.
- [ ] Add PR dependency review with an explicit severity/triage policy. Cover npm
      updates from step 3 and newly added tooling alongside existing NuGet updates;
      check that resolved/transitive dependencies are visible to the chosen checks.
- [ ] Keep fork-PR validation credential-free and read-only. Review privileged
      workflow boundaries so untrusted PR code/artifacts are not executed with write
      tokens or deployment credentials. Preserve protected-source deployment checks.
- [ ] Scan the actual runtime container, including OS packages, with a pinned
      scanner and an owned triage policy. Explain narrow exceptions and their review
      date; avoid hiding old findings behind an unexplained permanent baseline.

**Acceptance:** controlled policy/dependency/scan failures produce actionable
results and block the intended path. Record actual GitHub setting and hosted PR
behavior separately from local configuration tests. Extra scanners must cover a
real gap rather than duplicate existing alerts.
Sources: [Actions controls](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository),
[dependency review](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependency-review).

## Later work with concrete adoption triggers

### 21. Grow engine evidence with implemented behavior

**Trigger:** replay, serialization, editing, import, or performance-sensitive
behavior exists. The initial fixture and runnable example belong to steps 7-8.

- [ ] Record fixture authorship, source, permitted use, and expected behavior.
      Distinguish independently observed compatibility behavior from assumptions;
      keep decompiled source and unapproved/private material out of implementation inputs.
- [ ] Make reproducible bug reports possible with engine version, safe minimal
      fixture, input sequence, expected result, and seed where relevant. Review/redact
      diagnostic material before sharing; do not require private archived games.
- [ ] Add property tests for actual invariants such as serialization round trips,
      deterministic replay, and edit/undo. Use focused behavioral coverage rather than
      an arbitrary repository-wide coverage percentage.
- [ ] Fuzz importers and malformed inputs when an import format exists. Enforce
      concrete file-size, decompression, path, and execution/resource limits at the
      relevant boundary and retain minimized failing inputs as safe regressions.
- [ ] Establish small repeatable performance baselines when engine workloads
      justify them. Record environment and tolerances before gating regressions; avoid
      broad benchmark infrastructure or speculative architecture-test frameworks.

**Acceptance:** each added check proves an implemented contract, finds a deliberate
violation, and produces a reproducible diagnostic. Document limitations and source
provenance in permanent engine/testing guidance; never infer broad compatibility.

### 22. Make operations and recurring automation actionable

**Trigger:** a maintained public deployment exists, as it does now. Monitoring
is current work; the separate backup/restore work begins before persistent
user/project data is relied upon.

- [ ] Add external uptime/API, certificate-expiry, and host-capacity monitoring
      with a named recipient and a permanent response procedure. Alert on sustained
      failure and recovery; do not rely solely on GitHub scheduled jobs for uptime.
- [ ] Give every recurring automation an owner, purpose, cadence/cost or retention
      limit, and expected failure action. Prefer bounded maintenance reports or PRs;
      avoid unattended activity that exceeds available review capacity.
- [ ] When persistent data arrives, document backup scope, retention, recovery
      objectives, and ownership, then rehearse restoration in an isolated environment.
      A successful backup job alone does not establish recoverability.

**Acceptance:** a controlled failure reaches the intended operator and the runbook
leads to a verified response. Data recovery has measured restore evidence when
applicable. Setup, credentials, and operational rehearsals retain their normal
authorization requirements; procedures and evidence live in permanent guides.

### 23. Verify packages when distributing them

**Trigger:** engine packages, binaries, or other downloadable release artifacts
are offered to consumers beyond the in-repository application.

- [ ] Install the produced package into a separate consumer project and exercise
      its public example. Check dependencies, metadata, license notices, and debugging
      information; successful in-solution project references are insufficient.
- [ ] Attach checksums, an SBOM, and provenance attestations to the exact released
      artifacts, and implement/document verification by consumers or deployment.
      Generated attestations do not themselves establish correctness.
- [ ] Evaluate immutable releases. Prepare a draft, attach all intended assets,
      and publish through the single release owner; verify the policy for assets as
      well as tags and preserve the existing release authorization boundary.

**Acceptance:** an independent consumer uses the exact package, verifies its
identity/provenance, and can trace it to source and validation. Release artifacts
and permanent distribution instructions agree. Defer until distribution exists.
Sources: [attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations),
[immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).

## Completion and removal

### 24. Retire this temporary plan

- [ ] Confirm required near-term work has passed its acceptance checks. Resolve
      pending hosted/manual evidence explicitly; do not equate local tests with it.
- [ ] Move genuinely future, trigger-dependent work to durable issues with an
      owner, trigger, and acceptance criteria, or record a reasoned decision not to
      pursue it. Do not mark deferred work as implemented.
- [ ] Ensure permanent setup, testing, browser, AI, release, and hosting guides
      describe current behavior. Preserve useful decisions, source records, and
      historical evidence there; ordinary readers must never need this plan.
- [ ] Verify other tracked files, site navigation, and generated documentation
      inputs contain no references to this file or its step numbers. Keep this rule
      throughout implementation, not just at deletion time.
- [ ] Delete this file in the completion PR and rerun the applicable documentation
      build/link/reference checks. The Git history retains the completed plan.

**Acceptance:** deleting this file loses no operational instructions, support
contract, accepted decision, meaningful evidence, or actionable remaining work,
and introduces no broken links. Historical rollout/rollback records belong in
[hosting evidence](setup/hosting.md#recorded-deployment-evidence).
