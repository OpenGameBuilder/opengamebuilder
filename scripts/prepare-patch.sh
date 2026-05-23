#!/usr/bin/env bash
# Prepares a patch release PR from the latest stable GitHub Release tag.
#
# Creates (idempotently):
#   - branch patch/v<X.Y.(Z+1)> from the latest release tag
#   - branch chore/prepare-v<X.Y.(Z+1)> with VersionPrefix bumped
#   - PR from prepare branch into patch branch
#
# Requires GH_TOKEN to be set (with contents:write + pull-requests:write).

set -euo pipefail

# shellcheck source=release-lib.sh
. "$(dirname "$0")/release-lib.sh"

git fetch --force --tags origin >/dev/null
git fetch origin main >/dev/null

base_tag="$(latest_release_tag)"
if [ -z "${base_tag}" ]; then
    echo "No stable GitHub Release was found. Publish a standard release first." >&2
    exit 1
fi

base_version="${base_tag#v}"
read -r major minor patch <<< "$(semver_parts "${base_version}")"
next_patch=$((patch + 1))
next_version="${major}.${minor}.${next_patch}"
next_tag="v${next_version}"
patch_branch="patch/${next_tag}"
prepare_branch="chore/prepare-${next_tag}"

if git ls-remote --exit-code --tags origin "refs/tags/${next_tag}" >/dev/null 2>&1; then
    echo "Tag '${next_tag}' already exists." >&2
    exit 1
fi

configure_release_bot_git

# Ensure patch branch exists at the base tag.
if git ls-remote --exit-code --heads origin "${patch_branch}" >/dev/null 2>&1; then
    echo "Patch branch '${patch_branch}' already exists; checking its state."
    git fetch origin "+refs/heads/${patch_branch}:refs/remotes/origin/${patch_branch}" >/dev/null
    git switch --detach "origin/${patch_branch}"

    branch_version="$(read_version)"
    if [ "${branch_version}" != "${base_version}" ] && [ "${branch_version}" != "${next_version}" ]; then
        echo "Patch branch '${patch_branch}' has VersionPrefix '${branch_version}', expected '${base_version}' (unprepared) or '${next_version}' (already prepared)." >&2
        echo "Fix the branch before preparing another patch." >&2
        exit 1
    fi

    # The base tag must be an ancestor of the patch branch.
    if ! git merge-base --is-ancestor "${base_tag}" "origin/${patch_branch}"; then
        echo "Base tag '${base_tag}' is not an ancestor of '${patch_branch}'. Refusing to continue." >&2
        exit 1
    fi
else
    echo "Creating patch branch '${patch_branch}' from '${base_tag}'."
    git branch "${patch_branch}" "${base_tag}"
    git push origin "refs/heads/${patch_branch}"
fi

# Ensure prepare branch exists with version bump.
if git ls-remote --exit-code --heads origin "${prepare_branch}" >/dev/null 2>&1; then
    echo "Prepare branch '${prepare_branch}' already exists."
else
    git fetch origin "+refs/heads/${patch_branch}:refs/remotes/origin/${patch_branch}" >/dev/null
    git switch --detach "origin/${patch_branch}"
    git switch -c "${prepare_branch}"

    write_version "${next_version}"

    if [ -z "$(git status --porcelain)" ]; then
        echo "No version change was needed; ${patch_branch} is already at ${next_version}." >&2
        exit 1
    fi

    git add Directory.Build.props
    git commit -m "chore: prepare ${next_tag}"
    git push origin "HEAD:refs/heads/${prepare_branch}"
fi

# Ensure PR exists.
existing_pr="$(gh pr list --base "${patch_branch}" --head "${prepare_branch}" --state open --json number --jq '.[0].number' 2>/dev/null || true)"

if [ -z "${existing_pr}" ]; then
    body=$(cat <<EOF
Prepares patch release ${next_tag}.

Base release: ${base_tag}
Patch branch: ${patch_branch}

Next steps:
1. Merge this PR into \`${patch_branch}\`.
2. Add patch fixes to \`${patch_branch}\` via normal PRs.
3. From the GitHub Actions page, run **CD Production** with \`${patch_branch}\` as the ref.
EOF
)
    gh pr create \
        --base "${patch_branch}" \
        --head "${prepare_branch}" \
        --title "chore: prepare ${next_tag}" \
        --body "${body}"
else
    echo "Prepare patch PR already exists: #${existing_pr}"
fi

echo "Prepared patch release:"
echo "  Base release:    ${base_tag}"
echo "  Next tag:        ${next_tag}"
echo "  Patch branch:    ${patch_branch}"
echo "  Prepare branch:  ${prepare_branch}"
