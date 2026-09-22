#!/usr/bin/env bash
set -euo pipefail

# Stream this script over pinned SSH. Force TLS to the edge on that host so
# pre-cutover DNS cannot accidentally validate the old server instead.
environment="${1:-}"
base_url="${2:-}"
[[ "$environment" == staging || "$environment" == production ]] || { echo 'Unknown edge environment.' >&2; exit 1; }
[[ "$base_url" =~ ^https://([a-zA-Z0-9.-]+)/?$ ]] || { echo 'Expected an HTTPS origin without a port or path.' >&2; exit 1; }
hostname="${BASH_REMATCH[1]}"
response="$(curl --fail --show-error --silent \
  --noproxy '*' \
  --resolve "${hostname}:443:127.0.0.1" \
  --connect-timeout 10 --max-time 30 --retry-max-time 180 \
  --retry 5 --retry-delay 5 --retry-all-errors \
  "${base_url%/}/health")"
[[ "$response" == "ok $environment" ]] || { echo "Unexpected ${environment} edge health response." >&2; exit 1; }
echo "Verified ${environment} HTTPS edge on this host."
