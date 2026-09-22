# Hosting setup

Staging and production are independent deployment targets. Each GitHub
environment supplies its own SSH host, account, key, and trusted host-key entry.
They can point at the same server or different servers. Aspire is only the local
launcher; application hosting uses `deploy/staging` and `deploy/production`.

Each server runs **one host-local Caddy edge**, explicitly configured through
the `EDGE_PROFILE` variable on its GitHub deployment environment:

| Layout | Staging environment's `EDGE_PROFILE` | Production environment's `EDGE_PROFILE` |
| --- | --- | --- |
| Both applications on one server (current layout) | `shared` | `shared` |
| Separate servers | `staging` | `production` |

There is no default. Missing, unknown, or mismatched profiles fail closed.
`shared` is an intentional configuration, not an inferred relationship between
hosts. Each host has its own `ogb-edge` Docker network and Caddy certificate
volumes; the identical names on separate machines do not connect those machines.
An isolated profile has no routes, web mounts, or API aliases for the other
environment. Shared hosting still shares host/Docker privileges and outage risk;
it is not a security isolation boundary.

## Runtime trust boundaries

The reviewed SDK, ASP.NET runtime, and Caddy tags are paired with immutable image
digests. Dependabot continues to propose tag/digest updates, but a registry
retag cannot change an unreviewed build or edge deployment. Each built API image
is also deployed by its generated GHCR digest.
Dependabot's Docker cooldown is best effort: when the registry supplies no
publication date for a digest update, its PR reports that the cooldown could not
be applied. The digest still requires review and merging before it is used.

The API image declares the .NET image's non-root application user. CI and the
deployment job verify the effective UID is nonzero, the application assembly is
readable, `/app` is not writable by that user, and liveness succeeds before the
image can be deployed. The API Compose services publish no host port; Caddy
reaches them only through the external `ogb-edge` network.

Caddy terminates HTTPS and replaces client-supplied `X-Forwarded-For`,
`X-Forwarded-Proto`, and `X-Forwarded-Host` values before proxying. During
activation, `scripts/deploy-app.sh` reads the actual `ogb-edge` IPAM subnets and
passes only those CIDRs to the API. Forwarded-header middleware accepts one hop
from those networks and runs before HTTPS redirection. It does not trust every
private address or an arbitrary direct client. If the host network has no IPAM
subnet, activation fails before the candidate starts.

The host deployment account is separate from the API process identity. It needs
write access only below `/srv/opengamebuilder`, SSH access with the configured
key, and the Docker operations used by the reviewed deployment scripts. Docker
daemon access is host-privileged; do not reuse this account or key for application
traffic, interactive contributor access, or unrelated automation.

## Host edge changes

**🌐 CD Edge** (`.github/workflows/cd-edge.yml`) owns edge updates. Dispatch it
**from `main`**, selecting the GitHub environment that supplies the target host's
credentials and approval rules. An edge serving both environments must be
dispatched through **production**, never staging. Edge updates queue rather than
cancelling one another, even when two environments happen to share a host.

`scripts/render-edge.sh` combines the common pinned `deploy/edge/compose.yml`
with the selected `compose.<environment>.yml` mount overrides and
`Caddyfile.<environment>` site fragments. It produces standalone `compose.yml`
and `Caddyfile` candidates with an explicit profile marker. Only those rendered
files are transferred; do not deploy the common Compose base by itself.
Run the edge workflow before the first application deployment on a new host.

The workflow transfers candidate files to a separate directory on the host.
`scripts/apply-edge.sh` checks the candidate Compose definition, pulls its Caddy
image, and validates the candidate Caddyfile with that image **before** changing
the active files. If validation fails, the running configuration and active
files remain in place. A Caddyfile-only update copies the validated file into
the existing bind mount and calls `caddy reload`; it does not recreate Caddy.
An intentional Compose change runs `docker compose up -d`, which may recreate
the service. A failed reload restores the previous files and attempts to reload
the previous configuration. The workflow checks each selected site's `/health`
over HTTPS **on the SSH target host**, forcing its hostname to loopback while
still validating its TLS certificate. This tests edge readiness without needing
an application installed, and cannot accidentally validate an old DNS target.
DNS and certificate issuance must be ready for this check to pass; a new edge
may be installed while this check fails during a planned DNS cutover. It is not
application acceptance: each app deployment separately checks the real API and
browser revision. Inspect the job log and host state if activation or recovery fails;
do not assume a failed job automatically restored service availability.
An unchanged candidate leaves a running Caddy container alone, but starts it if
it is stopped. This cannot repair a port conflict with another host process.

The installed profile marker must agree with an application's configured
profile before release files are transferred. A normal edge update also refuses
to change an installed profile. Intentional migrations require
`allow-profile-change` and **production approval** in a separate authorization
job, then use the selected environment's own credentials and approval rules to
apply the change. Normal isolated staging updates do not enter the production
environment. Existing unmarked edge files
from the previous shared-only setup may be adopted only as `shared` through
production; they cannot silently become an isolated edge.

Application workflows update only their own release directory and API. They
require their host's edge network and never sync or restart Caddy. Staging
deployments queue instead of cancelling an in-flight deployment. Production
`/api/alive` is checked before and after staging updates **only when staging's
profile is `shared`**. Isolated staging neither requires production's URL nor
depends on production being available.

### Adopt explicit profiles on the current server

Before merging this workflow change, set the environment variable
`EDGE_PROFILE=shared` in **both** GitHub environments under **Settings >
Environments > staging/production > Environment variables**. Keep their existing
SSH secrets and verified host-key entries. These are configuration changes, not
an instruction to recreate the server or reset a password.

After merge, run **CD Edge** from `main`, select `production`, leave
`allow-profile-change` off, and approve it. This adopts the existing shared
layout while preserving the Compose project and certificate-volume names.
The old unmarked shared layout remains recognizable by application preflight
during this one-time adoption. Confirm the host-local HTTPS checks and the next
staging application's browser check pass.

### Later: move staging to its own server

1. Provision the new host with Docker/Compose, curl, a deployment account with
   write access under `/srv/opengamebuilder`, and ports 80/443 available for its
   edge. Do not run a competing native Caddy service.
2. Verify the new server's SSH host key through the
   [host-key guide](deployment-host-key.md). Change **only staging's** SSH
   secrets/host-key variable to the new host and set its `EDGE_PROFILE=staging`.
3. Coordinate DNS and certificate issuance for `staging.opengamebuilder.com`.
   Run **CD Edge** from `main` with environment `staging`, then **CD Staging**.
   A first edge check may need rerunning after DNS/certificates are ready; it
   deliberately does not accept a successful response from the old server.
4. Verify the new host's edge, API revision, and browser flow. Then set
   **production's** `EDGE_PROFILE=production` and dispatch **CD Edge** through
   production with `allow-profile-change` enabled. This deliberately removes the
   obsolete staging route/mount from the old host; coordinate the brief proxy
   interruption. Keep the old staging data until the cutover is accepted.

Pause conflicting deployment runs during the move. Moving credentials/profile
alone does not migrate application data, DNS, certificates, or release history.
Retain a documented recovery plan; no migration or cleanup is performed by a
normal application deployment.

To move **production** instead, provision and verify its new host, set
production's own SSH configuration and `EDGE_PROFILE=production`, then run its
edge and application workflows and verify the cutover. Once production is
accepted on the new host, leave staging's SSH configuration pointing at the old
host, set staging's `EDGE_PROFILE=staging`, and dispatch **CD Edge** with
environment `staging` and `allow-profile-change` enabled. Its separate
production approval authorizes removing the old production route/mount; the
apply job still uses staging's credentials to reach the old host. You do not
need to point production credentials back at that host. The same DNS,
certificate, data-retention, and recovery precautions apply in either direction.

### Host Caddy conflicts and read-only verification

Only the Docker edge should own this server's ports 80 and 443. A separately
installed `caddy.service` can start at boot, occupy those ports, and prevent
`ogb-edge-caddy-1` from starting. An API container being up does not establish
that a public site is reachable.

In an existing **root SSH session on the Hetzner server**, from any directory,
these commands inspect state without changing services or printing environment
variables or private keys:

```bash
systemctl is-enabled caddy
systemctl is-active caddy
ss -ltnp '( sport = :80 or sport = :443 )'
docker ps --all --filter name=ogb- --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
docker inspect --format '{{.Name}} image={{.Config.Image}} status={{.State.Status}} restarts={{.RestartCount}}' ogb-edge-caddy-1
docker logs --since 2h --tail 150 ogb-edge-caddy-1 2>&1
# Choose an application actually deployed on this host; repeat for the other
# only if this is a shared host.
environment=staging
docker logs --since 2h --tail 150 "ogb-${environment}-api-1" 2>&1
```

The native Caddy service should be disabled/inactive (or not installed).
`systemctl` returns a nonzero status for some of those expected states; run
these inspection commands individually, not in a fail-fast script. Container
logs may contain client addresses or request data; redact sensitive content
before sharing them.

If inspection confirms the native service is the conflicting, superseded OGB
proxy, coordinate a short interruption for **the sites on this host**, then run:

```bash
systemctl disable --now caddy
docker start ogb-edge-caddy-1
```

Do not stop a service hosting unrelated sites. No root-password reset or web
console is needed when the existing SSH session works. Restarting the container
restores its existing image; it does **not** apply a new image pin. After an edge
change is reviewed and merged, use GitHub **Actions > CD Edge > Run workflow**,
select `main` and the correct environment (production for a shared host), and
approve it. A Compose image change can briefly interrupt the sites on that host.
Verify the running image reference matches `deploy/edge/compose.yml` and that
the selected host's edge checks and its deployed applications' smoke tests pass.

## Application artifacts

After source validation, the package job produces one Release web archive.
After environment approval, deployment verifies that archive and builds and
pushes the API image once to the triggering repository owner's package namespace.
It pins `API_IMAGE` to the pushed image digest (not its mutable commit tag),
checks that exact image's API liveness locally, and stores
`releases/<release-id>/release-manifest.txt` with the source SHA, image digest
reference, and web archive SHA-256. The same web archive can be served at any
hostname with an `/api/*` reverse proxy; the browser calls the page's origin.
The only cross-origin URL is the explicit local Development override. Separate
staging and production runs package independently, so compare their manifests
rather than assuming identical bytes for the same commit.

## Application activation and rollback

The host keeps immutable application metadata in
`/srv/opengamebuilder/<environment>/releases/<release-id>/` and its web files in
`web/releases/<release-id>/`. The `current` and `previous` files contain paths to
those metadata directories. The root `web/index.html` is atomically replaced with
a redirect to the active `/releases/<release-id>/index.html` file. The deploy
script removes old root `index.html` compression sidecars before that switch so
Caddy cannot serve a stale compressed page. It also removes the packaged
release's index sidecars because they retain the original `/` base path. Blazor
maps the concrete `index.html` URL to the home page. Loaded pages continue to
request their own release's assets, and the prior web directory remains
available. The first deployment with this layout copies the
old in-place web files into a `legacy-*` release and retains its original root
assets when a prior `release-manifest.txt` exists. For an initial deployment,
there is no current or previous release, root manifest, or root index. The
candidate's `releases/<release-id>/predecessor` records `none`; an upgrade records
the exact `releases/<previous-id>` path instead. This record is written before
the `pending` marker and before starting the API. Recovery never interprets a
missing `previous` file as evidence of an initial deployment.

`scripts/deploy-app.sh` checks the archive checksum, stages the new files,
records the previous release, pulls and starts the API by its digest reference,
records the edge network as its forwarded-header trust boundary, then switches
the root page. The deploy job uses a browser to follow that page,
observe the frontend's `/api/about` request, and compare the API's source revision
with the protected commit being deployed. It also checks that the page renders
the returned application name and version. A failed activation or browser check
invokes `rollback`. For an upgrade, it validates the previous release against the
candidate's predecessor record and restarts that API image without rebuilding it.
A missing or corrupt expected predecessor fails recovery and retains `pending`
for operator investigation. A successful browser check clears the pending marker
with `finalize`.

For a pending initial deployment, rollback captures available container logs in
`releases/<release-id>/recovery.log`, then uses the candidate's Compose files to
stop and remove its API container, including one partially started by a failed
activation. It removes the root index and compression sidecars, `current`, and
the root release manifest. This is the defined undeployed state: no running
application API or active root page. The shared edge remains in place. Incoming
files, candidate metadata, recovery logs, and versioned web assets are retained;
retained assets may still be reached directly by their release URLs.

Recovery clears `pending` only after cleanup succeeds. If stopping the API or
removing active files fails, inspect the error and recovery log, correct the
cause, and repeat rollback for the same pending release. New activations remain
blocked until recovery succeeds. Retry deployment with a new release ID (a new
workflow run or attempt), since failed candidates are retained. After a first
release is finalized, it has no previous release to restore; a later successful
upgrade establishes that rollback target.

For a controlled staging rehearsal after a successful normal rollout, dispatch
**CD Staging** from `main` with **rehearse-rollback** enabled. It first passes
the browser check, then deliberately fails before `finalize`; the recovery step
must restore `previous`. This run is expected to be red, so inspect the recovery
step and independently verify the public page and `/api/about` afterward. Leave
the input off for normal staging updates.

Inspect `current`, `previous`, `pending`, the pending candidate's `predecessor`,
and the manifests before manual recovery. From a deployment checkout with SSH
access, recover a pending activation with its exact release ID:

```bash
ssh -i <deployment-key> <deploy-user>@<deploy-host> \
  bash -s -- rollback /srv/opengamebuilder/staging <pending-release-id> < scripts/deploy-app.sh
```

Use `production` in place of `staging` for production. Without a pending
activation, omit the release ID to restore the retained previous release. For
an upgrade rollback, verify the public page and `/api/about` after it returns;
for initial-deployment recovery, verify the API is stopped and the active root
files are absent. If predecessor state is missing or damaged, investigate and
repair it from verified release records; do not delete `pending` or invent `none`
to bypass recovery. Do not delete a release directory while old browser sessions
may still request its assets. Coordinate manual recovery with the environment's
deployment queue.

The Compose service is replaced before the root web redirect switches. During
that short interval, an already loaded page can call the new API, so API changes
must remain compatible with the retained frontend until its clients have aged
out. This mechanism provides an atomic web switch and a recoverable pair; it is
not a zero-downtime atomic swap of the API and web processes. The
staging failure and rollback rehearsal passed on 2026-09-20; see the
[recorded deployment evidence](#recorded-deployment-evidence).

To recover an edge change, fix the candidate on `main` and dispatch **CD Edge**
for the affected host again. For an urgent host-side recovery, use the last known-good edge
files retained in the host's `.rollback.*` directory after a failed activation,
validate them with `caddy validate`, and reload Caddy. Do not restart or
recreate Caddy for a Caddyfile-only correction. Coordinate host-side changes
with any active edge workflow so its next write does not overwrite the repair.

## Recorded deployment evidence

The [successful staging rollout](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35542650898)
and [2026-09-20 rollback rehearsal](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35542855238)
record activation and recovery of an existing installation. The rehearsal
deliberately failed after browser acceptance and restored the prior release
without rebuilding; its red status is intentional. It did not exercise recovery
of a failed initial deployment with no predecessor. That recovery path has
local mocked regression coverage, but no live rehearsal is recorded here.

The [production v0.10.0 release](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35674772060)
and [subsequent staging rollout](https://github.com/OpenGameBuilder/opengamebuilder/actions/runs/35675216560)
record later application acceptance. These historical runs do not establish
current host state, original SSH-key provenance, separate-host migration, or a
backup operator's readiness. Use the procedures above for current operations
and record new live verification separately from local checks.
