#!/usr/bin/env bash
set -euo pipefail

image="${1:?API image reference is required}"

docker run --rm --entrypoint sh "$image" -c '
  set -eu
  test "$(id -u)" -ne 0
  test -r /app/OpenGameBuilder.Api.dll
  test ! -w /app
'

probe_network="ogb-api-probe-$$"
container_id=''
cleanup() {
  if [[ -n "$container_id" ]]; then
    docker stop "$container_id" >/dev/null 2>&1 || true
  fi
  docker network rm "$probe_network" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$probe_network" >/dev/null
mapfile -t proxy_networks < <(
  docker network inspect "$probe_network" \
    --format '{{range .IPAM.Config}}{{if .Subnet}}{{println .Subnet}}{{end}}{{end}}'
)
[[ "${#proxy_networks[@]}" -gt 0 ]]
printf -v trusted_proxy_networks '%s;' "${proxy_networks[@]}"
trusted_proxy_networks="${trusted_proxy_networks%;}"

container_id="$(docker run --rm -d \
  --network "$probe_network" \
  --env "ReverseProxy__KnownNetworks=$trusted_proxy_networks" \
  --publish 127.0.0.1::8080 \
  "$image")"
port="$(docker port "$container_id" 8080/tcp | sed -n '1s/.*://p')"
test -n "$port"
for attempt in {1..30}; do
  if response="$(curl --fail --silent \
    --header 'X-Forwarded-Proto: https' \
    "http://127.0.0.1:${port}/api/alive")" && [[ "$response" == 'Healthy' ]]; then
    echo 'API image runs as a read-only non-root application user and passes liveness.'
    exit 0
  fi
  sleep 1
done

docker logs "$container_id" >&2
echo 'Packaged API image did not pass its local liveness check.' >&2
exit 1
