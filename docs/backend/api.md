# Current API

The ASP.NET Core host currently exposes application information and health
checks. There are no game, editor, account, database, or blob-storage endpoints.
Use [development setup](../setup/development.md) to run the API locally over
HTTPS; the default API origin is `https://localhost:7000`.

| Endpoint | Availability | Behavior |
| --- | --- | --- |
| `GET /api/about` | All environments | Application name, informational version, API environment, and source revision |
| `GET /api/alive` | All environments | Plain-text liveness status from checks tagged `live` |
| `/health` | Development only, on the API origin | Readiness result from all registered health checks |
| `/alive` | Development only, on the API origin | Liveness result from checks tagged `live` |
| `/openapi/v1.json` and `/scalar` | Development only | OpenAPI description and interactive API documentation |

`/api/about` uses the [AboutResponse contract](../../src/OpenGameBuilder.Api.Contracts/About/AboutResponse.cs).
Its JSON properties are `applicationName`, `version`, `apiEnvironmentName`, and
`sourceRevision`. The source revision comes from the deployment's `SOURCE_SHA`
and may be null in a local run. The
[typed client](../../src/OpenGameBuilder.Api.Client/About/IAboutApiClient.cs)
is the frontend entry point for this request.

Health checks are implemented in
[ServiceDefaults](../../src/OpenGameBuilder.ServiceDefaults/Extensions.cs).
The current `self` check reports process liveness. A passing `/api/alive` does not
prove frontend startup, a frontend-to-API request, or future dependency readiness.
The [integration tests](../../tests/OpenGameBuilder.Api.Tests/HealthEndpointTests.cs)
cover environment availability and health-check failure behavior.

On a deployed host, Caddy proxies `/api/*` to the API and serves the web client.
Caddy's public `/health` is an edge response, distinct from the API's
Development-only readiness endpoint. See [hosting](../setup/hosting.md) for
routing and [testing](../quality/testing.md) for the deployment browser smoke.
