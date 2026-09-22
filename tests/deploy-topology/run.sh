#!/usr/bin/env bash
# These assertions match literal workflow expressions and shell source text.
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
resolver="$repo_root/scripts/resolve-edge-profile.sh"
renderer="$repo_root/scripts/render-edge.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}
assert_contains() { grep -Fq -- "$2" "$1" || fail "$1 is missing $2"; }
assert_absent() { if grep -Fq -- "$2" "$1"; then fail "$1 unexpectedly contains $2"; fi; }
assert_rejected() { if "$@" >/dev/null 2>&1; then fail "unexpectedly accepted: $*"; fi; }

for environment in staging production; do
  expected="$(printf 'profile=%s\ncheck-production=false\nenvironments=%s' "$environment" "$environment")"
  [[ "$(bash "$resolver" "$environment" "$environment")" == "$expected" ]] || fail "wrong isolated outputs for $environment"
  check_production=false
  if [[ "$environment" == staging ]]; then check_production=true; fi
  expected="$(printf 'profile=shared\ncheck-production=%s\nenvironments=production staging' "$check_production")"
  [[ "$(bash "$resolver" "$environment" shared)" == "$expected" ]] || fail "wrong shared outputs for $environment"
done
assert_rejected bash "$resolver"
assert_rejected bash "$resolver" staging
assert_rejected bash "$resolver" staging ""
assert_rejected bash "$resolver" production ""
assert_rejected bash "$resolver" staging production
assert_rejected bash "$resolver" production staging
assert_rejected bash "$resolver" preview shared
assert_rejected bash "$resolver" staging Shared
assert_rejected bash "$resolver" staging shared extra
echo 'PASS edge topology is explicit and must match the deployment environment'

# Exercise host-local health probes without making HTTP requests. Each argument
# is logged separately so redirects, TLS bypasses, and the pinned destination are
# checked independently of shell quoting.
mkdir -p "$test_root/bin"
export CURL_CALLS="$test_root/curl-calls"
cat >"$test_root/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$CURL_CALLS"
printf '%s' "${CURL_RESPONSE:-}"
exit "${CURL_EXIT_CODE:-0}"
EOF
chmod +x "$test_root/bin/curl"
export PATH="$test_root/bin:$PATH"
health_checker="$repo_root/scripts/check-edge-health.sh"

assert_rejected bash "$health_checker"
assert_rejected bash "$health_checker" preview https://opengamebuilder.com
assert_rejected bash "$health_checker" staging http://staging.opengamebuilder.com
assert_rejected bash "$health_checker" staging https://staging.opengamebuilder.com/path
assert_rejected bash "$health_checker" staging https://staging.opengamebuilder.com:8443
assert_rejected bash "$health_checker" staging https://staging.opengamebuilder.com/?redirect=other
[[ ! -e "$CURL_CALLS" ]] || fail 'invalid edge health input invoked curl'
echo 'PASS edge health rejects invalid environments and non-HTTPS origins before curl'

for environment in production staging; do
  hostname=opengamebuilder.com
  if [[ "$environment" == staging ]]; then hostname=staging.opengamebuilder.com; fi
  export CURL_RESPONSE="ok $environment" CURL_EXIT_CODE=0
  rm -f "$CURL_CALLS"
  bash "$health_checker" "$environment" "https://$hostname/" >/dev/null
  mapfile -t curl_arguments <"$CURL_CALLS"
  resolve_count=0
  noproxy_count=0
  for ((index = 0; index < ${#curl_arguments[@]}; index++)); do
    case "${curl_arguments[$index]}" in
    --noproxy)
      ((noproxy_count += 1))
      [[ "${curl_arguments[$((index + 1))]:-}" == '*' ]] || fail 'health probe can use an external proxy'
      ;;
    --resolve)
      ((resolve_count += 1))
      [[ "${curl_arguments[$((index + 1))]:-}" == "$hostname:443:127.0.0.1" ]] || fail 'health probe does not target the deployed host'
      ;;
    --location | --location-trusted | -L | --insecure | -k) fail 'health probe follows redirects or bypasses TLS validation' ;;
    esac
  done
  [[ "$resolve_count" == 1 ]] || fail 'health probe must specify exactly one host-local resolution'
  [[ "$noproxy_count" == 1 ]] || fail 'health probe must bypass external proxies'
  [[ "${curl_arguments[-1]}" == "https://$hostname/health" ]] || fail 'health probe requested an unexpected URL'
  export CURL_RESPONSE="ok $environment unexpected"
  assert_rejected bash "$health_checker" "$environment" "https://$hostname"
  export CURL_RESPONSE="ok $environment" CURL_EXIT_CODE=22
  assert_rejected bash "$health_checker" "$environment" "https://$hostname"
done
echo 'PASS edge health verifies host-local HTTPS and exact selected-environment responses'

# Keep workflow wiring covered alongside the behavior of its shell helpers.
mapfile -t production_checks < <(awk '
  /- name: Check colocated production (before|after) staging update$/ {
    getline; sub(/^[[:space:]]+/, ""); print
  }
' "$repo_root/.github/workflows/_deploy.yml")
expected_condition="if: \${{ steps.target.outputs.check-production == 'true' }}"
[[ "${#production_checks[@]}" == 2 ]] || fail 'expected both production health guards'
for condition in "${production_checks[@]}"; do
  [[ "$condition" == "$expected_condition" ]] || fail 'production health guard is not topology-dependent'
done
awk '
  /- name: Check selected edge routes on the deployed host$/ { selected = 1; next }
  selected && /- name:/ { exit }
  selected { print }
' "$repo_root/.github/workflows/cd-edge.yml" >"$test_root/edge-health-step"
assert_contains "$test_root/edge-health-step" 'EDGE_ENVIRONMENTS: ${{ steps.target.outputs.environments }}'
assert_contains "$test_root/edge-health-step" 'for environment in $EDGE_ENVIRONMENTS; do'
assert_contains "$test_root/edge-health-step" 'ssh deployment bash -s -- "$environment" "$url" < scripts/check-edge-health.sh'
echo 'PASS deployment workflows gate production checks and host-local probes by the selected topology'

for job in authorize-profile-change apply; do
  awk -v job="$job" '
    $0 == "  " job ":" { selected = 1; next }
    selected && /^  [a-zA-Z0-9_-]+:/ { exit }
    selected { print }
  ' "$repo_root/.github/workflows/cd-edge.yml" >"$test_root/$job-job"
done
assert_contains "$test_root/authorize-profile-change-job" 'if: ${{ inputs.allow-profile-change }}'
assert_contains "$test_root/authorize-profile-change-job" 'environment: production'
assert_contains "$test_root/apply-job" '      - require-main-dispatch'
assert_contains "$test_root/apply-job" '      - authorize-profile-change'
assert_contains "$test_root/apply-job" "if: \${{ !cancelled() && needs.require-main-dispatch.result == 'success' && (needs.authorize-profile-change.result == 'success' || (!inputs.allow-profile-change && needs.authorize-profile-change.result == 'skipped')) }}"
assert_contains "$test_root/apply-job" 'environment: ${{ inputs.environment }}'
echo 'PASS profile migrations require production approval without gating normal isolated staging on production'

assert_rejected bash "$renderer"
assert_rejected bash "$renderer" shared
assert_rejected bash "$renderer" "" "$test_root/invalid"
assert_rejected bash "$renderer" unknown "$test_root/invalid"
assert_rejected bash "$renderer" staging ""
assert_rejected bash "$renderer" staging "$test_root/invalid" extra
assert_rejected bash "$renderer" shared "$repo_root/deploy/edge"
echo 'PASS renderer rejects missing or invalid profiles and source overwrite'

pinned_image="$(docker compose -f "$repo_root/deploy/edge/compose.yml" config --images)"
[[ "$pinned_image" =~ ^caddy:2@sha256:[a-f0-9]{64}$ ]] || fail 'common edge image is not digest-pinned'
for profile in shared staging production; do
  candidate="$test_root/$profile candidate"
  bash "$renderer" "$profile" "$candidate" >/dev/null
  for file in compose.yml Caddyfile; do
    [[ "$(head -n 1 "$candidate/$file")" == "# ogb-edge-profile: $profile" ]] || fail "$file lacks its exact profile marker"
  done
  docker compose -f "$candidate/compose.yml" config --quiet
  [[ "$(docker compose -f "$candidate/compose.yml" config --images)" == "$pinned_image" ]] || fail "$profile changed the pinned image"
  [[ "$(docker compose -f "$candidate/compose.yml" config --services)" == caddy ]] || fail "$profile contains unexpected services"
  assert_contains "$candidate/compose.yml" 'name: ogb-edge'
  assert_contains "$candidate/compose.yml" 'external: true'
  assert_contains "$candidate/compose.yml" 'name: ogb-edge_caddy_data'
  assert_contains "$candidate/compose.yml" 'name: ogb-edge_caddy_config'
  assert_contains "$candidate/compose.yml" 'source: ./Caddyfile'
  assert_contains "$candidate/compose.yml" 'target: /etc/caddy/Caddyfile'
  assert_absent "$candidate/compose.yml" "$repo_root"
  for environment in production staging; do
    if [[ "$profile" == shared || "$profile" == "$environment" ]]; then
      assert_contains "$candidate/compose.yml" "source: ../$environment/web"
      assert_contains "$candidate/compose.yml" "target: /srv/opengamebuilder/$environment/web"
      assert_contains "$candidate/Caddyfile" "reverse_proxy api-$environment:8080"
      assert_contains "$candidate/Caddyfile" "respond \"ok $environment\" 200"
      assert_contains "$candidate/Caddyfile" "root * /srv/opengamebuilder/$environment/web"
    else
      assert_absent "$candidate/compose.yml" "$environment"
      assert_absent "$candidate/Caddyfile" "$environment"
    fi
  done
  if [[ "$profile" == staging ]]; then
    assert_absent "$candidate/Caddyfile" 'www.opengamebuilder.com'
    if grep -Fxq 'opengamebuilder.com {' "$candidate/Caddyfile"; then fail 'staging includes the production site'; fi
  else
    assert_contains "$candidate/Caddyfile" 'www.opengamebuilder.com {'
    assert_contains "$candidate/Caddyfile" 'redir https://opengamebuilder.com{uri} permanent'
  fi
  if [[ "$profile" == production ]]; then
    assert_absent "$candidate/Caddyfile" 'staging.opengamebuilder.com'
  else
    assert_contains "$candidate/Caddyfile" 'staging.opengamebuilder.com {'
  fi
  cp "$candidate/compose.yml" "$candidate/previous-compose.yml"
  cp "$candidate/Caddyfile" "$candidate/previous-Caddyfile"
  bash "$renderer" "$profile" "$candidate" >/dev/null
  cmp -s "$candidate/previous-compose.yml" "$candidate/compose.yml" || fail "$profile Compose rendering is not deterministic"
  cmp -s "$candidate/previous-Caddyfile" "$candidate/Caddyfile" || fail "$profile Caddy rendering is not deterministic"
  echo "PASS $profile edge renders a portable pinned candidate with only its selected environments"
done
