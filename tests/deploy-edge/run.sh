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
  *'ps -q caddy') [[ "${CADDY_RUNNING:-1}" == 1 ]] && printf '%s\n' caddy-id ;;
  *'up -d') [[ "${FAIL_UP:-0}" != 1 ]] ;;
  *'network inspect ogb-edge') [[ "${NETWORK_EXISTS:-1}" == 1 ]] ;;
esac
EOF
chmod +x "$test_root/bin/docker"

fail() { echo "FAIL: $*" >&2; exit 1; }
reset_fixture() {
  rm -f "$DOCKER_CALLS" "$EDGE_DIR/compose.yml" "$EDGE_DIR/Caddyfile"
  printf 'name: ogb-edge\nservices:\n  caddy:\n    image: caddy:2\n' > "$EDGE_DIR/compose.yml"
  printf 'old.example.com { respond "old" }\n' > "$EDGE_DIR/Caddyfile"
  cp "$EDGE_DIR/compose.yml" "$test_root/candidate/compose.yml"
  printf 'new.example.com { respond "new" }\n' > "$test_root/candidate/Caddyfile"
  unset FAIL_VALIDATE FAIL_RELOAD FAIL_UP
  export CADDY_RUNNING=1 NETWORK_EXISTS=1
}
run_apply() { bash "$repo_root/scripts/apply-edge.sh" "$test_root/candidate"; }
assert_called() { grep -Fq -- "$1" "$DOCKER_CALLS" || fail "missing Docker call: $1"; }
assert_not_called() { if grep -Fq -- "$1" "$DOCKER_CALLS"; then fail "unexpected Docker call: $1"; fi; }

reset_fixture
export FAIL_VALIDATE=1
if run_apply >/dev/null 2>&1; then fail 'invalid candidate was accepted'; fi
grep -Fq 'old.example.com' "$EDGE_DIR/Caddyfile" || fail 'invalid candidate replaced active configuration'
assert_not_called 'exec -T caddy caddy reload'
assert_not_called 'up -d'
echo 'PASS invalid candidate preserves active edge'

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
export CADDY_RUNNING=0 NETWORK_EXISTS=0
run_apply >/dev/null
assert_called 'network create ogb-edge'
assert_called 'up -d'
echo 'PASS initial edge setup creates the shared network and service'
