# First engine milestone

## Decision

The first compatibility target is **headless playback of one deterministic,
independently authored scene timeline**. A player loads the version-1 fixture,
produces the initial scene state, then advances one logical tick at a time.
Each tick applies the one command scheduled for it and produces an observable
snapshot.

This establishes an explicit playback contract for implementation and testing;
it is not yet a claim of behavioral compatibility with the original MyGameBuilder
client. Historical behavior requires separately recorded, reviewable evidence.
The fixture deliberately contains no original game data, artwork, or decompiled
source-derived structure.

## Repository map

| Area | Current responsibility |
| --- | --- |
| `OpenGameBuilder.Api.Contracts` | Browser-compatible DTOs shared across the public API boundary. |
| `OpenGameBuilder.Api.Client` | Typed HTTP client and configuration, dependent on Contracts rather than the API host. |
| `OpenGameBuilder.Api` | ASP.NET Core API host and endpoints. |
| `OpenGameBuilder.Web.Client` | Standalone Blazor WebAssembly UI using the API client. |
| `OpenGameBuilder.ServiceDefaults` | Shared resilience and telemetry defaults for service hosts. |
| `OpenGameBuilder.AppHost` | Local Aspire launcher for the API and web client; not production hosting. |
| `tests` | API and API-client behavior tests; the engine test project joins this area when the player is implemented. |
| [mygamebuilder-archive](https://github.com/OpenGameBuilder/mygamebuilder-archive) | Separate archival repository; it is not an implementation dependency or fixture source. |

The engine belongs in a new, framework-free project only when the player is
implemented. It must not depend on Blazor, ASP.NET Core, HTTP, persistence, the
AppHost, or archive access. A later host can map engine snapshots to rendering,
input, storage, and transport concerns at its boundary.

## Fixture and observable contract

[`test-data/engine/first-playback-scene.v1.json`](../../test-data/engine/first-playback-scene.v1.json)
is the canonical first fixture. It was written for this repository and is not an
import format or an archived-game sample. Its v1 shape is intentionally limited:

- one grid scene (`4 × 3`);
- one actor starting at `(1, 1)`;
- a timeline with one command at each logical tick;
- two movement commands and one text-output command.

The first player must yield this trace after loading the fixture:

| Tick | Actor position | Messages emitted at this tick | Completed |
| --- | --- | --- | --- |
| 0 | `(1, 1)` | none | no |
| 1 | `(2, 1)` | none | no |
| 2 | `(2, 2)` | none | no |
| 3 | `(2, 2)` | `Hello, builder!` | yes |
| 4 | `(2, 2)` | none | yes |

Advancing after completion must leave the terminal state unchanged and must not
re-emit the message. Loading an unsupported fixture version, an unknown command,
or a timeline with multiple commands at one tick must fail with a clear,
deterministic validation error.

## Scope

This milestone includes fixture loading, state construction, deterministic
tick-by-tick playback, and direct unit tests of the trace above. The next task
may introduce a small `OpenGameBuilder.Engine` project and matching test project
only with this player and its tests; it should not add an empty engine shell or a
generic framework first.

It excludes archive import, editor workflows, authentication, persistence,
multiplayer, real-time scheduling, rendering, audio, user input, randomness,
multiple actors, collision, and a public engine API. The player receives explicit
logical ticks, so it needs no clock abstraction. The fixture supplies all state,
so it needs no input or randomness abstraction. Add those seams only when a
subsequent engine behavior exercises them.

## Acceptance for the next task

The next engine change is complete when a framework-free test loads the canonical
fixture and proves every row in the trace, the terminal no-repeat behavior, and
the three invalid-input cases. It can run through the normal `dotnet test`
solution command without starting Blazor, HTTP, a database, Aspire, or Docker.
