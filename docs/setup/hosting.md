# Hosting setup

Production uses the Compose files in `deploy/production` and `deploy/edge`;
staging uses `deploy/staging` and the same edge. The shared Caddy service routes
both sites and reads their published web files. The `ogb-edge` Docker network
connects Caddy to both API services. Aspire is only the local launcher.

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

The staging and production application workflows update only their own release
directory and API service. They require the shared edge network to exist and
never sync or restart Caddy. Staging deployments queue instead of cancelling an
in-flight deployment. Production `/api/alive` is checked before and after a
staging update; a failed preflight stops the update.

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
a redirect to the active versioned web path. Loaded pages continue to request
their own release's assets, and the prior web directory remains available. The
first deployment with this layout copies the old in-place web files into a
`legacy-*` release and retains its original root assets.

`scripts/deploy-app.sh` checks the archive checksum, stages the new files,
records the previous release, pulls and starts the API by its digest reference,
then switches the root page. The deploy job uses a browser to follow that page,
observe the frontend's `/api/about` request, and compare the API's source revision
with the protected commit being deployed. It also checks that the page renders
the returned application name and version. A failed activation or browser check
invokes `rollback` and restarts the recorded previous API image without rebuilding
it. A successful browser check clears the pending marker with `finalize`.

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
not a zero-downtime atomic swap of the API and web processes. The staging failure
and rollback rehearsal required by foundation checklist section 14 remains the
live acceptance check.

To recover an edge change, fix the candidate on `main` and dispatch **CD Shared
Edge** again. For an urgent host-side recovery, use the last known-good edge
files retained in the host's `.rollback.*` directory after a failed activation,
validate them with `caddy validate`, and reload Caddy. Do not restart or
recreate Caddy for a Caddyfile-only correction. Coordinate host-side changes
with any active edge workflow so its next write does not overwrite the repair.
