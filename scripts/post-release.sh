#!/usr/bin/env bash
# Post-release housekeeping after a successful production deploy.
#
# For standard releases (KIND=standard): opens a PR bumping main to NEXT_MAIN_VERSION.
# For patch releases   (KIND=patch):    opens a merge-back PR from patch/vX.Y.Z into main,
#                                        preserving main's higher version if it is already ahead.
#
# Requires:
#   KIND, VERSION, TAG environment variables
#   KIND=standard also requires NEXT_MAIN_VERSION
#   GH_TOKEN set with contents:write + pull-requests:write

set -euo pipefail

# shellcheck source=release-lib.sh
. "$(dirname "$0")/release-lib.sh"

: "${KIND:?KIND is required (standard|patch)}"
: "${VERSION:?VERSION is required}"
: "${TAG:?TAG is required}"

assert_semver "${VERSION}"
read -r major minor _ <<< "$(semver_parts "${VERSION}")"

git fetch --force --tags origin >/dev/null
git fetch origin main >/dev/null

configure_release_bot_git

case "${KIND}" in
    standard)
        : "${NEXT_MAIN_VERSION:?NEXT_MAIN_VERSION is required for standard releases}"
        assert_semver "${NEXT_MAIN_VERSION}"

        bump_branch="chore/bump-version-to-${NEXT_MAIN_VERSION}"

        if remote_ref_exists "refs/heads/${bump_branch}"; then
            echo "Bump branch '${bump_branch}' already exists."
        else
            git switch --detach origin/main
            git switch -c "${bump_branch}"
            write_version "${NEXT_MAIN_VERSION}"

            if [ -z "$(git status --porcelain)" ]; then
                echo "main is already at ${NEXT_MAIN_VERSION}; nothing to do."
                exit 0
            fi

            git add Directory.Build.props
            git commit -m "chore: bump version to ${NEXT_MAIN_VERSION}"
            git push origin "HEAD:refs/heads/${bump_branch}"
        fi

        existing_pr="$(gh pr list --base main --head "${bump_branch}" --state open --json number --jq '.[0].number // empty')"
        if [ -z "${existing_pr}" ]; then
            body=$(cat <<EOF
Post-release version bump after ${TAG}.

Released version: ${VERSION}
Next main version: ${NEXT_MAIN_VERSION}
EOF
)
            gh pr create \
                --base main \
                --head "${bump_branch}" \
                --title "chore: bump version to ${NEXT_MAIN_VERSION}" \
                --body "${body}"
        else
            echo "Version bump PR already exists: #${existing_pr}"
        fi
        ;;

    patch)
        patch_branch="patch/${TAG}"
        merge_branch="chore/merge-${TAG}-into-main"

        git fetch origin "+refs/heads/${patch_branch}:refs/remotes/origin/${patch_branch}" >/dev/null

        if remote_ref_exists "refs/heads/${merge_branch}"; then
            echo "Merge-back branch '${merge_branch}' already exists."
        else
            git switch --detach origin/main
            main_version="$(read_version)"

            # Target main version is whichever of (main, X.(Y+1).0) is greater.
            min_main="${major}.$((minor + 1)).0"
            if [ "$(semver_compare "${main_version}" "${min_main}")" = "-1" ]; then
                target_main_version="${min_main}"
            else
                target_main_version="${main_version}"
            fi

            echo "Main version before merge-back: ${main_version}"
            echo "Target main version after merge-back: ${target_main_version}"

            git switch -c "${merge_branch}"

            # A props conflict can include non-version changes; leave it for manual resolution.
            if ! git merge --no-ff --no-commit "origin/${patch_branch}"; then
                conflicts="$(git diff --name-only --diff-filter=U)"
                git status --short
                echo "Merge-back has unresolved conflicts (${conflicts}). Resolve manually; no branch was pushed." >&2
                exit 1
            fi

            write_version "${target_main_version}"
            git add -A

            if [ -z "$(git status --porcelain)" ]; then
                echo "Merge-back produced no changes. No PR needed."
                git merge --abort >/dev/null 2>&1 || true
                exit 0
            fi

            git commit -m "chore: merge ${TAG} into main"
            git push origin "HEAD:refs/heads/${merge_branch}"
        fi

        existing_pr="$(gh pr list --base main --head "${merge_branch}" --state open --json number --jq '.[0].number // empty')"
        if [ -z "${existing_pr}" ]; then
            body=$(cat <<EOF
Merges patch release ${TAG} back into main.

Released version: ${VERSION}
Patch branch: ${patch_branch}

Version policy:
- main keeps its current VersionPrefix if it is already beyond the patched release.
- otherwise main is bumped to ${major}.$((minor + 1)).0.
EOF
)
            gh pr create \
                --base main \
                --head "${merge_branch}" \
                --title "chore: merge ${TAG} into main" \
                --body "${body}"
        else
            echo "Merge-back PR already exists: #${existing_pr}"
        fi
        ;;

    *)
        echo "Unknown KIND: '${KIND}'. Expected 'standard' or 'patch'." >&2
        exit 1
        ;;
esac
