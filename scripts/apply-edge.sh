#!/usr/bin/env bash
# Apply a reviewed edge candidate on the deployment host.
set -euo pipefail

candidate_dir="${1:?Candidate directory is required}"
edge_dir="${EDGE_DIR:-/srv/opengamebuilder/edge}"
candidate_compose="${candidate_dir}/compose.yml"
candidate_caddyfile="${candidate_dir}/Caddyfile"
active_compose="${edge_dir}/compose.yml"
active_caddyfile="${edge_dir}/Caddyfile"

test -f "$candidate_compose"
test -f "$candidate_caddyfile"
mkdir -p "$edge_dir"

# Compose resolves relative bind mounts from the permanent edge directory.
compose_candidate=(docker compose -f "$candidate_compose" --project-directory "$edge_dir")
"${compose_candidate[@]}" config --quiet
image="$("${compose_candidate[@]}" config --images)"
if [[ -z "$image" || "$image" == *$'\n'* ]]; then
  echo "Expected exactly one Caddy image in the edge Compose file." >&2
  exit 1
fi
docker pull "$image"
docker run --rm --entrypoint caddy \
  --mount "type=bind,src=${candidate_caddyfile},dst=/etc/caddy/Caddyfile,readonly" \
  "$image" validate --config /etc/caddy/Caddyfile

# Nothing above this line modifies the active edge files or service.
compose_changed=true
config_changed=true
if [[ -f "$active_compose" ]] && cmp -s "$candidate_compose" "$active_compose"; then
  compose_changed=false
fi
if [[ -f "$active_caddyfile" ]] && cmp -s "$candidate_caddyfile" "$active_caddyfile"; then
  config_changed=false
fi
if [[ "$compose_changed" == false && "$config_changed" == false ]]; then
  echo "Edge configuration is already current."
  exit 0
fi

if ! docker network inspect ogb-edge >/dev/null 2>&1; then
  docker network create ogb-edge
fi

backup_dir="$(mktemp -d "${edge_dir}/.rollback.XXXXXXXX")"
if [[ -f "$active_compose" ]]; then cp -p "$active_compose" "$backup_dir/compose.yml"; fi
if [[ -f "$active_caddyfile" ]]; then cp -p "$active_caddyfile" "$backup_dir/Caddyfile"; fi

restore_files() {
  if [[ -f "$backup_dir/compose.yml" ]]; then
    cp "$backup_dir/compose.yml" "$active_compose"
  else
    rm -f "$active_compose"
  fi
  if [[ -f "$backup_dir/Caddyfile" ]]; then
    cp "$backup_dir/Caddyfile" "$active_caddyfile"
  else
    rm -f "$active_caddyfile"
  fi
}

if [[ "$compose_changed" == true ]] && ! cp "$candidate_compose" "$active_compose"; then
  restore_files
  exit 1
fi
if [[ "$config_changed" == true ]] && ! cp "$candidate_caddyfile" "$active_caddyfile"; then
  restore_files
  exit 1
fi

compose_active=(docker compose -f "$active_compose" --project-directory "$edge_dir")

# A Compose change is an explicit edge-service update. Caddyfile-only changes
# leave the container running and use Caddy's graceful configuration reload.
if [[ "$compose_changed" == true ]] ||
  [[ -z "$("${compose_active[@]}" ps -q caddy)" ]]; then
  if ! "${compose_active[@]}" up -d; then
    restore_files
    if [[ -f "$active_compose" ]]; then "${compose_active[@]}" up -d || true; fi
    echo "Edge service update failed; previous files were restored in ${edge_dir}." >&2
    exit 1
  fi
fi

if [[ "$config_changed" == true ]]; then
  if ! "${compose_active[@]}" exec -T caddy caddy reload --config /etc/caddy/Caddyfile; then
    restore_files
    if [[ "$compose_changed" == true ]]; then
      "${compose_active[@]}" up -d || true
    fi
    if [[ -f "$active_compose" && -f "$active_caddyfile" ]]; then
      "${compose_active[@]}" exec -T caddy caddy reload --config /etc/caddy/Caddyfile || true
    fi
    echo "Caddy reload failed; previous files were restored in ${edge_dir}." >&2
    exit 1
  fi
fi

rm -r "$backup_dir"
echo "Edge configuration applied."
