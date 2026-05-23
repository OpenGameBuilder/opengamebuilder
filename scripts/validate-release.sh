#!/usr/bin/env bash
# Validates a production release dispatched from the current checkout.
#
# Reads:
#   - <VersionPrefix> from Directory.Build.props
#   - $SOURCE_REF (the dispatched ref, e.g. main or patch/v1.9.1)
#   - GitHub Releases via `gh` (requires GH_TOKEN)
#
# Detects release kind from the version:
#   - patch == 0  -> "standard" (must be from main)
#   - patch >  0  -> "patch"    (must be from patch/vX.Y.Z matching the version)
#
# Writes the following to GITHUB_OUTPUT:
#   kind, version, tag, source_sha, previous_tag, next_main_version (standard only)

set -euo pipefail

# shellcheck source=release-lib.sh
. "$(dirname "$0")/release-lib.sh"

: "${SOURCE_REF:?SOURCE_REF is required (e.g. refs/heads/main).}"

source_ref="${SOURCE_REF#refs/heads/}"
source_ref="${source_ref#origin/}"

version="$(read_version)"
read -r major minor patch <<< "$(semver_parts "$version")"
tag="v${version}"
source_sha="$(git rev-parse HEAD)"

git fetch --force --tags origin >/dev/null 2>&1 || true

# If a tag with this version already exists, it must point at the same commit (idempotent re-runs).
if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
    existing_sha="$(git rev-list -n 1 "${tag}")"
    if [ "${existing_sha}" != "${source_sha}" ]; then
        echo "Tag ${tag} already exists at ${existing_sha}, but ${source_ref} is at ${source_sha}." >&2
        exit 1
    fi
    echo "Tag ${tag} already exists at the expected SHA. Continuing idempotently."
fi

latest_tag="$(latest_release_tag)"
latest_version="${latest_tag#v}"

next_main_version=""
previous_tag=""

if [ "${patch}" = "0" ]; then
    kind="standard"

    if [ "${source_ref}" != "main" ]; then
        echo "Standard releases must be published from main. Received '${source_ref}'." >&2
        exit 1
    fi

    if [ -n "${latest_tag}" ] && [ "${latest_tag}" != "${tag}" ]; then
        if [ "$(semver_compare "${version}" "${latest_version}")" != "1" ]; then
            echo "Standard release '${version}' must be greater than latest stable release '${latest_version}'." >&2
            exit 1
        fi
        previous_tag="${latest_tag}"
    fi

    next_main_version="${major}.$((minor + 1)).0"
else
    kind="patch"

    expected_branch="patch/v${version}"
    if [ "${source_ref}" != "${expected_branch}" ]; then
        echo "Patch releases must be published from ${expected_branch}. Received '${source_ref}'." >&2
        exit 1
    fi

    line="${major}.${minor}"
    line_latest_tag="$(latest_release_tag "${line}")"
    if [ -z "${line_latest_tag}" ] || [ "${line_latest_tag}" = "${tag}" ]; then
        echo "Could not find a prior stable release in line ${line}. Publish a standard release first." >&2
        exit 1
    fi

    line_latest_version="${line_latest_tag#v}"
    read -r _ _ line_latest_patch <<< "$(semver_parts "${line_latest_version}")"
    expected_patch=$((line_latest_patch + 1))
    if [ "${patch}" != "${expected_patch}" ]; then
        echo "Patch release '${version}' must be the next patch after '${line_latest_version}' (expected patch ${expected_patch})." >&2
        exit 1
    fi

    # Only patch the latest deployed release line.
    if [ -n "${latest_tag}" ] && [ "${latest_tag}" != "${tag}" ]; then
        read -r latest_major latest_minor _ <<< "$(semver_parts "${latest_version}")"
        if [ "${latest_major}.${latest_minor}" != "${line}" ]; then
            echo "Patch releases must patch the latest deployed line. Latest stable is '${latest_tag}', this patch is for '${line}'." >&2
            exit 1
        fi
    fi

    previous_tag="${line_latest_tag}"
fi

gh_output "kind" "${kind}"
gh_output "version" "${version}"
gh_output "tag" "${tag}"
gh_output "source_sha" "${source_sha}"
gh_output "previous_tag" "${previous_tag}"
gh_output "next_main_version" "${next_main_version}"

echo "Validated ${kind} release:"
echo "  Source ref:        ${source_ref}"
echo "  Source SHA:        ${source_sha}"
echo "  Version:           ${version}"
echo "  Tag:               ${tag}"
[ -n "${previous_tag}" ] && echo "  Previous tag:      ${previous_tag}"
[ -n "${next_main_version}" ] && echo "  Next main version: ${next_main_version}"
