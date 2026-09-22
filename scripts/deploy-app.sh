#!/usr/bin/env bash
set -euo pipefail

# Run on the application host. The workflow transfers an archive, manifest and
# Compose file into incoming/<release-id> before invoking activate.
command_name="${1:-}"
app_dir="${2:-}"
release_id="${3:-}"

die() { echo "deploy-app: $*" >&2; exit 1; }
[[ "$command_name" == activate || "$command_name" == rollback || "$command_name" == finalize ]] || die 'expected activate, rollback or finalize'
[[ -d "$app_dir" ]] || die 'application directory is missing'
environment="$(basename "$app_dir")"
[[ "$environment" == staging || "$environment" == production ]] || die 'unexpected application directory'
if [[ "$command_name" == activate || "$command_name" == finalize || -n "$release_id" ]]; then
  [[ "$release_id" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,100}$ ]] || die 'invalid release id'
fi

release_dir="$app_dir/releases"
web_dir="$app_dir/web"
mkdir -p "$release_dir" "$web_dir/releases"

manifest_value() {
  local file="$1" name="$2" value
  value="$(sed -n "s/^${name}=//p" "$file")"
  [[ -n "$value" && "$(grep -c "^${name}=" "$file")" == 1 ]] || die "missing or duplicate $name"
  printf '%s' "$value"
}

release_path() {
  local link="$1" target
  [[ -f "$link" ]] || die "missing release pointer: $link"
  target="$(cat "$link")"
  [[ "$target" =~ ^releases/[a-zA-Z0-9][a-zA-Z0-9.-]{0,100}$ ]] || die "invalid release pointer: $link"
  [[ -f "$app_dir/$target/release-manifest.txt" ]] || die "release manifest is missing: $target"
  printf '%s' "$app_dir/$target"
}

point_to() {
  local name="$1" id="$2" temp
  temp="$app_dir/.${name}.$$"
  printf 'releases/%s\n' "$id" > "$temp"
  mv -f "$temp" "$app_dir/$name"
}

write_index() {
  local id="$1" temp="$web_dir/.index.$$"
  if [[ "$id" == legacy-* ]]; then
    cp "$web_dir/releases/$id/index.html" "$temp"
  else
    cat > "$temp" <<EOF
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=/releases/$id/index.html">
<title>OpenGameBuilder</title></head><body>
<script>location.replace('/releases/$id/index.html')</script>
<a href="/releases/$id/index.html">Open OpenGameBuilder</a>
</body></html>
EOF
  fi
  # The old in-place Blazor publish has precompressed index sidecars. Caddy
  # prefers them over a newly replaced index.html, so clear them before the
  # atomic index replacement (also when restoring the legacy page).
  rm -f "$web_dir/index.html.br" "$web_dir/index.html.gz" "$web_dir/index.html.zst"
  mv -f "$temp" "$web_dir/index.html"
}

start_release() {
  local path="$1" pull_image="${2:-false}"
  if [[ "$pull_image" == true ]]; then
    docker compose --env-file "$path/.env" -f "$path/compose.yml" pull || return
  fi
  docker compose --env-file "$path/.env" -f "$path/compose.yml" up -d --pull never
}

restore_release() {
  local path="$1" id
  id="$(basename "$path")"
  start_release "$path" || die "failed to restart previous API from $id; manual recovery required"
  write_index "$id"
  point_to current "$id"
  cp "$path/release-manifest.txt" "$app_dir/.release-manifest.$$"
  mv -f "$app_dir/.release-manifest.$$" "$app_dir/release-manifest.txt"
}

if [[ "$command_name" == rollback ]]; then
  if [[ -n "$release_id" ]]; then
    [[ -f "$app_dir/pending" ]] || { echo 'No pending activation to recover.'; exit 0; }
    [[ "$(cat "$app_dir/pending")" == "$release_id" ]] || die 'pending release differs from requested rollback'
  fi
  previous="$(release_path "$app_dir/previous")"
  restore_release "$previous"
  rm "$app_dir/previous"
  rm -f "$app_dir/pending"
  echo "Restored $(basename "$previous") without rebuilding."
  exit 0
fi

if [[ "$command_name" == finalize ]]; then
  [[ "$(cat "$app_dir/pending")" == "$release_id" ]] || die 'pending release differs from deployed release'
  [[ "$(basename "$(release_path "$app_dir/current")")" == "$release_id" ]] || die 'current release differs from smoke-tested release'
  rm "$app_dir/pending"
  echo "Finalized $release_id"
  exit 0
fi

incoming="$app_dir/incoming/$release_id"
manifest="$incoming/release-manifest.txt"
[[ -f "$manifest" && -f "$incoming/web-release.tar.gz" && -f "$incoming/compose.yml" ]] || die 'incomplete incoming release'
[[ "$(manifest_value "$manifest" RELEASE_ID)" == "$release_id" ]] || die 'release id mismatch'
source_sha="$(manifest_value "$manifest" SOURCE_SHA)"
api_image="$(manifest_value "$manifest" API_IMAGE)"
web_sha="$(manifest_value "$manifest" WEB_SHA256)"
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || die 'invalid source SHA'
[[ "$api_image" =~ ^ghcr\.io/[a-z0-9_./-]+@sha256:[0-9a-f]{64}$ ]] || die 'API image must be a registry digest'
[[ "$web_sha" =~ ^[0-9a-f]{64}$ ]] || die 'invalid web checksum'
echo "$web_sha  $incoming/web-release.tar.gz" | sha256sum --check --status || die 'web archive checksum mismatch'

docker network inspect ogb-edge >/dev/null || die 'host edge network is missing'
mapfile -t proxy_networks < <(
  docker network inspect ogb-edge \
    --format '{{range .IPAM.Config}}{{if .Subnet}}{{println .Subnet}}{{end}}{{end}}'
)
[[ "${#proxy_networks[@]}" -gt 0 ]] || die 'host edge network has no configured subnet'
printf -v trusted_proxy_networks '%s;' "${proxy_networks[@]}"
trusted_proxy_networks="${trusted_proxy_networks%;}"

# Reject paths that could escape the release directory before extracting.
while IFS= read -r entry; do
  [[ "$entry" != /* && "$entry" != ../* && "$entry" != */../* && "$entry" != */.. ]] || die 'unsafe archive path'
done < <(tar -tzf "$incoming/web-release.tar.gz")

candidate="$release_dir/$release_id"
candidate_web="$web_dir/releases/$release_id"
[[ ! -e "$candidate" && ! -e "$candidate_web" ]] || die 'release id already exists'
temp_release="$release_dir/.${release_id}.$$"
temp_web="$web_dir/releases/.${release_id}.$$"
mkdir "$temp_release" "$temp_web"
cp "$manifest" "$temp_release/release-manifest.txt"
cp "$incoming/compose.yml" "$temp_release/compose.yml"
printf 'API_IMAGE=%s\nSOURCE_SHA=%s\nTRUSTED_PROXY_NETWORKS=%s\n' \
  "$api_image" "$source_sha" "$trusted_proxy_networks" > "$temp_release/.env"
tar -xzf "$incoming/web-release.tar.gz" -C "$temp_web"
[[ -f "$temp_web/index.html" ]] || die 'web archive lacks index.html'
grep -Fq "<base href=\"/releases/$release_id/\"" "$temp_web/index.html" || die 'web base path does not match release id'
# Reject stale compressed HTML even if a separately produced archive included it.
rm -f "$temp_web/index.html.br" "$temp_web/index.html.gz" "$temp_web/index.html.zst"
mv "$temp_release" "$candidate"
mv "$temp_web" "$candidate_web"

# The first rollout preserves the in-place installation as a rollback target.
if [[ ! -f "$app_dir/current" && -f "$app_dir/release-manifest.txt" ]]; then
  legacy_sha="$(manifest_value "$app_dir/release-manifest.txt" SOURCE_SHA)"
  [[ "$legacy_sha" =~ ^[0-9a-f]{40}$ ]] || die 'invalid legacy source SHA'
  legacy_id="legacy-${legacy_sha:0:12}"
  legacy="$release_dir/$legacy_id"
  [[ ! -e "$legacy" ]] || die 'legacy release already exists without a current pointer'
  mkdir "$legacy" "$web_dir/releases/$legacy_id"
  cp "$app_dir/release-manifest.txt" "$legacy/release-manifest.txt"
  cp "$app_dir/compose.yml" "$app_dir/.env" "$legacy/"
  tar -C "$web_dir" --exclude='./releases' -cf - . | tar -C "$web_dir/releases/$legacy_id" -xf -
  point_to current "$legacy_id"
fi

old=""
if [[ -f "$app_dir/current" ]]; then
  old="$(release_path "$app_dir/current")"
fi
[[ ! -e "$app_dir/pending" ]] || die 'another activation requires recovery'
if [[ -n "$old" ]]; then point_to previous "$(basename "$old")"; fi
printf '%s\n' "$release_id" > "$app_dir/pending"
if ! start_release "$candidate" true; then
  die 'new API failed; recovery will restore the recorded previous release'
fi

write_index "$release_id"
point_to current "$release_id"
cp "$manifest" "$app_dir/.release-manifest.$$"
mv -f "$app_dir/.release-manifest.$$" "$app_dir/release-manifest.txt"
echo "Activated $release_id; previous release: ${old:-none}"
