#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
version='0.74.0'
image_reference='opengamebuilder-api:ci'
config="$repo_root/scripts/trivy.yaml"
output_dir="$repo_root/artifacts/validation"

fail() {
  echo "API image vulnerability scan failed: $*" >&2
  exit 1
}

[[ $# -le 1 ]] || fail 'usage: scan-api-image.sh [opengamebuilder-api:ci]'
if [[ $# -eq 1 && "$1" != "$image_reference" ]]; then
  fail "only the locally built $image_reference image may be scanned"
fi
[[ -f "$config" ]] || fail "missing Trivy policy: $config"
command -v docker >/dev/null 2>&1 || fail 'docker is required'

case "$(uname -s)" in
Linux*) trivy="$repo_root/artifacts/tools/trivy/$version/trivy" ;;
MINGW* | MSYS* | CYGWIN*) trivy="$repo_root/artifacts/tools/trivy/$version/trivy.exe" ;;
*) fail "unsupported operating system: $(uname -s)" ;;
esac
[[ -x "$trivy" ]] || fail "Trivy $version is not installed; run scripts/install-trivy.sh"
"$trivy" --version | grep -Eq "^Version:[[:space:]]+${version}$" ||
  fail "expected Trivy $version at $trivy"

# Trivy supports environment-variable configuration. Remove it so repository
# policy and the explicit command line below are the only inputs.
while IFS='=' read -r variable_name _value; do
  case "$variable_name" in
  TRIVY_*) unset "$variable_name" ;;
  esac
done < <(env)

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd -P)"
json_report="$output_dir/trivy-api-image.json"
table_report="$output_dir/trivy-api-image.txt"
scan_log="$output_dir/trivy-api-image.log"
image_record="$output_dir/trivy-api-image-id.txt"
rm -f -- "$json_report" "$table_report" "$scan_log" "$image_record"
if ! image_id="$(docker image inspect --format '{{.Id}}' "$image_reference")"; then
  fail "locally built image $image_reference was not found"
fi
[[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "Docker returned an invalid image ID for $image_reference"

cache_dir="$(mktemp -d "$output_dir/trivy-cache.XXXXXX")"
case "$cache_dir" in
"$output_dir"/trivy-cache.*) ;;
*) fail "temporary cache escaped $output_dir" ;;
esac
cleanup() {
  rm -rf -- "$cache_dir"
}
trap cleanup EXIT
ignore_file="$cache_dir/empty.trivyignore"
: >"$ignore_file"
printf '%s\n' "$image_id" >"$image_record"

common_arguments=(
  --config "$config"
  --cache-dir "$cache_dir"
  --skip-db-update=false
  --image-src docker
  --scanners vuln
  --pkg-types "os,library"
  --ignore-unfixed=false
  --ignorefile "$ignore_file"
  --skip-version-check
)

# Keep an all-severity machine-readable result for triage. Scanner and database
# errors remain fatal even though vulnerabilities do not fail this first pass.
if ! "$trivy" image \
  "${common_arguments[@]}" \
  --list-all-pkgs=true \
  --severity "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL" \
  --format json \
  --output "$json_report" \
  --exit-code 0 \
  "$image_id" 2>&1 | tee "$scan_log"; then
  fail "Trivy could not produce $json_report; see $scan_log"
fi

# Trivy itself applies the blocking policy and writes the human-readable report.
if ! "$trivy" image \
  "${common_arguments[@]}" \
  --severity "HIGH,CRITICAL" \
  --format table \
  --output "$table_report" \
  --exit-code 1 \
  "$image_id" 2>&1 | tee -a "$scan_log"; then
  fail "HIGH/CRITICAL findings or a scanner error blocked the image; see $table_report and $scan_log"
fi

echo "API image $image_id passed the HIGH/CRITICAL vulnerability policy."
echo "Reports: $json_report and $table_report"
