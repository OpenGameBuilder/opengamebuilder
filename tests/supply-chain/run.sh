#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $*" >&2; exit 1; }

action_count=0
version_comment_pattern='#[[:space:]]+v[0-9]'
while IFS= read -r line; do
  [[ "$line" =~ uses:[[:space:]]+([^[:space:]#]+) ]] || fail "could not parse action reference: $line"
  action_ref="${BASH_REMATCH[1]}"
  [[ "$action_ref" == ./* ]] && continue
  [[ "$action_ref" =~ ^[^@]+@[0-9a-f]{40}$ ]] || fail "third-party action is not pinned to a full commit SHA: $action_ref"
  [[ "$line" =~ $version_comment_pattern ]] || fail "pinned action lacks an adjacent version comment: $line"
  ((action_count += 1))
done < <(grep -RhE --include='*.yml' --include='*.yaml' '^[[:space:]]*(- )?uses:[[:space:]]+' .github)
((action_count > 0)) || fail 'no third-party action references were checked'
echo "PASS ${action_count} third-party action references use reviewed commit SHAs"

base_count=0
while read -r directive image_ref remainder; do
  [[ "$directive" == FROM ]] || continue
  [[ "$image_ref" == scratch ]] && continue
  [[ "$image_ref" =~ @sha256:[0-9a-f]{64}$ ]] || fail "Dockerfile base image is not pinned by digest: $image_ref"
  ((base_count += 1))
done < src/OpenGameBuilder.Api/Dockerfile
((base_count > 0)) || fail 'no Dockerfile base images were checked'
grep -Eq '^[[:space:]]+image:[[:space:]]+[^[:space:]@]+@sha256:[0-9a-f]{64}$' deploy/edge/compose.yml ||
  fail 'edge image is not pinned by digest'
echo "PASS ${base_count} API base images and the edge image use immutable digests"

grep -Fq 'USER $APP_UID' src/OpenGameBuilder.Api/Dockerfile || fail 'API image lacks an explicit non-root user'
if grep -R -n -F 'ssh-keyscan' .github/workflows; then
  fail 'deployment workflow still learns SSH trust with ssh-keyscan'
fi
echo 'PASS API user and SSH trust declarations are hardened'

awk '
  /<packageSourceMapping>/ { in_mapping = 1 }
  in_mapping && /<clear[[:space:]]*\/>/ { found_clear = 1 }
  /<\/packageSourceMapping>/ { in_mapping = 0 }
  END { exit(found_clear ? 0 : 1) }
' NuGet.Config || fail 'package source mapping does not clear inherited mappings'

for ecosystem in github-actions docker docker-compose; do
  grep -Fq "package-ecosystem: \"${ecosystem}\"" .github/dependabot.yml ||
    fail "Dependabot does not monitor ${ecosystem} pins"
done
grep -Fq 'directory: "/.github/actions/validate"' .github/dependabot.yml ||
  fail 'Dependabot does not monitor the composite validation action pins'
echo 'PASS NuGet mapping inheritance is cleared and pin update automation remains enabled'
