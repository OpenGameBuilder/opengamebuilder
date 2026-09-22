# Documentation

Start with [development setup](setup/development.md) to build, test, and run the
application. The [public roadmap](https://github.com/orgs/OpenGameBuilder/projects/3)
tracks project work. There is no game runtime or editor yet; the first engine
milestone's behavior and acceptance criteria remain to be agreed.

## Working on the application

| Task                                                   | Read                                                                                                                        |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Install tools, run locally, or debug                   | [Development setup](setup/development.md)                                                                                   |
| Choose a task or propose a change                      | [Contributing](../CONTRIBUTING.md) and [open issues](https://github.com/OpenGameBuilder/opengamebuilder/issues)             |
| Understand the current HTTP surface and health checks  | [API](backend/api.md)                                                                                                       |
| Run tests and understand their limits                  | [Testing](quality/testing.md)                                                                                               |
| Maintain agent instructions and vendored skills        | [AI tooling maintenance](setup/ai-tooling.md) and [AI policy](../AI_POLICY.md)                                              |
| Check browser and accessibility expectations           | [Browser support](frontend/browser-support.md)                                                                              |
| Host, deploy, or recover a release                     | [Hosting](setup/hosting.md), [GitHub setup](setup/github.md), and [SSH host-key verification](setup/deployment-host-key.md) |
| Prepare a release or patch                             | [Release process](release/README.md), [changelog](../CHANGELOG.md), and [versioning](release/versioning.md)                 |
| Ask a question or report privately                     | [Support](../SUPPORT.md) and [security](../SECURITY.md)                                                                     |
| Check responsibilities or bring in historical material | [Practical stewardship](community/stewardship.md)                                                                           |

## Repository map

- [API contracts](../src/OpenGameBuilder.Api.Contracts/) contain browser-compatible
  DTOs. The [API client](../src/OpenGameBuilder.Api.Client/) depends on these
  contracts, not on the server host.
- The [API host](../src/OpenGameBuilder.Api/) serves HTTP endpoints and uses
  [service defaults](../src/OpenGameBuilder.ServiceDefaults/) for health checks,
  resilience, and telemetry.
- The [web client](../src/OpenGameBuilder.Web.Client/) is standalone Blazor
  WebAssembly and calls the typed API client.
- [AppHost](../src/OpenGameBuilder.AppHost/) launches the API and frontend locally.
  [Compose deployment](../deploy/) is separate from local Aspire orchestration.
- [Tests](../tests/) cover the API/client and deployment tooling. Engine code,
  when introduced, should remain testable without Blazor, HTTP, or storage.

Formatting and compiler rules live in [`.editorconfig`](../.editorconfig) and
[`Directory.Build.props`](../Directory.Build.props); the contribution and testing
guides describe the current workflow. Database, blob-storage, and performance
design documents should accompany real features rather than empty placeholders.

## MyGameBuilder history and source boundaries

The original material is separate from this implementation. Start with the
[archive pointer](mygamebuilder/data-archive.md) and
[format documentation pointer](mygamebuilder/data-formats.md). Follow the
[AI/source-material policy](../AI_POLICY.md#decompiled-source-and-original-client-material)
for independent compatibility work. [Forum preservation pointers](community/forum-archive.md)
and [community contact information](community/discord.md) provide historical
context; private chat is not required for contributing.

## General learning resources

General framework and tooling references belong in the organization's
[shared learning resources](https://github.com/OpenGameBuilder/.github/tree/main/resources).
Keep application-specific instructions here and link to shared material rather
than maintaining another reference library.
