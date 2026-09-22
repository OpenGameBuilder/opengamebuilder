#!/usr/bin/env bash
# Called only after production deployment and smoke validation succeed.
# Requires TAG, SOURCE_SHA, GH_TOKEN and a checkout of that exact source.
set -euo pipefail

# shellcheck source=release-lib.sh
. "$(dirname "$0")/release-lib.sh"

: "${TAG:?TAG is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
version="$(read_version)"
if [ "${TAG}" != "v${version}" ] || [ "$(git rev-parse HEAD)" != "${SOURCE_SHA}" ]; then
  echo 'Release tag, version, and checked-out source must match.' >&2
  exit 1
fi

# Select the reviewed entry before any tag/release mutation. Keep relative links
# useful on GitHub Releases by binding them to the immutable source revision.
notes_file="$(mktemp)"
trap 'rm -f -- "$notes_file"' EXIT
node "$(dirname "$0")/changelog.mjs" notes \
  --repository "${GITHUB_REPOSITORY:-OpenGameBuilder/opengamebuilder}" \
  --source-sha "${SOURCE_SHA}" --output "${notes_file}"

git fetch --force --tags origin
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  existing_sha="$(git rev-list -n 1 "${TAG}")"
  if [ "${existing_sha}" != "${SOURCE_SHA}" ]; then
    echo "Tag ${TAG} already exists at ${existing_sha}, expected ${SOURCE_SHA}." >&2
    exit 1
  fi
  echo "Tag ${TAG} already exists at the expected SHA."
else
  configure_release_bot_git
  git tag -a "${TAG}" "${SOURCE_SHA}" -m "Release ${TAG}"
  git push origin "refs/tags/${TAG}"
fi

# A failed lookup must not be mistaken for an absent release. Validation permits
# reruns only for the latest stable version, which is within this existing limit.
existing_release="$(gh release list --limit 200 --json tagName,isDraft,isPrerelease \
  --jq ".[] | select(.tagName == \"${TAG}\") | if .isDraft or .isPrerelease then \"unpublished\" else \"published\" end")"
case "${existing_release}" in
published)
  echo "GitHub Release ${TAG} already exists; leaving its reviewed body unchanged."
  ;;
unpublished)
  echo "GitHub Release ${TAG} is a draft or prerelease; resolve it before retrying." >&2
  exit 1
  ;;
"")
  gh release create "${TAG}" --verify-tag --title "${TAG}" --notes-file "${notes_file}"
  ;;
*)
  echo "Unexpected release lookup result for ${TAG}." >&2
  exit 1
  ;;
esac
