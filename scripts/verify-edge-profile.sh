#!/usr/bin/env bash
# Read-only application preflight for the edge installed on a deployment host.
set -euo pipefail

edge_dir="${1:?Edge directory is required}"
expected_profile="${2:?Expected edge profile is required}"
if [[ "$expected_profile" != shared && "$expected_profile" != staging && "$expected_profile" != production ]]; then
  echo "Expected edge profile shared staging or production." >&2
  exit 1
fi
if (( $# != 2 )); then
  echo "Usage: verify-edge-profile.sh <edge-dir> <expected-profile>" >&2
  exit 1
fi
if [[ ! -f "$edge_dir/compose.yml" || ! -f "$edge_dir/Caddyfile" ]]; then
  echo "Edge installation requires compose.yml and Caddyfile in ${edge_dir}." >&2
  exit 1
fi

# Self-contained for `ssh ... bash -s`: match the same reserved first-line
# marker accepted by apply-edge.sh without Docker calls or filesystem writes.
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

active_profile="$(read_edge_profile "$edge_dir/Caddyfile")"
if [[ "$active_profile" == legacy ]]; then
  # Existing installations predate the marker and use the original shared edge.
  if [[ "$expected_profile" != shared ]]; then
    echo "Unmarked legacy edge is only valid for the shared profile." >&2
    exit 1
  fi
  echo "Verified legacy shared edge profile."
elif [[ "$active_profile" != "$expected_profile" ]]; then
  echo "Installed edge profile ${active_profile} does not match expected profile ${expected_profile}." >&2
  exit 1
else
  echo "Verified edge profile: ${active_profile}."
fi
