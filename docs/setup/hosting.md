# Hosting setup

Production uses the Compose files in `deploy/production` and `deploy/edge`;
staging uses `deploy/staging` and the same edge. The shared Caddy service routes
both sites and reads their published web files. The `ogb-edge` Docker network
connects Caddy to both API services. Aspire is only the local launcher.

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
private address or an arbitrary direct client. If the shared network has no IPAM
subnet, activation fails before the candidate starts.

The host deployment account is separate from the API process identity. It needs
write access only below `/srv/opengamebuilder`, SSH access with the configured
key, and the Docker operations used by the reviewed deployment scripts. Docker
daemon access is host-privileged; do not reuse this account or key for application
traffic, interactive contributor access, or unrelated automation.

## Shared edge changes

The shared edge is owned by **🌐 CD Shared Edge** (`.github/workflows/cd-edge.yml`).
After a reviewed change to `deploy/edge/Caddyfile` or `deploy/edge/compose.yml`
reaches `main`, dispatch that workflow **from `main`**. It uses the `production`
environment's reviewer approval and deployment credentials, and queues edge
updates without cancelling an update already in progress. Run it once before
the first application deployment to create the shared network and Caddy service.

The workflow transfers candidate files to a separate directory on the host.
`scripts/apply-edge.sh` checks the candidate Compose definition, pulls its Caddy
image, and validates the candidate Caddyfile with that image **before** changing
the active files. If validation fails, the running configuration and active
files remain in place. A Caddyfile-only update copies the validated file into
the existing bind mount and calls `caddy reload`; it does not recreate Caddy.
An intentional Compose change runs `docker compose up -d`, which may recreate
the service. A failed reload restores the previous files and attempts to reload
the previous configuration. The workflow checks both API liveness URLs after
the update. Inspect the job log and host state if activation or recovery fails;
do not assume a failed job automatically restored service availability.
An unchanged candidate leaves a running Caddy container alone, but starts it if
it is stopped. This cannot repair a port conflict with another host process.

The staging and production application workflows update only their own release
directory and API service. They require the shared edge network to exist and
never sync or restart Caddy. Staging deployments queue instead of cancelling an
in-flight deployment. Production `/api/alive` is checked before and after a
staging update; a failed preflight stops the update.

### Host Caddy conflicts and read-only verification

Only the Docker edge should own this server's ports 80 and 443. A separately
installed `caddy.service` can start at boot, occupy those ports, and prevent
`ogb-edge-caddy-1` from starting. An API container being up does not establish
that either public site is reachable.

In an existing **root SSH session on the Hetzner server**, from any directory,
these commands inspect state without changing services or printing environment
variables or private keys:

```bash
systemctl is-enabled caddy
systemctl is-active caddy
ss -ltnp '( sport = :80 or sport = :443 )'
docker inspect --format '{{.Name}} image={{.Config.Image}} status={{.State.Status}} restarts={{.RestartCount}}' ogb-edge-caddy-1 ogb-staging-api-1 ogb-production-api-1
docker logs --since 2h --tail 150 ogb-edge-caddy-1 2>&1
docker logs --since 2h --tail 150 ogb-staging-api-1 2>&1
docker logs --since 2h --tail 150 ogb-production-api-1 2>&1
```

The native Caddy service should be disabled/inactive (or not installed).
`systemctl` returns a nonzero status for some of those expected states; run
these inspection commands individually, not in a fail-fast script. Container
logs may contain client addresses or request data; redact sensitive content
before sharing them.

If inspection confirms the native service is the conflicting, superseded OGB
proxy, coordinate a short interruption for **both sites**, then run on the host:

```bash
systemctl disable --now caddy
docker start ogb-edge-caddy-1
curl --fail --show-error https://opengamebuilder.com/api/alive
curl --fail --show-error https://staging.opengamebuilder.com/api/alive
```

Do not stop a service hosting unrelated sites. No root-password reset or web
console is needed when the existing SSH session works. Restarting the container
restores its existing image; it does **not** apply a new image pin. After an edge
change is reviewed and merged, use GitHub **Actions > CD Shared Edge > Run
workflow**, select `main`, and approve the production environment. A Compose
image change can recreate the shared proxy and briefly interrupt both sites.
Verify the running image reference matches `deploy/edge/compose.yml` and that
both workflow liveness checks pass.

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
assets when a prior `release-manifest.txt` exists. A first deployment without
that manifest records `previous release: none`; it has no managed rollback
target until a subsequent successful release retains this one. Do not infer
rollback readiness from a successful first release or create a release solely
to manufacture a predecessor.

`scripts/deploy-app.sh` checks the archive checksum, stages the new files,
records the previous release, pulls and starts the API by its digest reference,
records the edge network as its forwarded-header trust boundary, then switches
the root page. The deploy job uses a browser to follow that page,
observe the frontend's `/api/about` request, and compare the API's source revision
with the protected commit being deployed. It also checks that the page renders
the returned application name and version. A failed activation or browser check
invokes `rollback` and restarts the recorded previous API image without rebuilding
it. A successful browser check clears the pending marker with `finalize`.

For a controlled staging rehearsal after a successful normal rollout, dispatch
**CD Staging** from `main` with **rehearse-rollback** enabled. It first passes
the browser check, then deliberately fails before `finalize`; the recovery step
must restore `previous`. This run is expected to be red, so inspect the recovery
step and independently verify the public page and `/api/about` afterward. Leave
the input off for normal staging updates.

Inspect `current`, `previous`, `pending`, and the manifests before manual
recovery. From a deployment checkout with SSH access, the same
rollback command is:

```bash
ssh -i <deployment-key> <deploy-user>@<deploy-host> \
  bash -s -- rollback /srv/opengamebuilder/staging < scripts/deploy-app.sh
```

Use `production` in place of `staging` for production. The rollback script reads
the previous manifest and Compose file, restarts its cached image by digest,
restores its index, and updates `current`. Verify the public page and `/api/about` after it
returns; inspect Docker and Caddy logs if it cannot restart the old image. Do not
delete a release directory while old browser sessions may still request its
assets. Coordinate manual recovery with the environment's deployment queue.

The Compose service is replaced before the root web redirect switches. During
that short interval, an already loaded page can call the new API, so API changes
must remain compatible with the retained frontend until its clients have aged
out. This mechanism provides an atomic web switch and a recoverable pair; it is
not a zero-downtime atomic swap of the API and web processes. The section 14
staging failure and rollback rehearsal passed on 2026-09-20; see the
[checklist evidence](../foundation-checklist.md#14-make-rollout-atomic-and-rollback-explicit).

To recover an edge change, fix the candidate on `main` and dispatch **CD Shared
Edge** again. For an urgent host-side recovery, use the last known-good edge
files retained in the host's `.rollback.*` directory after a failed activation,
validate them with `caddy validate`, and reload Caddy. Do not restart or
recreate Caddy for a Caddyfile-only correction. Coordinate host-side changes
with any active edge workflow so its next write does not overwrite the repair.
