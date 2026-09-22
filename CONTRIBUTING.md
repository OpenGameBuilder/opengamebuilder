# Contributing to OpenGameBuilder

Thank you for your interest in contributing to OpenGameBuilder.

OpenGameBuilder is a community open-source preservation, reimplementation, and extension of MyGameBuilder.com. Contributions are welcome from former MyGameBuilder users and from people who are new to the project.

A contribution does not need to be code to matter.

## Project Status

OpenGameBuilder is in active development. Some architecture, APIs, tooling, and workflows may change as the project grows.

The goal is to keep the project easy to build, test, and contribute to, while also being careful with its preservation work and the history of the original MyGameBuilder community.

## Ways to Contribute

Useful contributions include:

- code changes;
- documentation;
- bug reports;
- testing;
- UI/UX feedback;
- accessibility feedback;
- compatibility testing for games;
- historical knowledge about MyGameBuilder;
- archival research;
- issue triage;
- community support.

If you are unsure where to start, look for issues labeled `good first issue`,
`help wanted`, or `documentation`, or issues with the `Bug` type. The public
[OpenGameBuilder Roadmap](https://github.com/orgs/OpenGameBuilder/projects/3)
tracks work, including the `Triage` status; triage is not an issue label.

## Before You Start

For small fixes, documentation improvements, typo fixes, straightforward bugs, and focused cleanup, feel free to open a pull request.

For larger changes, please open an issue or
[GitHub Discussion](https://github.com/OpenGameBuilder/opengamebuilder/discussions)
first. Use Discussions for exploratory questions and ideas; private Discord
access is not required to contribute. This is especially important for changes involving:

- major architecture;
- game runtime behavior;
- editor behavior;
- public APIs;
- data formats;
- compatibility decisions;
- licensing;
- governance;
- community or moderation policy.

This helps avoid wasted work and gives maintainers a chance to discuss the direction before implementation starts.

## Development Setup

Development setup instructions are maintained in:

[`docs/setup/development.md`](docs/setup/development.md)

That document covers setting up the project with Visual Studio or VS Code.

The repository is intended to work smoothly from a fresh checkout. If the setup guide does not work for you, please open an issue with your operating system, editor, installed SDK/runtime versions, and the error you encountered.

## Repository Standards

The repository includes an `.editorconfig`, and formatting runs on commit.

Please keep changes consistent with the existing style and project structure. When future coding standards or architecture documentation are added, contributors should follow those documents as well.

Before opening a pull request, please make sure the project builds and tests pass locally when practical. CI/CD also runs tests for pull requests and protected branches.

## Issues

Use the [issue forms](https://github.com/OpenGameBuilder/opengamebuilder/issues/new/choose)
for concrete work: Bug Report for broken behavior, Compatibility Issue for
observed differences from MyGameBuilder (also tracked as `Bug`), Enhancement for
improving an existing capability, and Feature Request for a new capability.
Use [Discussions](https://github.com/OpenGameBuilder/opengamebuilder/discussions)
for questions and proposals that are still exploratory.

When reporting a bug, please include:

- what happened;
- what you expected to happen;
- steps to reproduce the problem;
- your operating system and browser, if relevant;
- screenshots, video, logs, or error messages, if useful.

When reporting a compatibility issue with an archived or recreated MyGameBuilder game, please include:

- the game title or identifier, if it is public;
- what behavior seems wrong;
- what the expected behavior is, if known;
- whether the problem affects one game or many;
- screenshots or video, if safe and useful.

Do not include passwords, access tokens, private information, or sensitive archival material in public issues.

## Pull Requests

Pull requests should be focused and easy to review.

A good pull request usually includes:

- a clear summary of what changed;
- why the change was made;
- any related issue numbers;
- notes about testing;
- screenshots or video for visible UI changes;
- documentation updates when behavior changes.

Large pull requests are harder to review and more likely to stall. When possible, split large work into smaller, meaningful pieces.

Draft pull requests are welcome when you want early feedback.

## Significant Changes

Significant changes should usually be discussed before implementation.

A change is significant if it affects project direction, architecture, compatibility, archival policy, contributor expectations, public APIs, data formats, releases, governance, or how archived MyGameBuilder games are restored, presented, or made playable.

Significant decisions should leave a written record where practical, such as an issue, discussion, pull request, architecture decision record, or documentation update.

## Preservation and Archive Contributions

OpenGameBuilder includes preservation work related to MyGameBuilder games and historical material.

Before adding games, assets, submissions, or test fixtures, follow the short
[material-intake and creator-request checklist](docs/community/stewardship.md#material-intake-and-creator-requests).
Implementation tests use independently created fixtures. The application's
Apache-2.0 license does not grant rights to original MyGameBuilder material.

Please handle archival material carefully. The existence of archived material does not automatically mean every item should be public, searchable, or restored without context.

Do not post private, sensitive, identifying, or personal information from archived material in public issues, pull requests, comments, screenshots, or documentation.

Archive-related contributions should consider:

- preservation value;
- creator attribution;
- creator requests;
- privacy;
- safety;
- historical context;
- technical feasibility;
- long-term maintainability.

Questions or concerns about archived material should be raised with the maintainers. Sensitive concerns should be reported privately rather than through a public issue.

## AI-Assisted Contributions

AI-assisted development is allowed and supported in OpenGameBuilder.

Contributors may use AI tools for coding, testing, debugging, documentation, review, learning, and project exploration. Repository-specific guidance lives in `AGENTS.md`; tools with their own instruction mechanisms may also use their standard configuration when the repository adds one.

AI use does not lower the quality bar. If you submit AI-assisted work, you are responsible for understanding, reviewing, testing, and maintaining it.

Routine AI use does not need to be disclosed. Agent-authored or mostly AI-generated pull requests should mention that AI assistance was used.

Do not use AI tools to copy, translate, port, adapt, or mechanically rewrite decompiled source code from the original MyGameBuilder Flash client or any other proprietary source.

See [`AI_POLICY.md`](AI_POLICY.md) for the full policy.

## Security and Private Reports

Please do not report security vulnerabilities in public issues or discussions.

Report security vulnerabilities through [the private security reporting process](SECURITY.md).
For Code of Conduct reports, privacy concerns, or sensitive archival concerns,
use the private contact in the organization-wide
[Code of Conduct](https://github.com/OpenGameBuilder/.github/blob/main/CODE_OF_CONDUCT.md#reporting-an-issue).

## Community Standards

All contributors are expected to follow the organization-wide
[Code of Conduct](https://github.com/OpenGameBuilder/.github/blob/main/CODE_OF_CONDUCT.md).

Project governance, roles, and decision-making authority are described in the
organization-wide [governance document](https://github.com/OpenGameBuilder/.github/blob/main/GOVERNANCE.md).

## Licensing

By contributing to OpenGameBuilder, you agree that your contributions may be distributed under the project’s license.

See [`LICENSE`](LICENSE) for details.
