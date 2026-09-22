#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
app_dir="$test_root/staging"
mkdir -p "$test_root/bin" "$app_dir/web" "$app_dir/incoming"
export PATH="$test_root/bin:$PATH" DOCKER_CALLS="$test_root/docker-calls" DOCKER_ACTIVE="$test_root/docker-active"

cat > "$test_root/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCKER_CALLS"
if [[ "$*" == *'network inspect ogb-edge --format'* ]]; then
  printf '%s\n' '172.30.0.0/24'
fi
if [[ "$*" == *'up -d'* ]]; then
  # Compose can start the candidate before reporting an unhealthy service.
  printf '%s\n' "$*" > "$DOCKER_ACTIVE"
  if [[ -n "${FAIL_RELEASE:-}" && "$*" == *"$FAIL_RELEASE"* ]]; then exit 1; fi
fi
if [[ "$*" == *'logs --no-color'* ]]; then
  printf 'candidate API diagnostics\n'
fi
if [[ "$*" == *' down'* ]]; then
  if [[ -n "${FAIL_CLEANUP:-}" && "$*" == *"$FAIL_CLEANUP"* ]]; then
    printf 'candidate cleanup failed\n' >&2
    exit 1
  fi
  rm -f "$DOCKER_ACTIVE"
fi
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
  printf 'stale compressed index\n' > "$source/index.html.br"
  printf 'stale compressed index\n' > "$source/index.html.gz"
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
printf 'old compressed index\n' > "$app_dir/web/index.html.br"
printf 'old compressed index\n' > "$app_dir/web/index.html.gz"
printf 'legacy asset\n' > "$app_dir/web/old-asset.txt"

sha_a="$(printf '2%.0s' {1..40})"
make_release 101-1-222222222222 "$sha_a"
run_app activate 101-1-222222222222 >/dev/null
[[ "$(cat "$app_dir/current")" == releases/101-1-222222222222 ]] || fail 'new release was not activated'
[[ "$(cat "$app_dir/previous")" == releases/legacy-111111111111 ]] || fail 'legacy release was not retained'
grep -Fq '/releases/101-1-222222222222/' "$app_dir/web/index.html" || fail 'root redirect was not activated'
grep -Fq '/releases/101-1-222222222222/index.html' "$app_dir/web/index.html" || fail 'root redirect must target an existing file'
[[ ! -e "$app_dir/web/index.html.br" && ! -e "$app_dir/web/index.html.gz" ]] || fail 'old compressed index could shadow root redirect'
[[ ! -e "$app_dir/web/releases/101-1-222222222222/index.html.br" && ! -e "$app_dir/web/releases/101-1-222222222222/index.html.gz" ]] || fail 'compressed release index could shadow the rewritten base path'
[[ -f "$app_dir/web/old-asset.txt" && -f "$app_dir/web/releases/101-1-222222222222/asset-101-1-222222222222.txt" ]] || fail 'older browser assets were lost'
grep -Fxq 'TRUSTED_PROXY_NETWORKS=172.30.0.0/24' "$app_dir/releases/101-1-222222222222/.env" || fail 'release did not record the isolated proxy network'
run_app finalize 101-1-222222222222 >/dev/null
echo 'PASS activation retains legacy content and records the API digest and proxy network'

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

fresh_app() {
  app_dir="$test_root/$1/staging"
  mkdir -p "$app_dir/incoming"
  export DOCKER_CALLS="$test_root/$1/docker-calls" DOCKER_ACTIVE="$test_root/$1/docker-active"
  : > "$DOCKER_CALLS"
  unset FAIL_RELEASE FAIL_CLEANUP
}

assert_undeployed() {
  local id="$1" index_expected="${2:-true}" file
  [[ ! -e "$DOCKER_ACTIVE" ]] || fail 'initial recovery left the candidate API running'
  for file in pending current previous release-manifest.txt web/index.html web/index.html.br web/index.html.gz web/index.html.zst; do
    [[ ! -e "$app_dir/$file" ]] || fail "initial recovery left live state: $file"
  done
  [[ "$(cat "$app_dir/releases/$id/predecessor")" == none ]] || fail 'initial recovery lost its explicit predecessor state'
  [[ -f "$app_dir/releases/$id/release-manifest.txt" && -f "$app_dir/releases/$id/compose.yml" && -f "$app_dir/releases/$id/.env" ]] || fail 'initial recovery removed candidate diagnostics'
  [[ -f "$app_dir/web/releases/$id/asset-$id.txt" && -f "$app_dir/incoming/$id/web-release.tar.gz" ]] || fail 'initial recovery removed the failed release artifacts'
  if [[ "$index_expected" == true ]]; then
    [[ -f "$app_dir/web/releases/$id/index.html" ]] || fail 'initial recovery removed the candidate index'
  fi
  grep -Fq 'candidate API diagnostics' "$app_dir/releases/$id/recovery.log" || fail 'initial recovery did not retain candidate logs'
  grep -F "releases/$id/.env" "$DOCKER_CALLS" | grep -Fq ' down' || fail 'initial recovery did not clean up the recorded candidate'
}

assert_retry_succeeds() {
  local id="$1" sha="$2"
  unset FAIL_RELEASE FAIL_CLEANUP
  make_release "$id" "$sha"
  run_app activate "$id" >/dev/null
  [[ "$(cat "$app_dir/current")" == "releases/$id" ]] || fail 'retry did not activate the new release'
  [[ "$(cat "$app_dir/releases/$id/predecessor")" == none && ! -e "$app_dir/previous" ]] || fail 'retry invented a deployed predecessor'
  grep -Fq "releases/$id/.env" "$DOCKER_ACTIVE" || fail 'retry did not start the new API'
  grep -Fq "/releases/$id/index.html" "$app_dir/web/index.html" || fail 'retry did not publish the new root redirect'
  run_app finalize "$id" >/dev/null
  [[ ! -e "$app_dir/pending" ]] || fail 'successful retry was not finalized'
}

fresh_app first-start
first_id=201-1-555555555555
make_release "$first_id" "$(printf '5%.0s' {1..40})"
export FAIL_RELEASE="$first_id"
if run_app activate "$first_id" >/dev/null 2>&1; then fail 'first API startup failure passed'; fi
[[ -f "$DOCKER_ACTIVE" ]] || fail 'startup failure fixture did not partially start the API'
[[ "$(cat "$app_dir/pending")" == "$first_id" ]] || fail 'first API startup failure lost pending state'
run_app rollback "$first_id" >/dev/null
assert_undeployed "$first_id"
assert_retry_succeeds 202-1-666666666666 "$(printf '6%.0s' {1..40})"
echo 'PASS failed first API startup stops the partial candidate and permits a new-release retry'

fresh_app first-smoke
first_id=301-1-777777777777
make_release "$first_id" "$(printf '7%.0s' {1..40})"
run_app activate "$first_id" >/dev/null
[[ "$(cat "$app_dir/current")" == "releases/$first_id" && -f "$app_dir/release-manifest.txt" ]] || fail 'smoke failure fixture was not activated'
for suffix in br gz zst; do printf 'stale compressed index\n' > "$app_dir/web/index.html.$suffix"; done
# The workflow requests rollback when its post-activation browser smoke fails.
run_app rollback "$first_id" >/dev/null
assert_undeployed "$first_id"
assert_retry_succeeds 302-1-888888888888 "$(printf '8%.0s' {1..40})"
echo 'PASS first-deployment smoke failure clears published state and permits a new-release retry'

fresh_app failed-cleanup
first_id=401-1-999999999999
make_release "$first_id" "$(printf '9%.0s' {1..40})"
run_app activate "$first_id" >/dev/null
cp "$app_dir/web/index.html" "$test_root/failed-cleanup/index-before"
cp "$app_dir/release-manifest.txt" "$test_root/failed-cleanup/manifest-before"
export FAIL_CLEANUP="$first_id"
if run_app rollback "$first_id" >/dev/null 2>&1; then fail 'failed initial cleanup passed'; fi
[[ -f "$DOCKER_ACTIVE" && "$(cat "$app_dir/pending")" == "$first_id" ]] || fail 'failed cleanup lost its running candidate or pending state'
[[ "$(cat "$app_dir/current")" == "releases/$first_id" && "$(cat "$app_dir/releases/$first_id/predecessor")" == none ]] || fail 'failed cleanup changed current or transaction state'
grep -Fq 'candidate API diagnostics' "$app_dir/releases/$first_id/recovery.log" || fail 'failed cleanup lost candidate logs'
grep -Fq 'candidate cleanup failed' "$app_dir/releases/$first_id/recovery.log" || fail 'failed cleanup did not record its failure'
cmp -s "$app_dir/web/index.html" "$test_root/failed-cleanup/index-before" || fail 'failed cleanup changed the root index'
cmp -s "$app_dir/release-manifest.txt" "$test_root/failed-cleanup/manifest-before" || fail 'failed cleanup changed the live manifest'
retry_id=402-1-aaaaaaaaaaaa
make_release "$retry_id" "$(printf 'a%.0s' {1..40})"
calls_before="$(wc -l < "$DOCKER_CALLS")"
if run_app activate "$retry_id" >/dev/null 2>&1; then fail 'unrecovered initial activation permitted another activation'; fi
[[ "$(cat "$app_dir/pending")" == "$first_id" ]] || fail 'blocked activation changed the pending release'
[[ ! -e "$app_dir/releases/$retry_id" && ! -e "$app_dir/web/releases/$retry_id" ]] || fail 'blocked activation staged another candidate'
[[ "$(wc -l < "$DOCKER_CALLS")" == "$calls_before" ]] || fail 'blocked activation contacted Docker'
unset FAIL_CLEANUP
run_app rollback "$first_id" >/dev/null
assert_undeployed "$first_id"
assert_retry_succeeds "$retry_id" "$(printf 'a%.0s' {1..40})"
echo 'PASS failed cleanup retains recovery state and blocks activation until cleanup succeeds'

fresh_app missing-candidate-index
first_id=601-1-dddddddddddd
make_release "$first_id" "$(printf 'd%.0s' {1..40})"
run_app activate "$first_id" >/dev/null
rm "$app_dir/web/releases/$first_id/index.html"
run_app rollback "$first_id" >/dev/null
assert_undeployed "$first_id" false
echo 'PASS initial recovery stops the API even when the candidate web index is missing'

fresh_app failed-file-cleanup
first_id=701-1-eeeeeeeeeeee
make_release "$first_id" "$(printf 'e%.0s' {1..40})"
run_app activate "$first_id" >/dev/null
mv "$app_dir/web/index.html" "$test_root/failed-file-cleanup/index-before"
mkdir "$app_dir/web/index.html"
if run_app rollback "$first_id" >/dev/null 2>&1; then fail 'failed initial file cleanup passed'; fi
[[ ! -e "$DOCKER_ACTIVE" ]] || fail 'file cleanup failure fixture did not stop the candidate API'
[[ "$(cat "$app_dir/pending")" == "$first_id" && -d "$app_dir/web/index.html" ]] || fail 'failed file cleanup lost pending state or ignored the root index directory'
[[ "$(cat "$app_dir/releases/$first_id/predecessor")" == none ]] || fail 'failed file cleanup lost transaction state'
grep -Fq 'candidate API diagnostics' "$app_dir/releases/$first_id/recovery.log" || fail 'failed file cleanup lost candidate logs'
rmdir "$app_dir/web/index.html"
run_app rollback "$first_id" >/dev/null
assert_undeployed "$first_id"
echo 'PASS failed file cleanup retains pending until a later recovery removes the live files'

fresh_app expected-predecessor
old_id=501-1-bbbbbbbbbbbb
candidate_id=502-1-cccccccccccc
make_release "$old_id" "$(printf 'b%.0s' {1..40})"
run_app activate "$old_id" >/dev/null
run_app finalize "$old_id" >/dev/null
make_release "$candidate_id" "$(printf 'c%.0s' {1..40})"
run_app activate "$candidate_id" >/dev/null
[[ "$(cat "$app_dir/releases/$candidate_id/predecessor")" == "releases/$old_id" ]] || fail 'upgrade did not record its expected predecessor'
cp "$app_dir/web/index.html" "$test_root/expected-predecessor/index-before"
cp "$app_dir/release-manifest.txt" "$test_root/expected-predecessor/manifest-before"

assert_recovery_blocked() {
  local reason="$1" calls_before
  calls_before="$(wc -l < "$DOCKER_CALLS")"
  if run_app rollback "$candidate_id" >/dev/null 2>&1; then fail "$reason allowed recovery without a valid predecessor"; fi
  [[ "$(cat "$app_dir/pending")" == "$candidate_id" && "$(cat "$app_dir/current")" == "releases/$candidate_id" ]] || fail "$reason changed deployment pointers"
  [[ "$(wc -l < "$DOCKER_CALLS")" == "$calls_before" ]] || fail "$reason changed running services"
  cmp -s "$app_dir/web/index.html" "$test_root/expected-predecessor/index-before" || fail "$reason changed the root index"
  cmp -s "$app_dir/release-manifest.txt" "$test_root/expected-predecessor/manifest-before" || fail "$reason changed the live manifest"
}

mv "$app_dir/previous" "$test_root/expected-predecessor/previous-before"
assert_recovery_blocked 'missing previous pointer'
printf '../unexpected\n' > "$app_dir/previous"
assert_recovery_blocked 'corrupt previous pointer'
printf 'releases/%s\n' "$candidate_id" > "$app_dir/previous"
assert_recovery_blocked 'previous pointer differing from recorded predecessor'
mv "$test_root/expected-predecessor/previous-before" "$app_dir/previous"
mv "$app_dir/releases/$old_id/release-manifest.txt" "$test_root/expected-predecessor/old-manifest-before"
assert_recovery_blocked 'missing predecessor manifest'
printf 'corrupt\n' > "$app_dir/releases/$old_id/release-manifest.txt"
assert_recovery_blocked 'corrupt predecessor manifest'
mv "$test_root/expected-predecessor/old-manifest-before" "$app_dir/releases/$old_id/release-manifest.txt"
mv "$app_dir/releases/$candidate_id/predecessor" "$test_root/expected-predecessor/predecessor-before"
assert_recovery_blocked 'missing transaction state'
printf 'invalid\n' > "$app_dir/releases/$candidate_id/predecessor"
assert_recovery_blocked 'corrupt transaction state'
mv "$test_root/expected-predecessor/predecessor-before" "$app_dir/releases/$candidate_id/predecessor"
run_app rollback "$candidate_id" >/dev/null
[[ "$(cat "$app_dir/current")" == "releases/$old_id" && ! -e "$app_dir/pending" ]] || fail 'repaired predecessor did not restore the upgrade'
grep -Fq "releases/$old_id/.env" "$DOCKER_ACTIVE" || fail 'repaired predecessor did not restart the old API'
echo 'PASS missing or corrupt expected predecessor fails safely and can be recovered after repair'
