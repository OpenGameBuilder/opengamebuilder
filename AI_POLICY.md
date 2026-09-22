# AI Policy

AI assistance is welcome and optional. It can help with learning, implementation,
tests, debugging, documentation, and review. Contributors remain responsible for
the work they submit.

## Core Rule

Understand, review, test where practical, and maintain every contribution during
review, regardless of how it was produced. Do not submit work you do not understand.
Be able to explain what changed, why the approach fits the project, what tests
cover it, and its risks, dependencies, and maintenance cost.

AI suggestions are input for human judgment. Confidence, compilation, passing
tests, or an automated review do not establish correctness. Check suggestions in
context, reject incorrect advice, and ask maintainers when requirements are unclear.
AI review does not replace human review, security review, or maintainer judgment.

## Repository Instructions and Validation

Follow applicable [AGENTS.md](AGENTS.md), Copilot and area-specific instructions,
[contribution guidance](CONTRIBUTING.md), and this policy. Repository requirements
and maintainer review take precedence over an AI tool's suggestions.

AI-assisted work must meet the same standards as other contributions: correct,
readable, maintainable, consistent with the architecture and coding rules, and
free of unnecessary abstractions, invented APIs, and security or privacy defects.
Use the normal build, test, formatting, linting, CI/CD, and GitHub Code Quality
checks. See [development setup](docs/setup/development.md) and
[testing guidance](docs/quality/testing.md) for the current workflow.

Add or update tests when appropriate. Review generated tests against requirements,
not just the implementation; for bug fixes, prefer a test that fails before the
fix and passes afterward. Record expected behavior changes in an issue, PR, test,
architecture note, or project document. Applying AI review feedback carries the
same responsibility to verify it as any other change.

## Disclosure

Routine autocomplete, wording or grammar fixes, exploratory questions,
commit-message help, and private code explanations need no disclosure.

Mention AI assistance when materially relevant to review, including mostly
AI-generated or agent-authored PRs, architecture proposals, compatibility
analysis, and generated tests that define important behavior. A short note
describing the assistance and the review and validation actually performed is
enough. Do not claim checks that were not run.

## Autonomous Agents and Bots

Agents must remain accountable to a human contributor. Do not run unattended
agents that mass-create issues, PRs, comments, reviews, or discussions.

The contributor who starts an agent must review its PR before requesting
maintainer review. Remove mistakes, irrelevant or noisy changes, broken
formatting, and false explanations first.

Do not give agents broad write access, secrets, production credentials, private
reports, or sensitive data without explicit maintainer approval of that setup.
Maintainers may limit, close, or block agent activity that creates security risk,
review or moderation burden, or low-quality noise.

## Decompiled Source and Original Client Material

OpenGameBuilder independently reimplements and extends MyGameBuilder. Decompiled
original-client source exists outside this repository; it is not implementation
input.

Do not use AI to copy, translate, port, rewrite, adapt, refactor, or mechanically
convert decompiled or proprietary source into OpenGameBuilder work. Do not supply
that source to AI tools to explain it for recreating its implementation or to
derive equivalent classes, methods, names, control flow, or architecture. The ban
also covers source-derived tests, comments, documentation, and pseudocode.
Intermediate AI output does not make copied or source-derived work acceptable.

Use independently observed behavior for compatibility work: public user-facing
behavior, safe screenshots or recordings, independently written notes, expected
input/output examples, behavior tests, project-created safe fixtures, and
community knowledge. Describe what the original client did rather than how its
source implemented it.

Do not use private original-site data, unapproved original assets, or copied
comments, names, structures, or implementation details from proprietary material
as compatibility inputs. If an important behavior can only be justified by
decompiled source, ask maintainers before implementing it; this does not permit
using AI to derive an implementation from that source.

## Privacy and Sensitive Information

Do not put private, sensitive, identifying, confidential, or non-public project
information into AI tools without explicit maintainer approval of that use.
This includes passwords, tokens, API keys, user information, private reports,
sensitive historical material, unpublished security details, maintainer
discussions, infrastructure details, and anything unsuitable for a public issue
or PR. When in doubt, do not send it.

## Licensing and Attribution

AI does not remove licensing, attribution, or source-origin responsibilities.
Submit copied code, assets, documentation, or text only when its license permits
the use and proper attribution is included. If generated output appears copied,
verify the source is compatible with the project's license and attribution
requirements before submitting it. Do not use AI to hide or launder its origin.

## Documentation, Issues, and Evidence

Documentation must describe the actual project accurately and usefully. Remove
filler, invented commands or architecture, fake citations, and unsupported
certainty. Verify AI-generated bug reports yourself before submitting them;
include reproduction steps, expected and actual behavior, relevant logs or
screenshots, and enough context to act. AI speculation is not a verified finding.

## Enforcement

Maintainers may require explanations, revisions, tests, rewrites, or removal.
They may reject or close work that is unreviewed or not understood by its
contributor, contains invented facts or behavior, creates unnecessary maintenance
burden, violates security, privacy, licensing, attribution, or source-material
rules, generates excessive agent noise, or repeatedly ignores this policy.
