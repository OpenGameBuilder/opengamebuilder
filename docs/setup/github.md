# GitHub Setup

This guide describes the intended workflow code in this checkout and separately
records live GitHub settings. At the 2026-09-19 audit, remote `main` was still
`f40de883662f2fbe35859879f772b5a9f329256d`; this checkout's newer
protected-source workflow and validation action had not been published. Do not
assume a local workflow change is active on GitHub until it is merged.

## CI merge gate

The required pull-request check is **`build-test`**, produced by GitHub Actions
(app ID `15368`) in [CI](../../.github/workflows/ci.yml). Keep that job name stable.
CodeQL, code quality, and automated review supplement it; none runs the behavior
tests in its place.

CI runs on every pull request, without path filters, and on pushes to `patch/v*`.
The [shared validation action](../../.github/actions/validate/action.yml) runs
restore, formatting verification, a Release solution build (including AppHost),
and all tests. Both CI and [deployment validation](../../.github/workflows/_deploy.yml)
use this action. Deployment requires its validation job to succeed before entering
the environment job. CI additionally builds the API container without pushing it.
No deployment credentials are supplied to pull-request CI; the deployment
validation job also has a read-only repository token.

Before executing release scripts or deployment validation,
[protected-source resolution](../../.github/workflows/_resolve-source.yml) accepts
only `main` or `patch/vX.Y.Z`, requires GitHub to report the branch as protected,
and resolves its immutable commit through the API. Tags, arbitrary SHAs, and
unprotected branches are not deployment inputs. Validation and deployment check
out that resolved SHA, not unchecked dispatch input. If the branch moves after
source selection, the workflow fails explicitly; start a new run rather than
silently deploying a different commit.

The validation action definition is loaded from `github.workflow_sha` before
source checkout. That trusted action checks out the resolved deployment source
into a separate directory and runs the shared checks there. This keeps executable
pipeline definitions separate from the selected application's files.
Third-party Actions in workflows and in the local composite validation action
are pinned to reviewed commit SHAs with adjacent release comments. Separate
Dependabot entries cover `.github/workflows` and `.github/actions/validate`, so
both sets continue to receive reviewable version-update PRs.

Validation commands use explicit Bash shells, whose `-e -o pipefail` behavior
keeps a failing command from being hidden by `tee`. Failures upload the available
restore, formatting, build, and test console logs, plus the formatter's JSON
report, as `ci-validation`, `staging-validation`, or `production-validation`.
Each name includes the run-attempt suffix so reruns do not collide.
Artifacts expire after seven days. These are diagnostic logs, not TRX reports;
test failures and stack traces are in `test.log`. A cancellation, runner loss, or
job timeout can prevent the upload, so also consult the Actions job log.
Do not log credentials or sensitive response bodies.

Every runner job has an explicit timeout: CI and CodeQL 30 minutes, deployment
validation 20, deployment 30, smoke tests 5, and release-script jobs 10. Reusable
source-resolution jobs have a 5-minute timeout. Reusable
workflow callers use the timeouts on their called jobs. These are upper bounds,
not targets. Do not add `continue-on-error`, conditional skipping, or path filters
to the required job.

## Live protection

Authenticated administrator inspection and read-back on **2026-09-15** verified
the following active repository rulesets. Branch rules target **`main` and
`patch/v*`**; tag rules target **`v*`**. There are no legacy branch-protection
rules: the GraphQL collection was empty, and the authenticated `main` protection
endpoint returned "Branch not protected" (404). Rulesets still protect that branch.

| Ruleset | Requirements | Bypass |
| --- | --- | --- |
| [Main and patch merge gate (16765458)](https://github.com/OpenGameBuilder/opengamebuilder/rules/16765458) | `build-test` from GitHub Actions (`15368`), up-to-date branches, CodeQL, code quality, no deletion or force push | None, including administrators and the release bot |
| [Main linear history (23469610)](https://github.com/OpenGameBuilder/opengamebuilder/rules/23469610) | Linear history on `main` | None |
| [Main and patch human review (23468686)](https://github.com/OpenGameBuilder/opengamebuilder/rules/23468686) | One approval, stale-review dismissal, latest-push approval, resolved conversations, squash-only merges | Organization administrators, **PR-only**, as explained below |
| [Protected branch creation (23468683)](https://github.com/OpenGameBuilder/opengamebuilder/rules/23468683) | Restrict creation of protected branches | Release App, always mode, **creation only** |
| [Release tag creation (23468685)](https://github.com/OpenGameBuilder/opengamebuilder/rules/23468685) | Restrict creation of release tags | Release App, always mode, **creation only** |
| [Release tag immutability (16754313)](https://github.com/OpenGameBuilder/opengamebuilder/rules/16754313) | No tag updates, deletion, or force pushes | None, including administrators and the release bot |

The review rule also requires an extra approval for unattributed Copilot PRs.
Automated review is not human approval. No code-owner requirement is configured
without real owners. CodeQL blocks high-or-higher security alerts and other errors;
code quality blocks errors. The merge-gate ruleset also requests Copilot review.
The separate Copilot ruleset `19404460` is disabled and supplies no protection.

Required status checks are not enforced on **branch creation**: the release bot
must be able to create a patch branch at an existing released commit. Subsequent
updates receive the full PR/check gate. Do not enable a merge queue without
adding `merge_group` workflow triggers.

Patch branches must preserve their released base verbatim, including historical
merge commits. The separate linear-history rule therefore targets only `main`.
New PR merges remain squash-only on both branch families, enforced by repository
merge-method settings and the review rule. Do not rewrite a released history
or give the bot a general CI bypass just to create a patch branch.

### Deliberate maintainer exception

`ostomachion` is the only organization owner and only collaborator with write
access at verification time. Requiring a second eligible reviewer on that
maintainer's own PRs would deadlock routine development. Organization
administrators therefore retain a **pull-request-only bypass of the review
ruleset**, not of the merge gate. This is a deliberate sole-maintainer exception,
not a claim that the maintainer supplied an independent human approval.

Ordinary contributor and bot PRs require human review. New commits dismiss stale
approvals and require approval of the latest reviewable push. The maintainer may
merge their own PR without independent review only through the documented
exception; **failing CI, CodeQL, and code quality still block that merge**.
The exception does not permit direct pushes, deletion, or force pushes.

Remove this review bypass once a second trusted reviewer has write access and
can routinely review maintainer-authored PRs. Recheck the exception whenever
organization ownership changes. Do not grant repository access merely to make
a verification exercise pass.

### Release bot permissions

The installed `opengamebuilder-release-bot` App has ID **`3815756`**, verified
against the public App record, organization installation, and
`RELEASE_BOT_CLIENT_ID`. Its approved installation permissions are repository
contents write, pull requests write, workflows write, and metadata read.

The release scripts create a patch branch from a released tag, push unprotected
`chore/*` branches, and open preparation, version-bump, and merge-back PRs. The
creation-only rules permit this with the approved App permissions,
without granting permission to bypass checks, review its own PRs, directly update
protected branches, or overwrite release tags.
Do not add the bot to the merge-gate, review, or tag-immutability bypass lists.
PR validation never receives the short-lived release App token.

A bypass applies to its **entire ruleset**, which is why creation and immutability
are separate. Administrator ability to edit rules is not a standing bypass.
If emergency recovery needs a temporary rule change, record the reason, actor,
exact ref, and restoration in a public issue without credentials. Environment
approvals and release-token scope are audited below.

### Workflow-file permission

Workflows write is needed even to create a branch containing an existing release's
workflow-file history. The native Git preparation
[run 34997049849](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/34997049849)
and [reference-only API probe](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/34997318737)
both failed without it. Owner `ostomachion` approved the permission on 2026-09-15,
and authenticated installation read-back and the successful preparation below
confirmed it is active. No key rotation or token sharing was needed.

Both token-creation steps explicitly request `permission-workflows: write`, so
insufficient installation permissions fail at token creation rather than halfway
through a release. The action's default token scope is this repository; PR CI
never receives these permissions. Do not restore a broad ruleset bypass to try
to fix an App permission failure.

For future installation changes, update the
[App permissions](https://github.com/organizations/OpenGameBuilder/settings/apps/opengamebuilder-release-bot/permissions)
and approve them in the
[installation settings](https://github.com/organizations/OpenGameBuilder/settings/installations/134728813).
The installation currently selects all repositories, but the workflow does not
set the action's `owner` or `repositories` inputs, so each short-lived token is
scoped to this repository. Restrict the installation itself to selected
repositories if organization-wide installation is no longer needed; that is a
separate administrator setting, not a reason to broaden workflow tokens.

## Deployment authority and recovery

Authenticated read-back on **2026-09-19** found that both `production` and
`staging` select only the **`main` branch** for deployment. The obsolete
`release/**/*` tag rule on production and `release/**/*` branch rule on staging
were removed; neither belongs to the current process. GitHub matches an
environment's deployment rule against the workflow run's `GITHUB_REF`, not the
commit checked out inside a job. For both release kinds, dispatch **CD
Production** with the branch picker on `main`: the `ref` input chooses `main`
or a protected `patch/vX.Y.Z` source commit. Do not add `patch/*` to the
environment merely because a patch commit is deployed. Both published CD workflows
also fail immediately when the dispatch ref is not `main`, before resolving a
source or entering a deployment environment. [GitHub's environment
rule reference](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments#deployment-branches-and-tags)
explains this distinction.

| Workflow run ref | Source input | Environment result without admin bypass | Source check on merged `main` |
| --- | --- | --- | --- |
| `main` | `main` | Production allowed, then reviewer approval | Protected `main` SHA |
| `main` | `patch/vX.Y.Z` | Production allowed, then reviewer approval | Protected matching patch SHA |
| `patch/vX.Y.Z` or a tag | Any | Workflow guard fails; production also denies | Not run |
| `main` | Tag, arbitrary SHA, or unprotected branch | Environment permits the dispatch ref | Source resolver rejects the input |

Staging runs on a push to `main` or a manual dispatch from `main`; other
dispatch refs are denied by its environment policy in the normal path. On
2026-09-20, `main` at `93666e325c8c3bf02e9a5fbdbdffa4b7097198c9`
contained the guards and source resolver; they remained in the merged fix at
`65cf767afd587ce5ea72368df8d888c69bd0a7e7`. A
[deliberately invalid production dispatch](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531224662)
from `main` with a tag as the source input failed in the resolver; validation,
deployment, and release jobs were skipped. A
[non-`main` dispatch](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531484408)
from the fix branch failed at the first guard, with all downstream jobs skipped.
Neither run tested an approved production release.
The [merge-triggered staging run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531733842)
at that commit passed protected-source resolution, validation, deployment, and
the API liveness smoke test. It verifies the corrected secret handoff and the
staging path, not production approval or a standard/patch release.

The production environment has one required reviewer, `ostomachion`.
Self-approval is allowed because there is no second eligible release reviewer;
administrator bypass is also enabled. **Decision (2026-09-19): retain bypass
for emergency recovery while there is only one release operator.** It is not
the routine approval path and does not count as independent review. The only
human collaborator with write access at read-back was `ostomachion`;
`justinhufford` had read access only.
Someone with repository write access can dispatch a manual workflow, but the
deployment job waits for the configured reviewer (or an administrator's explicit
bypass). [GitHub's deployment review guide](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/review-deployments)
describes approval and bypass. Do not use bypass for a routine release; record
any emergency bypass, its reason, and the affected run. Because bypass can force
waiting jobs, `main`-only is not an absolute restriction against an administrator.
Revisit self-review and bypass when a second trusted release operator exists.

Each environment holds only its own `DEPLOY_HOST`, `DEPLOY_USER`, and
`DEPLOY_SSH_KEY` secrets, plus `DEPLOY_KNOWN_HOSTS` and `EDGE_PROFILE` environment
variables. The hosts and accounts may be the same or different. Set `EDGE_PROFILE`
explicitly: `shared` in both environments for a shared server, or `staging` and
`production` respectively for separate servers. There is no default. The edge
workflow selects the environment whose credentials to use; a shared edge or
profile migration requires production approval. See
[host profiles and migration](hosting.md#host-edge-changes).
`DEPLOY_KNOWN_HOSTS` contains the complete OpenSSH `known_hosts` entry for that
environment's `DEPLOY_HOST`; the public host key is configuration, not a secret.
Follow the [deployment host-key guide](deployment-host-key.md) to read the public
key through an existing SSH connection that strictly checks a saved, trusted
server key, construct the entry, set the selected environment's host-key variable,
and read it back. Repeat for the other environment and its host. This carries
forward the administrator's existing trust decision; it is
not independent verification of an unverified first connection. A provider
console or another authenticated independent channel is needed when the saved
key is missing, changed without explanation, or untrusted. Do not populate the
variable from an unverified `ssh-keyscan` result. During rotation, authenticate
the replacement before changing the variable. The workflow
requires an exact host match, enables strict host-key checking, and prints the
pinned fingerprint to the job log without printing private credentials.

The `RELEASE_BOT_PRIVATE_KEY` is a repository secret
because **Prepare Patch** needs the App before any deployment environment is
entered; the client ID and smoke-test URLs are repository variables. Deployment
callers use `secrets: inherit`: the
[merged staging run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35531071912)
showed that omitting this handoff left the selected environment's `DEPLOY_HOST`
and `DEPLOY_SSH_KEY` empty inside the reusable deployment workflow, despite their
configured names. It failed at SSH setup after publishing an image, before
syncing files or restarting services. The workflow checks the three deployment
secrets and the pinned host-key variable for presence in the environment job
before publishing an image; it never logs secret values. The successful staging
run above passed the earlier three-secret check,
SSH setup, file sync, service restart, and the smoke test. Inheritance also makes
the repository-scoped `RELEASE_BOT_PRIVATE_KEY` available to the trusted
reusable workflow's secret context, although no deployment step references it.
Keep the reusable workflow definition trusted and the bot key out of
scripts/checkout. Revisit isolation if release credentials move to a separate
approval boundary. Only the deployment call receives `packages: write`;
validation has `contents: read`, and the smoke test has no token permissions.
The App installation has contents, pull requests, and workflows write plus metadata
read; its creation-only branch/tag bypasses and the no-bypass tag-immutability
rule are recorded above. The token-creation action requests these permissions
explicitly and defaults to this repository, despite the broader installation.
Normal PR CI has a read-only `GITHUB_TOKEN`, references no deployment environment
and no release-bot secret, and therefore receives no deployment credentials.
GitHub makes environment secrets available only after that environment's rules
pass. On 2026-09-20, the signed-in organization Actions secrets settings page
explicitly reported that OpenGameBuilder has no organization secrets. This was
a read-only UI metadata check; no secret values were viewed. The audit CLI
token still receives 403 for the organization secret API inventory.

Read back these settings without revealing secret values:

```pwsh
gh api repos/OpenGameBuilder/opengamebuilder/environments/production
gh api repos/OpenGameBuilder/opengamebuilder/environments/production/deployment-branch-policies
gh api repos/OpenGameBuilder/opengamebuilder/environments/staging/deployment-branch-policies
gh api repos/OpenGameBuilder/opengamebuilder/environments/production/secrets --jq '.secrets[].name'
gh api repos/OpenGameBuilder/opengamebuilder/environments/staging/secrets --jq '.secrets[].name'
gh api repos/OpenGameBuilder/opengamebuilder/actions/secrets --jq '.secrets[].name'
gh api orgs/OpenGameBuilder/installations --jq '.installations[] | select(.app_id == 3815756) | {repository_selection, permissions}'
```

Today `ostomachion` is the only human who can both initiate and approve a
production release and handle recovery. If deployment fails before publishing,
fix the cause and rerun from `main` with the intended protected source branch.
If deployment succeeded but tagging, GitHub Release creation, or the follow-up
PR failed, keep that source branch at the same commit and follow the
[release rerun guidance](../release/README.md#what-happens-on-failure).
The bot may create the tag, Release, and follow-up PR after deployment; it
cannot approve its own PR, bypass CI, move a release tag, or recover the server.
There is no agreed backup operator; see [practical stewardship](../community/stewardship.md).
Artifact rollback was rehearsed in staging as recorded in
[foundation section 14](../foundation-checklist.md#14-make-rollout-atomic-and-rollback-explicit).
That evidence does not establish a second operator's access or recovery readiness.

## Acceptance evidence

The validation baseline is published in
[PR #82](https://github.com/OpenGameBuilder/opengamebuilder/pull/82). Its temporary
companion [patch PR #83](https://github.com/OpenGameBuilder/opengamebuilder/pull/83)
was closed without merging after verification. The disposable target
`patch/v0.0.0-ci-gate-check` was deleted; it was never a release to deploy or tag.
The original developer worktree and staged changes remain untouched by the
isolated verification commits.

Local verification used SDK `10.0.401` and Git for Windows Bash with the runner's
fail-fast/pipefail options. Restore, formatting verification, Release build, and
all **62 tests** passed (none skipped); Visual Studio build also passed. The known
ASPIRE010 warning remains. All four simulated failing `dotnet` pipelines retained
their nonzero exit codes and captured logs. Workflow structure, wiring, branch
patterns, timeouts, and documentation links were checked.

At head `7b9b1e54f070abb3cda809e3c33c5280273dfaa5`, both PRs reported `BLOCKED`,
and `gh pr checks --required` identified the failing `build-test` check.

| Target | Deliberately failing CI run | Result |
| --- | --- | --- |
| `main` (PR #82) | [34996043271](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/34996043271) | 62 passed, 1 deliberate assertion failed; merge blocked |
| `patch/v*` (PR #83) | [34996046998](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/34996046998) | 62 passed, 1 deliberate assertion failed; merge blocked |

Both runs passed restore, formatting, and build, and uploaded `ci-validation-1`
with the failing assertion and stack trace in `test.log`. Both CodeQL Advanced
language jobs ran for both targets. The aggregate CodeQL gate also correctly
caught a cache-poisoning risk from executing the shared action at an unchecked
deployment ref. Protected-source resolution addresses that trust boundary rather
than suppressing the alert. Its exact shell was checked with nine allowed,
rejected, moved-ref, unprotected-ref, and malformed-response cases, plus a real
read-only lookup of protected `main`.

After removing the deliberate test and completing trusted action/source
separation, head `ad8f7d7223a2908e48a828d85b74e78d01dab401` passed:

| Target | Passing CI run | Result |
| --- | --- | --- |
| `main` (PR #82) | [34998082400](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/34998082400) | All 62 tests passed; Docker image built without pushing |
| `patch/v*` (PR #83) | [34998087065](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/34998087065) | All 62 tests passed; Docker image built without pushing |

Both CodeQL Advanced language analyses and the managed code-quality analysis
passed. The [aggregate CodeQL check](https://github.com/OpenGameBuilder/opengamebuilder/runs/104479502143)
passed with zero annotations, and both PR merge refs had zero open code-scanning
alerts. No alert was dismissed and no security query was disabled. The shared
action was also executed locally against a separate source worktree: all 62
tests passed and all five diagnostic files appeared in that source directory.

The authenticated review rule verifies the approval count, stale-review dismissal,
latest-push approval, and the documented sole-maintainer exception. No fake human
approval was submitted. Resolve genuine review findings before merging; a green
test/scan check is not approval to bypass outstanding review conversations.

Cleanup temporarily excluded only the disposable patch ref from ruleset
`16765458` to allow deletion. Immediate read-back confirmed that the exclusion
list was restored to empty, with no bypass actors. The separate disposable bot
probe branch was also deleted. `main` and all existing release tags were unchanged;
no PR was merged and no deployment or release was performed.

### Successful release-bot acceptance

[Prepare Patch run 35002126742](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35002126742)
used the approved App token and completed successfully. It created:

- `patch/v0.9.1` at the existing `v0.9.0` commit
  `4fc9f816443eb6011958d6c6d43d64c82d9bfad3`, preserving its historical merges.
- `chore/prepare-v0.9.1` at `6167c2bc2a801b525ff8bf502d52121c80cd04a9`.
- Bot-authored [PR #84](https://github.com/OpenGameBuilder/opengamebuilder/pull/84),
  changing only `VersionPrefix` from `0.9.0` to `0.9.1`.

The PR reported `REVIEW_REQUIRED` and `BLOCKED`, with `build-test` still required.
[Its CI run](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35002166207)
failed restore with NU1903 for the old release's `Microsoft.OpenApi` 2.0.0
([advisory](https://github.com/advisories/GHSA-v5pm-xwqc-g5wc)).
That is the gate correctly rejecting an old dependency baseline, not a bot
permission failure. The current dependency/test baseline's green main and patch
runs are recorded above. Real patch preparation from older tags must receive the
current dependency and validation baseline before merging; do not disable Audit
or required checks to make an old release green.

PR #84 was closed without merging and both refs created by this run were deleted.
Only the exact verification patch ref was temporarily excluded for deletion;
read-back confirmed the exclusion was removed and the gate has no bypass actors.
The successful creation/PR operation, enforced review/check requirements, and
unchanged tag-immutability rules complete section 7's bot acceptance. No human
approval was fabricated and no deployment, tag change, or release was performed.

## Administrator verification

Use an authenticated administrator session; do not put tokens in the repository.
These read-only commands complement the settings UI:

```pwsh
gh auth status
gh api repos/OpenGameBuilder/opengamebuilder/rulesets --paginate
gh api repos/OpenGameBuilder/opengamebuilder/rulesets/16765458
gh api repos/OpenGameBuilder/opengamebuilder/rulesets/16754313
gh api repos/OpenGameBuilder/opengamebuilder/rulesets/23468683
gh api repos/OpenGameBuilder/opengamebuilder/rulesets/23468685
gh api repos/OpenGameBuilder/opengamebuilder/rulesets/23468686
gh api repos/OpenGameBuilder/opengamebuilder/rulesets/23469610
gh api repos/OpenGameBuilder/opengamebuilder/branches/main/protection
gh api repos/OpenGameBuilder/opengamebuilder/rules/branches/main
gh api graphql -f query='query { repository(owner: "OpenGameBuilder", name: "opengamebuilder") { branchProtectionRules(first: 100) { nodes { pattern } pageInfo { hasNextPage endCursor } } } }'
```

Inspect any additional/inherited rulesets and their bypass actors, plus every
matching legacy pattern (paginate if necessary). For a real patch branch, also
query `branches/patch%2FvX.Y.Z/protection` and `rules/branches/patch%2FvX.Y.Z`.
An authenticated 404 for legacy protection can mean no legacy rule; a 401/403
does not. If one terminal is authenticated and another is not, compare
`GH_CONFIG_DIR` and `XDG_CONFIG_HOME` configuration locations before logging in
again. Do not display tokens or copy credentials into the repository.

Then perform a controlled acceptance check without deploying:

1. Publish this CI/action/test baseline and run CI on a representative PR.
   Confirm the reported check is exactly `build-test`, and require it from
   GitHub Actions in the ruleset.
2. On a temporary PR to `main`, deliberately break an existing test. Confirm the
   test fails, `build-test` is red, the failure artifact contains the assertion,
   and the merge box specifically identifies the failed required check as a
   blocker for a non-bypass contributor. Do **not** merge the failing PR.
3. Restore the assertion and push. Confirm the check passes. For a PR that does
   not use the sole-maintainer exception, have an eligible human approve, then
   push a small reviewable change and verify reapproval is required.
4. Repeat the failure/pass and review checks on a PR into a real `patch/vX.Y.Z`
   branch. Verify both CodeQL analyses and code-quality results run, rather than
   leaving required checks pending forever. Patch branches created from older
   releases must first receive the current workflows, shared action, and test
   baseline in their preparation PR; do not assume old tags contain these files.
5. Verify the release App can create the intended patch branch and open its
   preparation PR, while that PR still requires human approval and green tests.
   Confirm tag creation is the App's only tag bypass from authenticated ruleset
   details; do not create, move, or delete a real release tag merely to test rules.
   Rehearse actual release/tag operations only during an authorized release.
6. Record PR URLs, head SHAs, check-run URLs, merge-blocking evidence, and the
   authenticated ruleset/bypass inventory here before completing section 7.
   Close temporary PRs; do not merge them just to exercise the gate.

See GitHub's [available rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
for status-check, approval, creation, and bypass semantics.
