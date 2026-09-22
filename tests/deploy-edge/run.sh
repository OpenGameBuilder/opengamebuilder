#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/candidate" "$test_root/active"
export EDGE_DIR="$test_root/active"
export DOCKER_CALLS="$test_root/docker-calls"
export PATH="$test_root/bin:$PATH"

cat > "$test_root/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCKER_CALLS"
case "$*" in
  *'config --images') printf '%s\n' 'caddy:2' ;;
  *'validate --config'*) [[ "${FAIL_VALIDATE:-0}" != 1 ]] ;;
  *'exec -T caddy caddy reload'*) [[ "${FAIL_RELOAD:-0}" != 1 ]] ;;
  *'ps -q caddy') if [[ "${CADDY_RUNNING:-1}" == 1 ]]; then printf '%s\n' caddy-id; fi ;;
  *'up -d')
    for environment in ${EXPECTED_WEB_ENVIRONMENTS:-}; do
      [[ -d "$EDGE_DIR/../$environment/web" ]] || exit 1
    done
    [[ "${FAIL_UP:-0}" != 1 ]]
    ;;
  *'network inspect ogb-edge') [[ "${NETWORK_EXISTS:-1}" == 1 ]] ;;
esac
EOF
chmod +x "$test_root/bin/docker"

fail() { echo "FAIL: $*" >&2; exit 1; }
write_profile() {
  local default_config='example.com { respond "ok" }'
  printf '# ogb-edge-profile: %s\n%s\n' "$2" "${3:-$default_config}" > "$1"
}
reset_fixture() {
  rm -f "$DOCKER_CALLS" "$EDGE_DIR/compose.yml" "$EDGE_DIR/Caddyfile"
  rm -rf "$test_root/staging" "$test_root/production"
  printf 'name: ogb-edge\nservices:\n  caddy:\n    image: caddy:2\n' > "$EDGE_DIR/compose.yml"
  write_profile "$EDGE_DIR/Caddyfile" shared 'old.example.com { respond "old" }'
  cp "$EDGE_DIR/compose.yml" "$test_root/candidate/compose.yml"
  write_profile "$test_root/candidate/Caddyfile" shared 'new.example.com { respond "new" }'
  unset FAIL_VALIDATE FAIL_RELOAD FAIL_UP EXPECTED_WEB_ENVIRONMENTS
  export CADDY_RUNNING=1 NETWORK_EXISTS=1
}
run_apply() { bash "$repo_root/scripts/apply-edge.sh" "$test_root/candidate" "${1:-production}" "${2:-false}"; }
run_verify() { bash "$repo_root/scripts/verify-edge-profile.sh" "$EDGE_DIR" "$1"; }
assert_called() { grep -Fq -- "$1" "$DOCKER_CALLS" || fail "missing Docker call: $1"; }
assert_not_called() { if grep -Fq -- "$1" "$DOCKER_CALLS"; then fail "unexpected Docker call: $1"; fi; }
assert_rejected_without_mutation() {
  local expected_error="$1"
  shift
  cp "$EDGE_DIR/compose.yml" "$test_root/expected-compose.yml"
  cp "$EDGE_DIR/Caddyfile" "$test_root/expected-Caddyfile"
  if "$@" > "$test_root/rejection.log" 2>&1; then fail 'unsafe edge operation was accepted'; fi
  grep -Fq "$expected_error" "$test_root/rejection.log" || fail "expected error: $expected_error"
  [[ ! -s "$DOCKER_CALLS" ]] || fail 'rejected profile operation called Docker'
  [[ ! -e "$test_root/staging" && ! -e "$test_root/production" ]] || fail 'rejected profile operation created application directories'
  cmp -s "$test_root/expected-compose.yml" "$EDGE_DIR/compose.yml" || fail 'rejected profile operation changed Compose file'
  cmp -s "$test_root/expected-Caddyfile" "$EDGE_DIR/Caddyfile" || fail 'rejected profile operation changed Caddyfile'
}

reset_fixture
assert_rejected_without_mutation 'Deployment environment is required' \
  bash "$repo_root/scripts/apply-edge.sh" "$test_root/candidate"
assert_rejected_without_mutation 'Expected deployment environment staging or production' run_apply development
assert_rejected_without_mutation 'Expected allow-profile-change to be true or false' run_apply production yes
echo 'PASS edge application requires a valid environment and explicit boolean override'

for missing_file in compose.yml Caddyfile; do
  reset_fixture
  rm "$test_root/candidate/$missing_file"
  assert_rejected_without_mutation 'Edge candidate requires compose.yml and Caddyfile' run_apply
done
echo 'PASS incomplete candidates do not touch Docker or application directories'

reset_fixture
printf 'unmarked.example.com { respond "old" }\n' > "$test_root/candidate/Caddyfile"
assert_rejected_without_mutation 'Candidate Caddyfile requires an edge profile marker' run_apply
for marker in \
  '# ogb-edge-profile: invalid' \
  '# ogb-edge-profile: shared ' \
  '# ogb-edge-profile:shared' \
  $'# another comment\n# ogb-edge-profile: shared' \
  $'# ogb-edge-profile: shared\n# ogb-edge-profile: shared'; do
  printf '%s\nexample.com { respond "ok" }\n' "$marker" > "$test_root/candidate/Caddyfile"
  assert_rejected_without_mutation 'Invalid edge profile marker' run_apply
done
echo 'PASS missing malformed misplaced and duplicate candidate markers are rejected'

reset_fixture
write_profile "$test_root/candidate/Caddyfile" staging
assert_rejected_without_mutation 'does not include deployment environment production' run_apply production
assert_rejected_without_mutation 'does not include deployment environment production' run_apply production true
write_profile "$test_root/candidate/Caddyfile" production
assert_rejected_without_mutation 'does not include deployment environment staging' run_apply staging
assert_rejected_without_mutation 'does not include deployment environment staging' run_apply staging true
write_profile "$test_root/candidate/Caddyfile" shared
assert_rejected_without_mutation 'Shared edge updates require the production environment' run_apply staging
assert_rejected_without_mutation 'Shared edge updates require the production environment' run_apply staging true
echo 'PASS candidate scope must match its environment and shared edge needs production approval'

for active_profile in shared production; do
  reset_fixture
  write_profile "$EDGE_DIR/Caddyfile" "$active_profile"
  write_profile "$test_root/candidate/Caddyfile" staging
  assert_rejected_without_mutation 'Changing the installed edge profile requires' run_apply staging
  run_apply staging true >/dev/null
  grep -Fxq '# ogb-edge-profile: staging' "$EDGE_DIR/Caddyfile" || fail 'approved profile change did not install staging marker'
  assert_called 'exec -T caddy caddy reload'
done
echo 'PASS staging can replace shared or production edge profiles only after explicit production authorization'

for active_profile in shared staging; do
  reset_fixture
  write_profile "$EDGE_DIR/Caddyfile" "$active_profile"
  write_profile "$test_root/candidate/Caddyfile" production
  assert_rejected_without_mutation 'Changing the installed edge profile requires' run_apply production
  run_apply production true >/dev/null
  grep -Fxq '# ogb-edge-profile: production' "$EDGE_DIR/Caddyfile" || fail 'approved profile change did not install production marker'
  assert_called 'exec -T caddy caddy reload'
done
reset_fixture
write_profile "$EDGE_DIR/Caddyfile" production
assert_rejected_without_mutation 'Changing the installed edge profile requires' run_apply production
run_apply production true >/dev/null
grep -Fxq '# ogb-edge-profile: shared' "$EDGE_DIR/Caddyfile" || fail 'approved profile change did not install shared marker'
echo 'PASS changing an installed profile requires explicit production-authorized migration'

reset_fixture
printf 'legacy.example.com { respond "old" }\n' > "$EDGE_DIR/Caddyfile"
write_profile "$test_root/candidate/Caddyfile" staging
assert_rejected_without_mutation 'Unmarked legacy edge can only adopt the shared profile through production' run_apply staging true
write_profile "$test_root/candidate/Caddyfile" production
assert_rejected_without_mutation 'Unmarked legacy edge can only adopt the shared profile through production' run_apply production true
write_profile "$test_root/candidate/Caddyfile" shared
run_apply production >/dev/null
grep -Fxq '# ogb-edge-profile: shared' "$EDGE_DIR/Caddyfile" || fail 'legacy shared edge was not marked'
echo 'PASS unmarked legacy edge can only adopt shared profile through production'

for marker in \
  '# ogb-edge-profile: invalid' \
  $'# another comment\n# ogb-edge-profile: shared' \
  $'# ogb-edge-profile: shared\n# ogb-edge-profile: production'; do
  reset_fixture
  printf '%s\nexample.com { respond "ok" }\n' "$marker" > "$EDGE_DIR/Caddyfile"
  assert_rejected_without_mutation 'Invalid edge profile marker' run_apply production true
done
echo 'PASS malformed installed profiles cannot be overridden'

for profile in staging production; do
  reset_fixture
  rm "$EDGE_DIR/compose.yml" "$EDGE_DIR/Caddyfile"
  write_profile "$test_root/candidate/Caddyfile" "$profile"
  export CADDY_RUNNING=0 NETWORK_EXISTS=0 EXPECTED_WEB_ENVIRONMENTS="$profile"
  run_apply "$profile" >/dev/null
  grep -Fxq "# ogb-edge-profile: $profile" "$EDGE_DIR/Caddyfile" || fail 'fresh host received incorrect profile'
  [[ -d "$test_root/$profile/web" ]] || fail 'fresh edge setup did not create its web root'
  if [[ "$profile" == staging ]]; then other_profile=production; else other_profile=staging; fi
  [[ ! -e "$test_root/$other_profile" ]] || fail 'isolated edge setup created the other environment directory'
  assert_called 'up -d'
done
echo 'PASS fresh hosts install isolated edge profiles and create only their own web roots'

for profile in production staging; do
  reset_fixture
  write_profile "$test_root/candidate/Caddyfile" "$profile"
  export FAIL_RELOAD=1
  if run_apply "$profile" true >/dev/null 2>&1; then fail 'failed profile migration was reported as success'; fi
  assert_called 'exec -T caddy caddy reload'
  grep -Fxq '# ogb-edge-profile: shared' "$EDGE_DIR/Caddyfile" || fail 'failed migration did not restore profile marker'
  grep -Fq 'old.example.com' "$EDGE_DIR/Caddyfile" || fail 'failed migration did not restore previous configuration'
done
echo 'PASS failed migration restores the installed profile marker with its configuration'

for profile in shared staging production; do
  reset_fixture
  write_profile "$EDGE_DIR/Caddyfile" "$profile"
  run_verify "$profile" >/dev/null
  for expected_profile in shared staging production; do
    if [[ "$expected_profile" != "$profile" ]]; then
      assert_rejected_without_mutation 'does not match expected profile' run_verify "$expected_profile"
    fi
  done
  [[ ! -s "$DOCKER_CALLS" ]] || fail 'profile verification called Docker'
done
echo 'PASS application preflight checks exact marked profile without Docker or mutations'

reset_fixture
printf 'legacy.example.com { respond "old" }\n' > "$EDGE_DIR/Caddyfile"
run_verify shared >/dev/null
assert_rejected_without_mutation 'Unmarked legacy edge is only valid for the shared profile' run_verify staging
assert_rejected_without_mutation 'Unmarked legacy edge is only valid for the shared profile' run_verify production
assert_rejected_without_mutation 'Expected edge profile shared staging or production' run_verify invalid
echo 'PASS preflight accepts legacy unmarked edge only for explicitly expected shared profile'

for marker in \
  '# ogb-edge-profile: invalid' \
  $'# another comment\n# ogb-edge-profile: shared' \
  $'# ogb-edge-profile: shared\n# ogb-edge-profile: shared'; do
  reset_fixture
  printf '%s\nexample.com { respond "ok" }\n' "$marker" > "$EDGE_DIR/Caddyfile"
  assert_rejected_without_mutation 'Invalid edge profile marker' run_verify shared
done
for missing_file in compose.yml Caddyfile; do
  reset_fixture
  rm "$EDGE_DIR/$missing_file"
  if run_verify shared > "$test_root/rejection.log" 2>&1; then fail 'incomplete edge installation passed preflight'; fi
  grep -Fq 'Edge installation requires compose.yml and Caddyfile' "$test_root/rejection.log" || fail 'preflight did not report incomplete installation'
  [[ ! -s "$DOCKER_CALLS" ]] || fail 'preflight called Docker for incomplete installation'
done
echo 'PASS preflight rejects malformed markers and incomplete edge installations'

reset_fixture
export FAIL_VALIDATE=1 CADDY_RUNNING=0 NETWORK_EXISTS=0
if run_apply >/dev/null 2>&1; then fail 'invalid candidate was accepted'; fi
grep -Fq 'old.example.com' "$EDGE_DIR/Caddyfile" || fail 'invalid candidate replaced active configuration'
assert_not_called 'exec -T caddy caddy reload'
assert_not_called 'up -d'
assert_not_called 'network create ogb-edge'
[[ ! -e "$test_root/staging" && ! -e "$test_root/production" ]] || fail 'invalid candidate created application directories'
echo 'PASS invalid candidate preserves active edge'

reset_fixture
cp "$EDGE_DIR/Caddyfile" "$test_root/candidate/Caddyfile"
run_apply >/dev/null
assert_not_called 'up -d'
assert_not_called 'exec -T caddy caddy reload'
assert_not_called 'network create ogb-edge'
echo 'PASS unchanged running edge is left alone'

reset_fixture
cp "$EDGE_DIR/Caddyfile" "$test_root/candidate/Caddyfile"
export CADDY_RUNNING=0
run_apply >/dev/null
assert_called 'up -d'
assert_not_called 'exec -T caddy caddy reload'
cmp -s "$test_root/candidate/compose.yml" "$EDGE_DIR/compose.yml" || fail 'recovery changed active Compose file'
cmp -s "$test_root/candidate/Caddyfile" "$EDGE_DIR/Caddyfile" || fail 'recovery changed active Caddyfile'
echo 'PASS unchanged stopped edge starts with its existing configuration'

reset_fixture
cp "$EDGE_DIR/Caddyfile" "$test_root/candidate/Caddyfile"
export CADDY_RUNNING=0 FAIL_UP=1
if run_apply >/dev/null 2>&1; then fail 'failed edge recovery was reported as success'; fi
assert_called 'up -d'
cmp -s "$test_root/candidate/compose.yml" "$EDGE_DIR/compose.yml" || fail 'failed recovery changed active Compose file'
cmp -s "$test_root/candidate/Caddyfile" "$EDGE_DIR/Caddyfile" || fail 'failed recovery changed active Caddyfile'
echo 'PASS failed recovery preserves the existing edge configuration'

reset_fixture
run_apply >/dev/null
grep -Fq 'new.example.com' "$EDGE_DIR/Caddyfile" || fail 'valid candidate was not installed'
assert_called 'exec -T caddy caddy reload'
assert_not_called 'up -d'
echo 'PASS Caddyfile change reloads without recreating Caddy'

reset_fixture
export FAIL_RELOAD=1
if run_apply >/dev/null 2>&1; then fail 'failed reload was reported as success'; fi
grep -Fq 'old.example.com' "$EDGE_DIR/Caddyfile" || fail 'failed reload did not restore active file'
assert_not_called 'up -d'
echo 'PASS failed reload restores previous configuration'

reset_fixture
printf 'name: ogb-edge\nservices:\n  caddy:\n    image: caddy:2.1\n' > "$test_root/candidate/compose.yml"
run_apply >/dev/null
assert_called 'up -d'
assert_called 'exec -T caddy caddy reload'
echo 'PASS explicit Compose change updates the edge service'

reset_fixture
printf 'name: ogb-edge\nservices:\n  caddy:\n    image: caddy:2.1\n' > "$test_root/candidate/compose.yml"
export FAIL_UP=1
if run_apply >/dev/null 2>&1; then fail 'failed Compose update was reported as success'; fi
grep -Fxq '    image: caddy:2' "$EDGE_DIR/compose.yml" || fail 'failed Compose update did not restore active file'
grep -Fq 'old.example.com' "$EDGE_DIR/Caddyfile" || fail 'failed Compose update did not restore Caddyfile'
echo 'PASS failed Compose update restores previous files'

reset_fixture
rm "$EDGE_DIR/compose.yml" "$EDGE_DIR/Caddyfile"
export CADDY_RUNNING=0 NETWORK_EXISTS=0 EXPECTED_WEB_ENVIRONMENTS='staging production'
run_apply >/dev/null
assert_called 'network create ogb-edge'
assert_called 'up -d'
[[ -d "$test_root/staging/web" && -d "$test_root/production/web" ]] || fail 'shared edge setup did not create both web roots'
echo 'PASS initial edge setup creates the shared network and service'
