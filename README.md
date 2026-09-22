# OpenGameBuilder

OpenGameBuilder is an independent, community-led open-source reimplementation
and extension of MyGameBuilder, the original Flash game-making site. It is not
an official continuation of MyGameBuilder.

## What works today

The project is in early development. This repository currently provides a
.NET API and a standalone Blazor WebAssembly frontend. The home page fetches
application information from `/api/about` and displays the name and version;
the API also exposes `/api/alive` for liveness checks. Aspire launches the two
applications locally, and automated tests cover API and client behavior.

There is no playable game runtime, game importer, or editor yet. APIs and
architecture may change before v1; original-game compatibility is not established.

The next milestone is to make the foundation ready for engine development.
The first engine milestone's compatibility goal, independent fixture, and
acceptance criteria are still to be agreed through a
[public proposal](https://github.com/OpenGameBuilder/opengamebuilder/discussions).
Full original-site recreation and broad game compatibility are outside this
initial foundation work.

## Start contributing

1. Follow the [Windows development setup](docs/setup/development.md#command-line-workflow-start-here)
   to install the supported tools, build, test, and run the application. It also
   covers Visual Studio and VS Code. Local development does not require Docker,
   a database, production credentials, or Discord access.
2. Read the [contribution guide](CONTRIBUTING.md) and
   [testing guidance](docs/quality/testing.md) before changing code. If you use AI
   tools, follow the [AI policy](AI_POLICY.md).
3. Pick a bounded task from the [public roadmap](https://github.com/orgs/OpenGameBuilder/projects/3)
   or [open issues](https://github.com/OpenGameBuilder/opengamebuilder/issues).
   Check existing issues before starting, and propose larger changes before
   implementation as described in the contribution guide.

The [documentation index](docs/README.md) maps the application, operating guides,
and browser/accessibility expectations.
Browse the [published searchable documentation](https://opengamebuilder.github.io/opengamebuilder/)
for the latest explicitly published guides.

Useful starting tasks include following the setup guide in your editor and
reporting a reproducible failure, improving an unclear setup instruction, or
adding a focused regression test for an API/client bug. Fresh-checkout editor
verification remains open. Engine contributors can help define a small,
independently testable milestone through a public proposal.

Use the [issue forms](https://github.com/OpenGameBuilder/opengamebuilder/issues/new/choose)
for reproducible bugs and concrete proposals. See [support](SUPPORT.md) for help
and [security reporting](SECURITY.md) for private vulnerability reports.

## Implementation, archive, and original site

- **This repository** contains the new OpenGameBuilder implementation, its tests,
  and contributor documentation.
- **The [MyGameBuilder archive](https://github.com/OpenGameBuilder/mygamebuilder-archive)**
  is a separate preservation repository for historical MyGameBuilder material.
  You do not need it to build or run this application.
- **Original MyGameBuilder** is the historical Flash site whose behavior informs
  the community's compatibility goals. This project does not claim to be the
  original service or its official successor.

Compatibility work should use observed behavior, independently written notes,
and safe project-created fixtures. Do not copy or translate decompiled original
client source into this implementation; see the
[source-material policy](AI_POLICY.md#decompiled-source-and-original-client-material).
Do not post private archived data or original proprietary assets in public issues.

## License

This implementation is licensed under [Apache License 2.0](LICENSE). That license
does not grant rights to original MyGameBuilder assets or archived material.

## Build and deployment

For deployment operations, see [hosting setup](docs/setup/hosting.md). Aspire is
the local launcher; production hosting uses Docker Compose. These workflow
badges describe automation status, not game compatibility or feature completeness.

[![CI](https://github.com/OpenGameBuilder/opengamebuilder/actions/workflows/ci.yml/badge.svg)](https://github.com/OpenGameBuilder/opengamebuilder/actions/workflows/ci.yml)
[![CD Staging](https://github.com/OpenGameBuilder/opengamebuilder/actions/workflows/cd-staging.yml/badge.svg)](https://github.com/OpenGameBuilder/opengamebuilder/actions/workflows/cd-staging.yml)
[![CD Production](https://github.com/OpenGameBuilder/opengamebuilder/actions/workflows/cd-production.yml/badge.svg)](https://github.com/OpenGameBuilder/opengamebuilder/actions/workflows/cd-production.yml)
