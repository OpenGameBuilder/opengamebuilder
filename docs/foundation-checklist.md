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

- [x] Write a short architecture/repository map: API, contracts, API client,
  frontend, AppHost, service defaults, and the separate archive repository.
- [x] Choose the first compatibility goal and its non-goals: playback, import,
  editor behavior, or one narrowly defined combination.
- [x] Define a small, independently created fixture and observable acceptance
  criteria for the first engine milestone.
- [x] Keep game logic testable without Blazor, HTTP, or a database. Introduce
  boundaries for rendering, input, time, and randomness with actual engine work,
  not as empty projects or generic infrastructure.

**Acceptance:** the next engine task is small enough to implement and test without
first adding a new architectural framework.

**Verified (2026-09-19):** [the first engine milestone](architecture/first-engine-milestone.md)
selects deterministic, headless playback of a single independently authored scene
timeline. Its canonical [v1 fixture](../test-data/engine/first-playback-scene.v1.json)
has a five-row observable trace, terminal behavior, and invalid-input criteria.
The selected next task introduces an engine project only alongside the player and
its direct tests; it explicitly excludes the framework and host concerns that do
not yet have a behavior to serve.

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

- [ ] Audit environment branch/tag restrictions against the actual workflow.
  Distinguish the branch dispatching the workflow from the source SHA it checks out;
  do not blindly replace every environment selector with `patch/*`.
- [ ] Verify production approval, release-bot permissions, protected-tag creation,
  and narrowly scoped environment secrets.
- [ ] Record who can deploy and recover a release in `docs\setup\github.md`.

**Acceptance:** approved standard and patch workflows are allowed, unintended
dispatch paths are rejected, and normal pull-request validation receives no
production credentials.

**Progress (2026-09-19):** authenticated read-back found production approval by
`ostomachion`, self-review and administrator bypass enabled, environment-scoped
deployment secrets, repository-scoped release-bot tokens, and creation-only bot
tag permission. The stale production `release/**/*` tag selector and staging
`release/**/*` branch selector were removed; both environments now allow only
the `main` dispatch branch. Both local CD workflows now reject non-`main`
dispatches before source selection, and their deployment calls no longer inherit
the repository's release-bot secret. [GitHub setup](setup/github.md#deployment-authority-and-recovery)
records the dispatch/source distinction, actual operator and recovery limits,
and the read-only permission audit. No deployment was run. **Keep this section
open:** remote `main` still has the older deployment workflow and lacks this
checkout's protected-source resolver, so its input-ref rejection has not yet
reached the live workflow. A signed-in organization Actions settings read-back
on 2026-09-20 found no organization secrets; the audit CLI token still received
403 for the same API inventory. Publish the local workflow baseline, verify the
live source gate, and check these items off only then.
Administrator bypass is retained for sole-operator emergency recovery, not
routine releases; while enabled, the `main`-only selector is not an absolute
barrier to an administrator forcing a waiting job.

### 12. Isolate shared-edge changes from application deployments

- [ ] Stop routine staging/application deployments from recreating the shared
  production Caddy service.
- [ ] Validate a candidate Caddy configuration before activating it; use a
  graceful reload when configuration changes.
- [ ] Coordinate operations that modify shared edge files or services across
  staging and production. Avoid cancelling an in-flight mutation midway through.

**Acceptance:** deploy staging while checking production availability. An invalid
candidate edge configuration is rejected without replacing the working configuration.

### 13. Make builds portable and promote identifiable artifacts

- [ ] Prefer deployed frontend requests to the current origin's `/api` rather than
  hardcoded official hosts. Keep an explicit local development override.
- [ ] Verify forks and self-hosted Release builds cannot accidentally call the
  official API. Do not introduce API subdomains without a concrete requirement.
- [ ] Reduce duplicated endpoint/port configuration. Support parallel worktrees
  when practical; otherwise document the fixed-port limitation.
- [ ] Build frontend and API artifacts once where practical and promote the
  tested pair. Address environment-specific frontend publishing before claiming
  that the same artifact is promoted unchanged.
- [ ] Record image digests, frontend artifact identity, and source revision.
  Do not rely on a mutable commit-named image tag or version string alone.

**Acceptance:** the same tested release can be identified unambiguously and hosted
on an alternate hostname without rebuilding just to change its API hostname.

### 14. Make rollout atomic and rollback explicit

- [ ] Replace in-place frontend `rsync --delete` with versioned release directories
  and an atomic activation step.
- [ ] Retain the previous compatible frontend/API pair and document rollback.
  Account for clients still requesting assets from an older loaded page.
- [ ] Extend smoke tests to verify the expected revision and a frontend-to-API
  interaction, not only `/api/alive` or Caddy's static `/health`.
- [ ] Document failure recovery in `docs\setup\hosting.md` and `docs\release`,
  including a deploy succeeding before tag or follow-up PR creation fails.

**Acceptance:** rehearse deployment failure and rollback in staging. Recover the
previous working release without rebuilding it or guessing which image it used.

### 15. Harden the existing hosting and supply chain

- [ ] Pin Actions to reviewed commit SHAs and deployed container images to digests.
  Keep Dependabot/update automation capable of maintaining those pins.
- [ ] Verify the deployment SSH host key through a trusted channel and pin it,
  rather than trusting a fresh `ssh-keyscan` result during each deployment.
- [ ] Run the API container as an explicit non-root user and verify permissions.
- [ ] Configure trusted forwarded headers for Caddy before middleware relying on
  request scheme or client IP. Test HTTPS redirects; do not trust arbitrary proxies.
- [ ] Recheck NuGet configuration inheritance on a clean machine. Explicitly clear
  inherited source mappings for the single-feed setup, or document and adopt
  reviewed source-specific mappings. Do not treat a global wildcard as namespace
  isolation between feeds.

**Acceptance:** image startup, proxy behavior, restore, dependency updates, and
deployment still work with the hardened configuration and least required privileges.

## Phase 3: Prepare to welcome community contributors

### 16. Replace the placeholder README with a contributor front door

- [ ] Describe what works today, the first milestone, non-goals, and project status.
- [ ] Link working setup, contribution, testing, support, roadmap, and license
  information before emphasizing deployment badges.
- [ ] Explain the distinction between this implementation, the archive repository,
  and the original MyGameBuilder; do not imply official continuation.

**Acceptance:** an unfamiliar contributor can identify a useful task and reach the
run instructions from the README without asking a maintainer.

### 17. Make public support and issue intake usable

- [ ] Make GitHub Discussions the discoverable default for exploratory questions.
  Keep the reunion Discord private if desired, but not a prerequisite for contributing.
- [ ] Link directly to the authoritative organization-wide Code of Conduct and
  governance documents from `CONTRIBUTING.md` and `SUPPORT.md`.
- [ ] Add question and private-security-reporting links to the issue chooser.
- [ ] Create or replace the missing `needs triage` label used by templates and
  Dependabot. Remove the compatibility form's TODO option.
- [ ] Simplify overlapping enhancement/feature forms if they do not help triage.
  Make the issue labels/types and contributor guidance agree.

**Acceptance:** a newcomer can ask a question, report a bug, propose a change,
and find private reporting instructions without access to private chat.

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

- [ ] Remove empty Markdown placeholders or turn the intended work into issues.
  Keep only useful setup, architecture, testing, hosting, and compatibility documents.
- [ ] Add a concise documentation index and repair broken local links.
- [ ] Correct stale claims, including the statement that health checks are absent.
  Move general learning resources to the shared location planned by the project,
  retaining useful links rather than duplicating a reference library.
- [ ] Fill `docs\frontend\browser-support.md` with a tested support policy.
  Explain that `.browserslistrc` alone neither implements nor verifies compatibility.
- [ ] Include keyboard operation, focus, accessible loading/errors, and a concrete
  supported-browser smoke matrix for the editor as it develops.

**Acceptance:** referenced documents contain real instructions; local links resolve;
the claimed browser/accessibility baseline has recorded checks.

### 20. Finish AI tooling maintenance and simplify policy

- [ ] Record vendored skills' upstream source/revision, applicable licenses and
  attribution, update/regeneration procedure, and local-edit policy.
- [ ] Trim unused skill coverage where useful, or explicitly distinguish generic
  cloud/deployment capabilities from approved repository workflows.
- [ ] Shorten repetitive sections of `AI_POLICY.md` without weakening human
  accountability, disclosure, privacy, or proprietary-material restrictions.
- [ ] If using cloud coding agents, add a minimal reproducible setup workflow and
  validate it on their actual runner. Keep production secrets out of that environment.
  Otherwise record cloud-agent setup as not applicable.

**Acceptance:** local and any supported cloud agents use the same documented
checks. A maintainer can update the skills deliberately, with provenance preserved.

### 21. Establish practical stewardship and project continuity

- [ ] Keep lightweight governance, but identify a backup maintainer and document
  repository, hosting, domain, release, and recovery responsibilities.
- [ ] Provide an alternate private reporting route for concerns involving the
  primary contact. Confirm private vulnerability reporting remains enabled.
- [ ] Add `CODEOWNERS` when real area owners exist; do not create fictional ownership
  or an approval requirement nobody can satisfy.
- [ ] Document rights/provenance checks for historical games, submissions, assets,
  and fixtures: source, permitted use, attribution, privacy review, creator requests,
  and removal handling. Do not imply Apache-2.0 grants rights to original material.
- [ ] Keep archive ownership separate and use independently created fixtures for
  implementation tests.

**Acceptance:** contributors know who decides and who can help; someone other than
the primary maintainer has an agreed recovery role; material is not imported merely
because it is technically accessible.

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
