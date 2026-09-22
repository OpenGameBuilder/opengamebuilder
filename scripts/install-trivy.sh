#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
version='0.74.0'
release_base="https://github.com/aquasecurity/trivy/releases/download/v${version}"
tools_root="$repo_root/artifacts/tools/trivy"
install_dir="$tools_root/$version"

fail() {
  echo "Trivy installation failed: $*" >&2
  exit 1
}

[[ $# -eq 0 ]] || fail 'this installer does not accept arguments'

machine="$(uname -m)"
case "$machine" in
x86_64 | amd64) ;;
*) fail "unsupported architecture: $machine (x86_64 is required)" ;;
esac

case "$(uname -s)" in
Linux*)
  archive_name="trivy_${version}_Linux-64bit.tar.gz"
  archive_sha256='2ae6fe3ee734b7fdf11335663e18c75ea12dccc76062f09f164a3b0f8be4371a'
  executable_name='trivy'
  executable_sha256='d89bcc6510a267f11b773398cbf1be5520ce39f9e8b6633178c4487f05b7d791'
  ;;
MINGW* | MSYS* | CYGWIN*)
  archive_name="trivy_${version}_windows-64bit.zip"
  archive_sha256='94c40e0696e4b907a74b7b2e1438d5d72ebaca83115817407f568a002d520842'
  executable_name='trivy.exe'
  executable_sha256='4c532e1f28f53282dc364671e87381cd77760fa9cafab143f576449c2207cdd5'
  ;;
*) fail "unsupported operating system: $(uname -s)" ;;
esac

executable="$install_dir/$executable_name"
if [[ -x "$executable" ]] &&
  printf '%s  %s\n' "$executable_sha256" "$executable" | sha256sum --check --status &&
  "$executable" --version | grep -Eq "^Version:[[:space:]]+${version}$"; then
  echo "Trivy $version is already installed at $executable"
  exit 0
fi

for command_name in curl sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
done
if [[ "$archive_name" == *.zip ]]; then
  command -v unzip >/dev/null 2>&1 || fail 'unzip is required on Windows Git Bash'
else
  command -v tar >/dev/null 2>&1 || fail 'tar is required on Linux'
fi

mkdir -p "$tools_root"
tools_root="$(cd "$tools_root" && pwd -P)"
work_dir="$(mktemp -d "$tools_root/install-${version}.XXXXXX")"
case "$work_dir" in
"$tools_root"/install-"$version".*) ;;
*) fail "temporary directory escaped $tools_root" ;;
esac
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT
archive="$work_dir/$archive_name"

curl --fail --location --silent --show-error \
  --output "$archive" \
  "$release_base/$archive_name"
printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum --check --status ||
  fail "SHA-256 verification failed for $archive_name"

if [[ "$archive_name" == *.zip ]]; then
  unzip -q "$archive" "$executable_name" -d "$work_dir/extracted"
else
  mkdir -p "$work_dir/extracted"
  tar -xzf "$archive" -C "$work_dir/extracted" "$executable_name"
fi

mkdir -p "$install_dir"
chmod +x "$work_dir/extracted/$executable_name"
mv -f "$work_dir/extracted/$executable_name" "$executable"
printf '%s  %s\n' "$executable_sha256" "$executable" | sha256sum --check --status ||
  fail "installed executable checksum did not match Trivy $version"
"$executable" --version | grep -Eq "^Version:[[:space:]]+${version}$" ||
  fail "installed executable did not report Trivy $version"

echo "Installed Trivy $version at $executable"
