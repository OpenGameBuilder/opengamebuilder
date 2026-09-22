#!/usr/bin/env bash
# Isolated release-script contract tests. Only local fixture repositories are touched.
set -euo pipefail

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
real_git="$(command -v git)"
test_root="$(mktemp -d -t ogb-release-tests.XXXXXX)"
cleanup() {
  case "${test_root}" in
  */ogb-release-tests.*) rm -rf -- "${test_root}" ;;
  *)
    echo "Refusing to remove unexpected test directory: ${test_root}" >&2
    exit 1
    ;;
  esac
}
trap cleanup EXIT

mkdir -p "${test_root}/mock-bin"
cat >"${test_root}/mock-bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = push ]; then
    printf 'git %s\n' "$*" >> "$MOCK_LOG"
    exit "${MOCK_PUSH_EXIT:-0}"
fi
if [ "${1:-}" = ls-remote ] && [ "${MOCK_REMOTE_LOOKUP_FAIL:-0}" = 1 ]; then
    echo 'mock remote lookup failed' >&2
    exit 128
fi
exec "$REAL_GIT" "$@"
EOF
cat >"${test_root}/mock-bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "$MOCK_LOG"
case "${1:-} ${2:-}" in
    'release list')
        if [ "${MOCK_RELEASE_LIST_FAIL:-0}" = 1 ]; then
            echo 'mock GitHub release lookup failed' >&2
            exit 1
        fi
        cat "$MOCK_RELEASES_FILE"
        ;;
    'pr list')
        if [ "${MOCK_PR_LIST_FAIL:-0}" = 1 ]; then
            echo 'mock GitHub PR lookup failed' >&2
            exit 1
        fi
        printf '%s\n' "${MOCK_PR_NUMBER:-}"
        ;;
    'pr create')
        if [ "${MOCK_PR_CREATE_FAIL:-0}" = 1 ]; then
            echo 'mock GitHub PR creation failed' >&2
            exit 1
        fi
        echo 'https://example.invalid/mock-pr/1'
        ;;
    *) echo "Unexpected GitHub call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "${test_root}/mock-bin/git" "${test_root}/mock-bin/gh"
export REAL_GIT="${real_git}" PATH="${test_root}/mock-bin:${PATH}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}
assert_status() { [ "${status}" = "$1" ] || {
  cat "$output" >&2
  fail "Expected exit $1, got ${status}"
}; }
assert_contains() { grep -Fq -- "$1" "$2" || {
  cat "$2" >&2
  fail "Missing '$1' in $2"
}; }
assert_not_contains() { if grep -Fq -- "$1" "$2"; then
  cat "$2" >&2
  fail "Unexpected '$1' in $2"
fi; }
assert_no_push() { assert_not_contains 'git push ' "$MOCK_LOG"; }

new_fixture() {
  local name="$1" version="$2"
  fixture="${test_root}/${name}"
  repo="${fixture}/work"
  origin="${fixture}/origin.git"
  mkdir -p "$fixture"
  "$REAL_GIT" init -q -b main "$repo"
  "$REAL_GIT" init -q --bare "$origin"
  "$REAL_GIT" -C "$repo" config user.name 'Release Script Test'
  "$REAL_GIT" -C "$repo" config user.email 'release-test@example.invalid'
  "$REAL_GIT" -C "$repo" config core.autocrlf false
  "$REAL_GIT" -C "$repo" remote add origin "$origin"
  write_props "$version"
  "$REAL_GIT" -C "$repo" add Directory.Build.props
  "$REAL_GIT" -C "$repo" commit -qm base
  base_sha="$("$REAL_GIT" -C "$repo" rev-parse HEAD)"
  remote_ref refs/heads/main "$base_sha"
  MOCK_LOG="${fixture}/operations.log"
  MOCK_RELEASES_FILE="${fixture}/releases.txt"
  output="${fixture}/output.txt"
  gh_output_file="${fixture}/github-output.txt"
  : >"$MOCK_LOG"
  : >"$MOCK_RELEASES_FILE"
  : >"$gh_output_file"
  export MOCK_LOG MOCK_RELEASES_FILE
  unset MOCK_RELEASE_LIST_FAIL MOCK_PR_LIST_FAIL MOCK_PR_CREATE_FAIL MOCK_PR_NUMBER \
    MOCK_PUSH_EXIT MOCK_REMOTE_LOOKUP_FAIL || true
}

write_props() {
  local version="$1" extra="${2:-}"
  printf '<Project>\n  <PropertyGroup>\n    <VersionPrefix>%s</VersionPrefix>\n    %s\n  </PropertyGroup>\n</Project>\n' \
    "$version" "$extra" >"$repo/Directory.Build.props"
}

remote_ref() {
  "$REAL_GIT" --git-dir="$origin" fetch -q "$repo" "$2"
  "$REAL_GIT" --git-dir="$origin" update-ref "$1" "$2"
}
tag_at() {
  "$REAL_GIT" -C "$repo" tag "$1" "$2"
  remote_ref "refs/tags/$1" "$2"
}
commit_props() {
  write_props "$1" "${2:-}"
  "$REAL_GIT" -C "$repo" add Directory.Build.props
  "$REAL_GIT" -C "$repo" commit -qm "$1"
}
patch_branch() {
  "$REAL_GIT" -C "$repo" switch -q -c "patch/v$1"
  commit_props "$1" "${2:-}"
  patch_sha="$("$REAL_GIT" -C "$repo" rev-parse HEAD)"
  remote_ref "refs/heads/patch/v$1" "$patch_sha"
}
releases() { printf '%s\n' "$@" >"$MOCK_RELEASES_FILE"; }
run_script() {
  if (cd "$repo" && "$@") >"$output" 2>&1; then status=0; else status=$?; fi
}
validate() { run_script env SOURCE_REF="$1" GITHUB_OUTPUT="$gh_output_file" bash "$source_root/scripts/validate-release.sh"; }
post_standard() {
  run_script env KIND=standard VERSION="$1" TAG="v$1" NEXT_MAIN_VERSION="$2" \
    bash "$source_root/scripts/post-release.sh"
}
post_patch() {
  run_script env KIND=patch VERSION="$1" TAG="v$1" bash "$source_root/scripts/post-release.sh"
}
pass() { echo "PASS: $1"; }

new_fixture standard_next 1.10.0
tag_at v1.9.0 "$base_sha"
releases v1.9.0
validate main
assert_status 0
assert_contains 'kind=standard' "$gh_output_file"
assert_contains 'previous_tag=v1.9.0' "$gh_output_file"
assert_contains 'next_main_version=1.11.0' "$gh_output_file"
assert_no_push
pass 'next standard release'

new_fixture standard_rerun 1.10.0
tag_at v1.10.0 "$base_sha"
releases v1.9.0 v1.10.0
validate main
assert_status 0
assert_contains 'previous_tag=v1.9.0' "$gh_output_file"
pass 'published standard release rerun'

new_fixture standard_stale 1.9.0
releases v1.9.0 v1.10.0
validate main
[ "$status" != 0 ] || fail 'Stale standard release was accepted'
assert_contains 'must be greater' "$output"
pass 'stale standard release rejected'

new_fixture patch_next 1.9.0
tag_at v1.9.0 "$base_sha"
patch_branch 1.9.1
releases v1.9.0
validate patch/v1.9.1
assert_status 0
assert_contains 'kind=patch' "$gh_output_file"
assert_contains 'previous_tag=v1.9.0' "$gh_output_file"
assert_contains 'next_main_version=' "$gh_output_file"
pass 'next patch release'

tag_at v1.9.1 "$patch_sha"
releases v1.9.0 v1.9.1
: >"$gh_output_file"
validate patch/v1.9.1
assert_status 0
assert_contains 'previous_tag=v1.9.0' "$gh_output_file"
pass 'published patch release rerun'

releases v1.9.0 v1.9.1 v1.10.0
validate patch/v1.9.1
[ "$status" != 0 ] || fail 'Old published patch rerun was accepted'
assert_contains 'latest deployed line' "$output"
pass 'old published patch rerun rejected'

new_fixture patch_tag_only 1.9.0
tag_at v1.9.0 "$base_sha"
patch_branch 1.9.1
tag_at v1.9.1 "$patch_sha"
releases v1.9.0
validate patch/v1.9.1
assert_status 0
pass 'tag-only partial patch release rerun'

new_fixture tag_conflict 1.9.0
tag_at v1.9.0 "$base_sha"
patch_branch 1.9.1
tag_at v1.9.1 "$base_sha"
releases v1.9.0
validate patch/v1.9.1
[ "$status" != 0 ] || fail 'Mismatched tag was accepted'
assert_contains 'already exists at' "$output"
pass 'mismatched tag rejected'

new_fixture patch_progression 1.9.0
tag_at v1.9.0 "$base_sha"
patch_branch 1.9.3
releases v1.9.0 v1.9.1
validate patch/v1.9.3
[ "$status" != 0 ] || fail 'Skipped patch version was accepted'
assert_contains 'must be the next patch' "$output"
pass 'invalid patch progression rejected'

new_fixture old_line 1.9.0
tag_at v1.9.0 "$base_sha"
patch_branch 1.9.1
releases v1.9.0 v1.10.0
validate patch/v1.9.1
[ "$status" != 0 ] || fail 'Patch to old release line was accepted'
assert_contains 'latest deployed line' "$output"
pass 'old release line rejected'

new_fixture github_failure 1.10.0
MOCK_RELEASE_LIST_FAIL=1
export MOCK_RELEASE_LIST_FAIL
validate main
[ "$status" != 0 ] || fail 'Failed GitHub release lookup was accepted'
assert_contains 'Failed to list GitHub Releases' "$output"
pass 'failed GitHub release lookup'

new_fixture standard_followup 1.9.0
post_standard 1.9.0 1.10.0
assert_status 0
assert_contains 'git push origin HEAD:refs/heads/chore/bump-version-to-1.10.0' "$MOCK_LOG"
assert_contains 'gh pr create --base main --head chore/bump-version-to-1.10.0' "$MOCK_LOG"
assert_contains '<VersionPrefix>1.10.0</VersionPrefix>' "$repo/Directory.Build.props"
pass 'standard follow-up branch and PR with mocked push'

new_fixture standard_followup_rerun 1.9.0
"$REAL_GIT" -C "$repo" switch -q -c chore/bump-version-to-1.10.0
commit_props 1.10.0
bump_sha="$("$REAL_GIT" -C "$repo" rev-parse HEAD)"
remote_ref refs/heads/chore/bump-version-to-1.10.0 "$bump_sha"
MOCK_PR_NUMBER=42
export MOCK_PR_NUMBER
post_standard 1.9.0 1.10.0
assert_status 0
assert_contains 'Version bump PR already exists: #42' "$output"
assert_no_push
assert_not_contains 'gh pr create' "$MOCK_LOG"
pass 'existing follow-up PR rerun'

new_fixture pr_list_failure 1.9.0
MOCK_PR_LIST_FAIL=1
export MOCK_PR_LIST_FAIL
post_standard 1.9.0 1.10.0
[ "$status" != 0 ] || fail 'Failed PR lookup was accepted'
assert_contains 'mock GitHub PR lookup failed' "$output"
assert_not_contains 'gh pr create' "$MOCK_LOG"
pass 'failed GitHub PR lookup'

new_fixture pr_create_failure 1.9.0
MOCK_PR_CREATE_FAIL=1
export MOCK_PR_CREATE_FAIL
post_standard 1.9.0 1.10.0
[ "$status" != 0 ] || fail 'Failed PR creation was accepted'
assert_contains 'mock GitHub PR creation failed' "$output"
pass 'failed GitHub PR creation'

new_fixture remote_lookup_failure 1.9.0
MOCK_REMOTE_LOOKUP_FAIL=1
export MOCK_REMOTE_LOOKUP_FAIL
post_standard 1.9.0 1.10.0
[ "$status" != 0 ] || fail 'Failed remote branch lookup was accepted'
assert_contains 'Failed to inspect remote ref' "$output"
assert_no_push
pass 'failed remote branch lookup'

new_fixture patch_followup 1.9.0
patch_branch 1.9.1 '<PatchSetting>kept</PatchSetting>'
"$REAL_GIT" -C "$repo" switch -q main
post_patch 1.9.1
assert_status 0
assert_contains 'git push origin HEAD:refs/heads/chore/merge-v1.9.1-into-main' "$MOCK_LOG"
assert_contains 'gh pr create --base main --head chore/merge-v1.9.1-into-main' "$MOCK_LOG"
assert_contains '<PatchSetting>kept</PatchSetting>' "$repo/Directory.Build.props"
assert_contains '<VersionPrefix>1.10.0</VersionPrefix>' "$repo/Directory.Build.props"
pass 'clean patch merge-back preserves props changes'

new_fixture props_conflict 1.9.0
patch_branch 1.9.1 '<PatchSetting>keep</PatchSetting>'
"$REAL_GIT" -C "$repo" switch -q main
commit_props 1.10.0 '<MainSetting>keep</MainSetting>'
main_sha="$("$REAL_GIT" -C "$repo" rev-parse HEAD)"
remote_ref refs/heads/main "$main_sha"
post_patch 1.9.1
[ "$status" != 0 ] || fail 'Conflicted props merge-back was accepted'
assert_contains 'Resolve manually; no branch was pushed' "$output"
assert_no_push
assert_not_contains 'gh pr create' "$MOCK_LOG"
pass 'props merge conflict requires manual resolution'

new_fixture prepare_conflict 1.9.0
tag_at v1.9.0 "$base_sha"
tag_at v1.9.1 "$base_sha"
releases v1.9.0
run_script bash "$source_root/scripts/prepare-patch.sh"
[ "$status" != 0 ] || fail 'Prepare patch accepted existing next tag'
assert_contains "Tag 'v1.9.1' already exists" "$output"
assert_no_push
pass 'prepare patch rejects existing tag'

new_fixture prepare_rerun 1.9.0
tag_at v1.9.0 "$base_sha"
remote_ref refs/heads/patch/v1.9.1 "$base_sha"
"$REAL_GIT" -C "$repo" switch -q -c chore/prepare-v1.9.1
commit_props 1.9.1
prepare_sha="$("$REAL_GIT" -C "$repo" rev-parse HEAD)"
remote_ref refs/heads/chore/prepare-v1.9.1 "$prepare_sha"
releases v1.9.0
MOCK_PR_NUMBER=43
export MOCK_PR_NUMBER
run_script bash "$source_root/scripts/prepare-patch.sh"
assert_status 0
assert_contains 'Prepare patch PR already exists: #43' "$output"
assert_no_push
assert_not_contains 'gh pr create' "$MOCK_LOG"
pass 'prepare patch existing PR rerun'

echo 'All release-script tests passed.'
