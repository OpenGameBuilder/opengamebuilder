#!/usr/bin/env bash
# Apply a reviewed edge candidate on the deployment host.
set -euo pipefail

candidate_dir="${1:?Candidate directory is required}"
deployment_environment="${2:?Deployment environment is required}"
# The workflow obtains separate production-environment approval before setting
# this flag; SSH still targets the selected deployment environment's host.
allow_profile_change="${3:-false}"
if [[ "$deployment_environment" != staging && "$deployment_environment" != production ]]; then
  echo "Expected deployment environment staging or production." >&2
  exit 1
fi
if [[ "$allow_profile_change" != true && "$allow_profile_change" != false ]]; then
  echo "Expected allow-profile-change to be true or false." >&2
  exit 1
fi
if (( $# > 3 )); then
  echo "Usage: apply-edge.sh <candidate-dir> <deployment-environment> [allow-profile-change=false]" >&2
  exit 1
fi
edge_dir="${EDGE_DIR:-/srv/opengamebuilder/edge}"
candidate_compose="${candidate_dir}/compose.yml"
candidate_caddyfile="${candidate_dir}/Caddyfile"
active_compose="${edge_dir}/compose.yml"
active_caddyfile="${edge_dir}/Caddyfile"

if [[ ! -f "$candidate_compose" || ! -f "$candidate_caddyfile" ]]; then
  echo "Edge candidate requires compose.yml and Caddyfile." >&2
  exit 1
fi

# Keep this script self-contained: the workflow streams it over SSH. The
# reserved marker must occur exactly once and be the entire first line.
read_edge_profile() {
  local caddyfile="$1" marker_count first_line
  marker_count="$(awk 'tolower($0) ~ /ogb-edge-profile/ { count++ } END { print count+0 }' "$caddyfile")"
  if [[ "$marker_count" == 0 ]]; then
    printf '%s\n' legacy
    return
  fi
  first_line="$(head -n 1 "$caddyfile")"
  if [[ "$marker_count" != 1 || ! "$first_line" =~ ^\#\ ogb-edge-profile:\ (shared|staging|production)$ ]]; then
    echo "Invalid edge profile marker in ${caddyfile}; expected one exact marker on the first line." >&2
    return 1
  fi
  printf '%s\n' "${BASH_REMATCH[1]}"
}

candidate_profile="$(read_edge_profile "$candidate_caddyfile")"
if [[ "$candidate_profile" == legacy ]]; then
  echo "Candidate Caddyfile requires an edge profile marker." >&2
  exit 1
fi
if [[ "$candidate_profile" != shared && "$candidate_profile" != "$deployment_environment" ]]; then
  echo "Candidate profile ${candidate_profile} does not include deployment environment ${deployment_environment}." >&2
  exit 1
fi
if [[ "$candidate_profile" == shared && "$deployment_environment" != production ]]; then
  echo "Shared edge updates require the production environment." >&2
  exit 1
fi

if [[ -f "$active_caddyfile" ]]; then
  active_profile="$(read_edge_profile "$active_caddyfile")"
  if [[ "$active_profile" == legacy ]]; then
    # The pre-profile deployment format always served both environments.
    if [[ "$candidate_profile" != shared || "$deployment_environment" != production ]]; then
      echo "Unmarked legacy edge can only adopt the shared profile through production." >&2
      exit 1
    fi
  elif [[ "$active_profile" != "$candidate_profile" ]] &&
    [[ "$allow_profile_change" != true ]]; then
    echo "Changing the installed edge profile requires allow-profile-change=true after production approval." >&2
    exit 1
  fi
fi

# Reject profile mistakes before directory creation, image pulls, or service work.
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

# Create only this profile's web roots as the deploying user, before Docker can
# create missing bind-mount directories as root during first-time edge setup.
case "$candidate_profile" in
  shared) edge_environments=(staging production) ;;
  staging|production) edge_environments=("$candidate_profile") ;;
esac
for environment in "${edge_environments[@]}"; do
  mkdir -p "${edge_dir}/../${environment}/web"
done

# Nothing above this line modifies the active edge files or service.
compose_changed=true
config_changed=true
if [[ -f "$active_compose" ]] && cmp -s "$candidate_compose" "$active_compose"; then
  compose_changed=false
fi
if [[ -f "$active_caddyfile" ]] && cmp -s "$candidate_caddyfile" "$active_caddyfile"; then
  config_changed=false
fi
compose_active=(docker compose -f "$active_compose" --project-directory "$edge_dir")
# Matching files do not guarantee the edge survived a host restart or port
# conflict. A stopped service still needs the normal Compose startup below.
if [[ "$compose_changed" == false && "$config_changed" == false ]] &&
  [[ -n "$("${compose_active[@]}" ps -q caddy)" ]]; then
  echo "Edge configuration is already current and Caddy is running."
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
