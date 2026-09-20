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

The staging and production application workflows update only their own web
directory, Compose file, `.env`, and API service. They require the shared edge
network to exist and never sync or restart Caddy. Staging deployments queue
instead of cancelling an in-flight deployment. Their preflight and smoke-test
jobs probe production `/api/alive` before and after a staging update; a failed
preflight stops the update. These checks establish API availability at probe
time, not continuous uptime or complete browser behavior.

After source validation, the package job produces one Release web archive.
After environment approval, deployment verifies that archive and builds and
pushes the API image once to the triggering repository owner's package namespace.
It pins `API_IMAGE` to the pushed image digest (not its mutable commit tag),
checks that exact image's API liveness locally, and stores
`release-manifest.txt` beside Compose with the source SHA, image digest
reference, and web archive SHA-256. The same web archive can be served at any
hostname with an `/api/*` reverse proxy; the browser uses the page's origin.
The only cross-origin URL is the explicit local Development override. There is
no hostname-specific rebuild, but separate staging and production workflow runs
currently package independently; compare their manifests rather than assuming
identical bytes for the same commit. The existing
in-place web sync is still non-atomic; see foundation checklist section 14 for
activation and rollback work.

To recover an edge change, fix the candidate on `main` and dispatch **CD Shared
Edge** again. For an urgent host-side recovery, use the last known-good edge
files retained in the host's `.rollback.*` directory after a failed activation,
validate them with `caddy validate`, and reload Caddy. Do not restart or
recreate Caddy for a Caddyfile-only correction. Coordinate host-side changes
with any active edge workflow so its next write does not overwrite the repair.
