# Foundation checklist

Work through these steps in order within each phase. Prefer one focused pull request
per numbered step; split a step further when needed. Check items off only after the
acceptance check passes. Paths are relative to the repository root.

Track current work here, with completed steps marked done and deferred steps
given a concrete trigger. Check dependency advisories and GitHub settings against
the current repository.

## Phase 1: Establish a foundation for engine development

### 1. Establish the current dependency and toolchain baseline

(done)

### 2. Include the developer launcher in build validation

(done)

### 3. Repair the documented development workflow

- [ ] Follow `docs\setup\development.md` from a fresh checkout in Visual Studio
  and VS Code, verifying F5 launching and debugger attachment.

**Acceptance:** both editor workflows work as documented, and the frontend loads
application information from the local API without undocumented steps or
production credentials.

### 4. Make formatting and build policy consistent

(done)

### 5. Establish API and client behavior tests

(done)

### 6. Establish frontend failure handling and a smoke test

**Deferred until the first functional frontend feature.** The current page is a
placeholder; add the following with that feature rather than introducing test
projects or browser infrastructure now.

- [ ] Define the expected UI for loading, success, network failure, and invalid
  API responses. Handle expected failures explicitly without hiding unexpected
  errors behind broad catch blocks.
- [ ] Add component tests for those states and a published-app browser smoke test
  that verifies a real frontend-to-API request.
- [ ] Preserve useful diagnostic logging without exposing sensitive response data.

**Acceptance:** the smoke test fails if the API URL is wrong or the frontend cannot
start, even when the API's liveness endpoint is healthy.

### 7. Make CI an effective merge gate

- [x] Keep the same build/test/format checks in pull-request CI and deployment
  validation. Add useful failure artifacts and explicit workflow timeouts.
- [x] Inspect both rulesets and legacy branch protection. Require the actual
  stable build/test job, not only CodeQL, code-quality checks, or review.
- [x] Align protected branches with `main` and `patch/v*`. Ensure the intended
  CodeQL checks run for patch PRs too.
- [x] Verify human approval, stale-review dismissal, and release-tag protection.
  Document any deliberate maintainer or release-bot bypasses.

**Acceptance:** a failing test blocks merging a representative PR. A patch branch
receives the intended protections and runnable checks without blocking the
release bot's narrowly authorized work.

**Verified (2026-09-15):** shared validation, failure artifacts, workflow timeouts,
and patch CodeQL triggers are implemented. Authenticated inspection confirmed
there are no legacy protection rules. Live rules now require `build-test` from
GitHub Actions on `main` and `patch/v*`, with no CI bypass. Release-App bypasses
are creation-only; tags cannot be changed or deleted even by the bot.

The only maintainer is the sole eligible reviewer, so a documented PR-only
exception is retained in a separate human-review ruleset, not in the CI gate.
Remove that exception when a second trusted reviewer can review maintainer PRs.
Local formatting, builds, all 62 tests, and failure-exit propagation passed.
Failing-test merge blocking was verified on PRs #82 and #83, including uploaded
assertion diagnostics. The deliberate test was removed. The aggregate CodeQL
gate caught selectable-source action execution; protected source resolution and
trusted action loading address that boundary. Both main and patch validation
then passed all 62 tests, the Docker build, code-quality analysis, and aggregate
CodeQL with zero open alerts. Temporary verification refs were cleaned up.

After the owner approved Workflows write permission,
[Prepare Patch run 35002126742](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35002126742)
successfully created the protected patch branch and bot-authored PR #84. The PR
still required human review and CI; its inherited old-release dependency failed
NuGet Audit, correctly blocking merging rather than bypassing the gate.
The verification PR and both new refs were cleaned up without merging, deploying,
or creating a release. Section 7 is complete; [GitHub setup](setup/github.md)
records the live rules, deliberate exceptions, current-baseline passing checks,
and bot acceptance evidence.

### 8. Write useful repository-specific AI instructions

- [x] Document a short project map and dependency boundaries in `AGENTS.md`, with
  prerequisites, exact validation commands, and links to authoritative policies.
- [x] Explain that Aspire is the local launcher while production currently uses
  Compose. Require explicit authorization for deployments, releases, credentials,
  and destructive operations; documentation-only work should not start services.
- [x] Add thin Copilot-specific guidance only where needed for tool support, or
  correct documentation claiming those files already exist. Avoid duplicated rules.
- [x] Document the Aspire executable required by `.mcp.json` and how contributors
  install and verify it without making AI tools mandatory.

**Acceptance:** a fresh local agent can perform a small code/test change using the
instructions, without guessing commands or accessing deployment credentials.

**Verified (2026-09-19):** `AGENTS.md` now maps the solution's dependency
boundaries, names the local validation gate, and points to the authoritative setup,
testing, policy, hosting, and CI documentation. It documents `aspire` as the
executable used by `.mcp.json`, with the matching 13.4.2 install and verification
commands. The installed executable reported 13.4.2. Aspire is explicitly scoped
to local orchestration; production Compose, releases, credentials, deployments,
and destructive operations require authorization. `CONTRIBUTING.md` now identifies
`AGENTS.md` as the existing repository guidance instead of implying uncommitted
Copilot instruction files exist.

### 9. Record the engine boundary and first milestone

- [ ] Write a short architecture/repository map: API, contracts, API client,
  frontend, AppHost, service defaults, and the separate archive repository.
- [ ] Choose the first compatibility goal and its non-goals: playback, import,
  editor behavior, or one narrowly defined combination.
- [ ] Define a small, independently created fixture and observable acceptance
  criteria for the first engine milestone.
- [ ] Keep game logic testable without Blazor, HTTP, or a database. Introduce
  boundaries for rendering, input, time, and randomness with actual engine work,
  not as empty projects or generic infrastructure.

**Acceptance:** the next engine task is small enough to implement and test without
first adding a new architectural framework.

### Gate: return to engine implementation

- [ ] Steps 1-5 and 7-9 pass their acceptance checks. Section 6 accompanies the
  first functional frontend feature.
- [ ] Local setup works, meaningful tests run, CI enforces them, and agent
  instructions match reality.
- [ ] Resume the scoped engine milestone. Do not wait for every community or
  documentation refinement below.

Complete Phase 2 before relying on further public deployments. If deployments
continue during engine work, bring those steps forward rather than accepting the
known release risks.

## Phase 2: Make deployment and releases dependable

### 10. Test and repair release-script behavior

- [x] Fix `scripts\validate-release.sh` returning failure after successful patch
  validation because its final optional-output condition is false.
- [x] Support documented reruns when a patch tag/release already exists at the
  expected commit. Continue rejecting mismatched tags and invalid version progressions.
- [x] Avoid resolving all of `Directory.Build.props` with `--ours` in
  `scripts\post-release.sh`; preserve non-version changes or require manual resolution.
- [x] Add isolated tests for standard and patch releases, tag conflicts, reruns,
  failed GitHub calls, follow-up PR handling, and merge-back conflicts.

**Acceptance:** the valid-next-patch and already-published-patch cases both pass.
Tests mock external operations and never push branches, tags, or releases.
If simplifying the release workflow instead, remove superseded paths and update
`docs\release` so there is only one supported process.

**Verified locally (2026-09-19):** 20 isolated Bash cases passed with GitHub
operations and pushes mocked, including valid-next and already-published patch
releases. A conflicting props merge-back now stops for manual resolution without
pushing. The test suite is part of shared CI/deployment validation; no actual
release or deployment was run. Restore, formatting verification, Release build,
and all 62 solution tests passed (the documented ASPIRE010 build warning remains).

### 11. Align deployment permissions with the release process

- [x] Audit environment branch/tag restrictions against the actual workflow.
  Distinguish the branch dispatching the workflow from the source SHA it checks out;
  do not blindly replace every environment selector with `patch/*`.
- [x] Verify production approval, release-bot permissions, protected-tag creation,
  and narrowly scoped environment secrets.
- [x] Record who can deploy and recover a release in `docs\setup\github.md`.

**Acceptance:** approved standard and patch workflows are allowed, unintended
dispatch paths are rejected, and normal pull-request validation receives no
production credentials.

**Verified (2026-09-20):** authenticated read-back found production approval by
`ostomachion`, self-review and administrator bypass enabled, environment-scoped
deployment secrets, repository-scoped release-bot tokens, and creation-only bot
tag permission. The stale production `release/**/*` tag selector and staging
`release/**/*` branch selector were removed; both environments now allow only
the `main` dispatch branch. Both CD workflows on merged `main` reject non-`main`
dispatches before source selection. A [live invalid-source run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531224662)
rejected a tag input at the protected-source resolver; validation, production
deployment, and publication were skipped. A second
[non-`main` dispatch](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531484408)
failed at the first workflow guard, with all downstream jobs skipped. The
first merge-triggered
[staging run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531071912)
passed source resolution and build/test but failed before syncing files or
restarting services: its environment secrets were empty in the reusable workflow
after `secrets: inherit` was removed. The merged fix restored the caller handoff
and added a credential-presence check before image publication. Its
[staging run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531733842)
passed source resolution, build/test, credential check, image publication, SSH,
file sync, service restart, and the API liveness smoke test at commit
`65cf767afd587ce5ea72368df8d888c69bd0a7e7`.
[GitHub setup](setup/github.md#deployment-authority-and-recovery) records the
dispatch/source distinction, actual operator and recovery limits, and the
read-only permission audit. The signed-in organization Actions settings page
reported no organization secrets; the audit CLI token still receives 403 for
that API inventory. Normal PR CI references no deployment environment or
production credentials. The protected `main`/patch source paths are configured
for standard and patch releases, but no positive production release, patch
deployment, tag, or GitHub Release was performed for this permission audit.
Administrator bypass is retained for sole-operator emergency recovery, not
routine releases; while enabled, the `main`-only selector is not an absolute
barrier to an administrator forcing a waiting job.

### 12. Isolate shared-edge changes from application deployments

- [x] Stop routine staging/application deployments from recreating the shared
  production Caddy service.
- [x] Validate a candidate Caddy configuration before activating it; use a
  graceful reload when configuration changes.
- [x] Coordinate operations that modify shared edge files or services across
  staging and production. Avoid cancelling an in-flight mutation midway through.

**Acceptance:** deploy staging while checking production availability. An invalid
candidate edge configuration is rejected without replacing the working configuration.

**Implemented locally (2026-09-20):** application deployments no longer sync or
recreate shared Caddy. The `main`-only, production-approved shared-edge workflow
serializes edge updates without cancellation. Its apply script validates a staged
candidate before touching active files, reloads Caddy for Caddyfile-only changes,
and restores prior files after a failed reload. The isolated Docker-mock suite
passed invalid-candidate, reload, rollback, Compose-update, and first-setup cases.
Staging now probes production API liveness before and after its deployment.
Live staging deployment and production availability read-back remain to be
verified after the protected workflow change is merged; no edge or application
deployment was run for this local implementation.

**Host independence follow-up:** deployment environments explicitly select a
`shared`, `staging`, or `production` edge profile. Each host owns its own network,
proxy, and certificate volumes; an isolated profile contains no routes or web
mounts for the other environment. Only shared staging deployments probe
production availability. Profile changes require explicit production approval,
and application preflight checks the installed profile before transferring a
release. See [hosting setup](setup/hosting.md#host-edge-changes) for adoption and
future separation. Local regression/configuration validation does not establish
live separate-host acceptance; no host migration is performed by this change.

### 13. Make builds portable and promote identifiable artifacts

- [x] Prefer deployed frontend requests to the current origin's `/api` rather than
  hardcoded official hosts. Keep an explicit local development override.
- [x] Verify forks and self-hosted Release builds cannot accidentally call the
  official API. Do not introduce API subdomains without a concrete requirement.
- [x] Reduce duplicated endpoint/port configuration. Support parallel worktrees
  when practical; otherwise document the fixed-port limitation.
- [x] Build frontend and API artifacts once where practical and promote the
  tested pair. Address environment-specific frontend publishing before claiming
  that the same artifact is promoted unchanged.
- [x] Record image digests, frontend artifact identity, and source revision.
  Do not rely on a mutable commit-named image tag or version string alone.

**Acceptance:** the same tested release can be identified unambiguously and hosted
on an alternate hostname without rebuilding just to change its API hostname.

**Implemented locally (2026-09-20):** Release web builds use the hosting origin
and retain only a Development localhost override; staging and production no longer
publish different API URLs. The packaging job follows source validation and builds
the frontend archive once; after environment approval, deployment verifies that
archive, builds the API image once, and records its digest reference, the archive
checksum, and source revision on the host. Fixed development ports are documented
as a single-stack limitation. Local build/publish and workflow structure checks
validate the package contract; live deployment and alternate-host browser behavior
remain unverified until a controlled deployment. Staging and production workflow
runs still package separately; each run's manifest identifies its actual pair.

### 14. Make rollout atomic and rollback explicit

- [x] Replace in-place frontend `rsync --delete` with versioned release directories
  and an atomic activation step.
- [x] Retain the previous compatible frontend/API pair and document rollback.
  Account for clients still requesting assets from an older loaded page.
- [x] Extend smoke tests to verify the expected revision and a frontend-to-API
  interaction, not only `/api/alive` or Caddy's static `/health`.
- [x] Document failure recovery in `docs\setup\hosting.md` and `docs\release`,
  including a deploy succeeding before tag or follow-up PR creation fails.

**Acceptance:** rehearse deployment failure and rollback in staging. Recover the
previous working release without rebuilding it or guessing which image it used.

**Accepted in staging (2026-09-20):** [normal run 35542650898](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35542650898)
passed build/test, activation, and Chromium smoke against source revision
`14e7582d01059f0408be501504a5689e53a74f36`. The controlled
[rollback rehearsal 35542855238](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35542855238)
activated a new release, passed the same browser check, then failed on purpose.
Its recovery step restored release `35542650898-1-14e7582d0105` using the
recorded prior image digest without rebuilding. The rehearsal run is red by
design. Independent HTTPS checks afterward found the root page pointing to the
restored release, `/api/about` returning the expected revision, both versioned
web directories serving, and production `/api/alive` healthy. See the
[hosting recovery procedure](setup/hosting.md#application-activation-and-rollback)
and [release failure guidance](release/README.md#what-happens-on-failure).

### 15. Harden the existing hosting and supply chain

- [x] Pin Actions to reviewed commit SHAs and deployed container images to digests.
  Keep Dependabot/update automation capable of maintaining those pins.
- [ ] Verify the deployment SSH host key through a trusted channel and pin it,
  rather than trusting a fresh `ssh-keyscan` result during each deployment.
- [x] Run the API container as an explicit non-root user and verify permissions.
- [x] Configure trusted forwarded headers for Caddy before middleware relying on
  request scheme or client IP. Test HTTPS redirects; do not trust arbitrary proxies.
- [x] Recheck NuGet configuration inheritance on a clean machine. Explicitly clear
  inherited source mappings for the single-feed setup, or document and adopt
  reviewed source-specific mappings. Do not treat a global wildcard as namespace
  isolation between feeds.

**Acceptance:** image startup, proxy behavior, restore, dependency updates, and
deployment still work with the hardened configuration and least required privileges.

**Implemented locally (2026-09-21):** third-party Actions and base/edge images
are immutable while the existing Dependabot ecosystems remain enabled. A local
image build and runtime probe confirmed that the API starts with a nonzero UID,
can read its assembly, cannot write `/app`, and returns its liveness response; CI
repeats that probe. The API
trusts one forwarded hop only from the deployed `ogb-edge` network, with redirect
and spoofing coverage. An isolated empty-cache restore passes with inherited
package sources and mappings cleared. Deployment now requires a pinned
`DEPLOY_KNOWN_HOSTS` environment variable and never learns trust with
`ssh-keyscan`. Keep the SSH item and live acceptance open until an administrator
verifies and records the key through an existing trusted SSH connection or an
independent authenticated channel, configures both environments, CI passes, and
a merged staging deployment passes. Follow the
[host-key setup guide](setup/deployment-host-key.md) for commands and trust limits.

**Live application evidence (2026-09-22 UTC):** the
[staging retry](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35673447966/attempts/2)
and [production v0.10.0 release](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35674772060)
passed the image permission/liveness probe, strict pinned-host SSH connections,
activation, browser revision checks, and finalization. The automatic version
bump and [staging rollout of 0.11.0](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35675216560)
also passed. These prove that the configured pins work, not independently how
the administrator authenticated the original host key. Keep that trust-source
confirmation explicit. The running Caddy digest and native-service boot state
still need [host verification](setup/hosting.md#host-caddy-conflicts-and-read-only-verification);
application deployments do not apply edge-image changes.

## Phase 3: Prepare to welcome community contributors

### 16. Replace the placeholder README with a contributor front door

- [x] Describe what works today, the first milestone, non-goals, and project status.
- [x] Link working setup, contribution, testing, support, roadmap, and license
  information before emphasizing deployment badges.
- [x] Explain the distinction between this implementation, the archive repository,
  and the original MyGameBuilder; do not imply official continuation.

**Acceptance:** an unfamiliar contributor can identify a useful task and reach the
run instructions from the README without asking a maintainer.

**Verified locally (2026-09-21):** the README now describes the API/frontend
foundation and its current limitations, links directly to the run instructions,
and gives concrete setup, documentation, and regression-test contribution paths.
It points to section 9 for the still-unselected first engine milestone rather
than claiming a compatibility target has been accepted. Setup, contribution,
testing, support, roadmap, and license links precede workflow badges. Local link
targets and heading anchors were checked, current behavior was compared with
the source, and the public archive repository and enabled issue tracker were
confirmed through GitHub. This documentation review does not close section 3's
fresh-checkout editor verification or section 9's milestone decisions.

### 17. Make public support and issue intake usable

- [x] Make GitHub Discussions the discoverable default for exploratory questions.
  Keep the reunion Discord private if desired, but not a prerequisite for contributing.
- [x] Link directly to the authoritative organization-wide Code of Conduct and
  governance documents from `CONTRIBUTING.md` and `SUPPORT.md`.
- [x] Add question and private-security-reporting links to the issue chooser.
- [x] Use the existing project `Triage` status; remove stale `needs triage`
  label references from issue forms. Dependabot is already corrected. Remove
  the compatibility form's TODO option.
- [x] Simplify overlapping enhancement/feature forms if they do not help triage.
  Make the issue labels/types and contributor guidance agree.

**Acceptance:** a newcomer can ask a question, report a bug, propose a change,
and find private reporting instructions without access to private chat.

**Verified locally and against GitHub (2026-09-21):** Discussions (including Q&A
and Ideas), private vulnerability reporting, and the public Roadmap's `Triage`
status already exist. No settings or labels needed creating, and Dependabot
already omits the stale label. The four issue forms now omit it too. Bug,
Feature, and Enhancement match enabled organization issue types; the nonexistent
compatibility type is replaced with Bug while keeping its behavior/evidence form.
The unused TODO dropdown is removed. Enhancement and Feature remain separate
because both types exist and the forms distinguish existing and new capabilities.
Support, contribution guidance, and issue-chooser links now lead to public
questions, concrete reports/proposals, and private security reporting. Broken
local policy links now point to the verified organization-wide documents.
YAML, configured types, and documentation links were checked locally; the hosted
chooser will reflect these changes after merge. No test issues or reports were
submitted, and project automation was not changed.

### 18. Create a small, genuinely actionable contributor backlog

- [ ] Prepare a few `good first issue` and `help wanted` tasks with acceptance
  criteria, likely files, validation steps, and a willing maintainer contact.
- [ ] Include non-code opportunities such as accessibility testing, documentation,
  independently written behavior examples, and UI feedback.
- [ ] Record consequential decisions in public issues, discussions, or short
  architecture notes rather than only in Discord.

**Acceptance:** someone new can take a bounded task without first designing a
database layer, deployment system, or entire engine.

### 19. Consolidate documentation and define browser expectations

- [x] Remove empty Markdown placeholders or turn the intended work into issues.
  Keep only useful setup, architecture, testing, hosting, and compatibility documents.
- [x] Add a concise documentation index and repair broken local links.
- [x] Correct stale claims, including the statement that health checks are absent.
  Move general learning resources to the shared location planned by the project,
  retaining useful links rather than duplicating a reference library.
- [x] Fill `docs\frontend\browser-support.md` with a tested support policy.
  Explain that `.browserslistrc` alone neither implements nor verifies compatibility.
- [x] Include keyboard operation, focus, accessible loading/errors, and a concrete
  supported-browser smoke matrix for the editor as it develops.

**Acceptance:** referenced documents contain real instructions; local links resolve;
the claimed browser/accessibility baseline has recorded checks.

**Verified (2026-09-22 UTC):** removed 23 empty placeholders and filled the API
and browser guides. The [documentation index](README.md) links current operating
instructions, the repository map, and compatibility boundaries. Five substantive
learning-resource pages moved to the organization's `.github` repository in
[draft PR #1](https://github.com/OpenGameBuilder/.github/pull/1), retaining all 211
original external link targets and replacing broken local references. The index
links the published shared commit so it works before merge; issue
[#56](https://github.com/OpenGameBuilder/opengamebuilder/issues/56) remains open
pending the cross-repository review and merge. The API guide documents existing
health checks, and testing guidance now distinguishes the existing Chromium
deployment smoke from section 6's future component and failure-state coverage.

The browser guide records the successful Chromium smoke from staging run
[35681727268](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35681727268)
and source-inspected accessibility gaps. Other browsers, keyboard, focus, screen
readers, and physical mobile devices remain explicitly unverified; their concrete
acceptance matrix accompanies the first functional frontend feature in section 6.
This is not an editor or accessibility-conformance acceptance. Markdown paths,
heading anchors, nonempty documents, preserved resource links, and whitespace
were checked. No new services or browser sessions were started, and section 18
was left unchanged.

### 20. Finish AI tooling maintenance and simplify policy

- [x] Record vendored skills' upstream source/revision, applicable licenses and
  attribution, update/regeneration procedure, and local-edit policy.
- [x] Trim unused skill coverage where useful, or explicitly distinguish generic
  cloud/deployment capabilities from approved repository workflows.
- [x] Shorten repetitive sections of `AI_POLICY.md` without weakening human
  accountability, disclosure, privacy, or proprietary-material restrictions.
- [x] If using cloud coding agents, add a minimal reproducible setup workflow and
  validate it on their actual runner. Keep production secrets out of that environment.
  Otherwise record cloud-agent setup as not applicable.

**Acceptance:** local and any supported cloud agents use the same documented
checks. A maintainer can update the skills deliberately, with provenance preserved.

**Verified (2026-09-22 UTC):** [AI tooling maintenance](setup/ai-tooling.md)
records matching immutable source revisions for all 37 vendored files, the
embedded Aspire bundle checksum, dotnet-inspect attribution, complete MIT notices,
and reproduction/update and local-patch procedures. A clean upstream checkout
matched all six Aspire skill trees; the extracted dotnet-inspect source matched
its recorded SHA-256. The vendored files themselves are unchanged. Generic cloud
and deployment coverage is explicitly separate from this repository's approved
Compose workflow and authorization boundaries. `AI_POLICY.md` was reduced from
307 to 119 lines while preserving accountability, disclosure, privacy, licensing,
and proprietary-source restrictions; its linked source-material heading remains.
The maintainer confirmed local agents only, so cloud setup and runner validation
are not applicable. Local links, license contents, and whitespace checks passed;
no services, cloud environment, or new application tests were needed.

### 21. Establish practical stewardship and project continuity

- [ ] Keep lightweight governance, but identify a backup maintainer and document
  repository, hosting, domain, release, and recovery responsibilities.
- [ ] Provide an alternate private reporting route for concerns involving the
  primary contact. Confirm private vulnerability reporting remains enabled.
- [x] Add `CODEOWNERS` when real area owners exist; do not create fictional ownership
  or an approval requirement nobody can satisfy.
- [x] Document rights/provenance checks for historical games, submissions, assets,
  and fixtures: source, permitted use, attribution, privacy review, creator requests,
  and removal handling. Do not imply Apache-2.0 grants rights to original material.
- [x] Keep archive ownership separate and use independently created fixtures for
  implementation tests.

**Acceptance:** contributors know who decides and who can help; someone other than
the primary maintainer has an agreed recovery role; material is not imported merely
because it is technically accessible.

**Practical work completed (2026-09-22 UTC):** [stewardship](community/stewardship.md)
records current responsibilities, material-intake checks, creator/removal handling,
and the separate archive boundary. Private vulnerability reporting was confirmed
enabled. No real area owners are assigned, so `CODEOWNERS` is not applicable yet.
The stale statement that rollback had never been rehearsed is corrected.

**Deferred:** the first two items remain incomplete because no agreed backup
operator or independent private contact is recorded. Owner: `ostomachion`.
Trigger: before wider participation or an operational handoff, obtain a willing
delegate's agreement, record responsibilities and a private reporting route,
verify necessary repository/hosting/domain access, and rehearse recovery. A
read-only collaborator is not a substitute for an agreed role. Full continuity
acceptance is not claimed; local documentation links and whitespace were checked.

## Final gate: open the project to wider participation

- [ ] Phases 2 and 3 are complete, or genuinely inapplicable items have an explicit
  explanation and owner for any future trigger.
- [ ] The scoped engine milestone from step 9 works with independently created data.
- [ ] A person unfamiliar with the repo successfully follows setup and completes a
  small contribution through the actual review/check process.
- [ ] Public deployment has a rehearsed recovery path and community reporting works.

Stop foundation work here. Do not add microservices, generic repositories, mediator
pipelines, event buses, Kubernetes, a large committee structure, or a coverage target
merely to look mature. Improve these foundations further when engine or community
work demonstrates a specific need.
