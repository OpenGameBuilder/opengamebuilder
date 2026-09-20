#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
app_dir="$test_root/staging"
mkdir -p "$test_root/bin" "$app_dir/web" "$app_dir/incoming"
export PATH="$test_root/bin:$PATH" DOCKER_CALLS="$test_root/docker-calls"

cat > "$test_root/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCKER_CALLS"
if [[ -n "${FAIL_RELEASE:-}" && "$*" == *'up -d'* && "$*" == *"$FAIL_RELEASE"* ]]; then exit 1; fi
EOF
chmod +x "$test_root/bin/docker"

fail() { echo "FAIL: $*" >&2; exit 1; }
run_app() { bash "$repo_root/scripts/deploy-app.sh" "$1" "$app_dir" "${2:-}"; }
make_release() {
  local id="$1" sha="$2" source incoming web_sha
  source="$test_root/source-$id"
  incoming="$app_dir/incoming/$id"
  mkdir -p "$source" "$incoming"
  printf '<html><head><base href="/releases/%s/" /></head></html>\n' "$id" > "$source/index.html"
  printf 'asset %s\n' "$id" > "$source/asset-$id.txt"
  tar -czf "$incoming/web-release.tar.gz" -C "$source" .
  web_sha="$(sha256sum "$incoming/web-release.tar.gz" | cut -d ' ' -f 1)"
  printf 'RELEASE_ID=%s\nSOURCE_SHA=%s\nAPI_IMAGE=ghcr.io/example/api@sha256:%s\nWEB_SHA256=%s\n' \
    "$id" "$sha" "$(printf 'a%.0s' {1..64})" "$web_sha" > "$incoming/release-manifest.txt"
  printf 'name: ogb-staging\nservices:\n  api:\n    image: ${API_IMAGE}\n' > "$incoming/compose.yml"
}

legacy_sha="$(printf '1%.0s' {1..40})"
printf 'SOURCE_SHA=%s\nAPI_IMAGE=ghcr.io/example/api@sha256:%s\nWEB_SHA256=%s\n' \
  "$legacy_sha" "$(printf 'b%.0s' {1..64})" "$(printf 'c%.0s' {1..64})" > "$app_dir/release-manifest.txt"
printf 'API_IMAGE=ghcr.io/example/api@sha256:%s\n' "$(printf 'b%.0s' {1..64})" > "$app_dir/.env"
printf 'name: ogb-staging\nservices:\n  api:\n    image: ${API_IMAGE}\n' > "$app_dir/compose.yml"
printf '<html>legacy page</html>\n' > "$app_dir/web/index.html"
printf 'legacy asset\n' > "$app_dir/web/old-asset.txt"

sha_a="$(printf '2%.0s' {1..40})"
make_release 101-1-222222222222 "$sha_a"
run_app activate 101-1-222222222222 >/dev/null
[[ "$(cat "$app_dir/current")" == releases/101-1-222222222222 ]] || fail 'new release was not activated'
[[ "$(cat "$app_dir/previous")" == releases/legacy-111111111111 ]] || fail 'legacy release was not retained'
grep -Fq '/releases/101-1-222222222222/' "$app_dir/web/index.html" || fail 'root redirect was not activated'
[[ -f "$app_dir/web/old-asset.txt" && -f "$app_dir/web/releases/101-1-222222222222/asset-101-1-222222222222.txt" ]] || fail 'older browser assets were lost'
run_app finalize 101-1-222222222222 >/dev/null
echo 'PASS activation retains legacy content and records the API digest'

run_app rollback >/dev/null
[[ "$(cat "$app_dir/current")" == releases/legacy-111111111111 ]] || fail 'rollback did not restore legacy release'
grep -Fq 'legacy page' "$app_dir/web/index.html" || fail 'rollback did not restore legacy index'
grep -Fq 'legacy-111111111111/.env' "$DOCKER_CALLS" || fail 'rollback did not restart the recorded legacy image'
echo 'PASS rollback restores the previous pair without rebuilding'

sha_b="$(printf '3%.0s' {1..40})"
make_release 102-1-333333333333 "$sha_b"
export FAIL_RELEASE=102-1-333333333333
if run_app activate 102-1-333333333333 >/dev/null 2>&1; then fail 'API startup failure passed'; fi
run_app rollback 102-1-333333333333 >/dev/null
[[ "$(cat "$app_dir/current")" == releases/legacy-111111111111 ]] || fail 'failed activation changed current release'
grep -Fq 'legacy page' "$app_dir/web/index.html" || fail 'failed activation changed root index'
echo 'PASS failed API update recovers the previous pair'

make_release 103-1-444444444444 "$(printf '4%.0s' {1..40})"
printf 'corruption' >> "$app_dir/incoming/103-1-444444444444/web-release.tar.gz"
if run_app activate 103-1-444444444444 >/dev/null 2>&1; then fail 'corrupt archive passed'; fi
[[ ! -f "$app_dir/pending" ]] || fail 'corrupt archive created a pending activation'
echo 'PASS archive mismatch fails before the live release changes'
