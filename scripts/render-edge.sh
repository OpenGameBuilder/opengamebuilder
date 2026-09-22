#!/usr/bin/env bash
# Render an explicit host profile into two standalone edge deployment files.
# This only uses the Compose CLI; it does not contact Docker Engine or start services.
set -euo pipefail

if [[ "$#" != 2 || -z "$2" ]]; then
  echo "Usage: render-edge.sh <shared|staging|production> <candidate-directory>" >&2
  exit 1
fi

profile="$1"
case "$profile" in
shared) environments=(production staging) ;;
staging | production) environments=("$profile") ;;
*)
  echo "Unknown edge profile '$profile'; expected shared, staging, or production." >&2
  exit 1
  ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/deploy/edge"
mkdir -p -- "$2"
candidate_dir="$(cd "$2" && pwd)"
if [[ "$candidate_dir" == "$source_dir" ]]; then
  echo "The candidate directory must not overwrite the edge source templates." >&2
  exit 1
fi

temporary_dir="$(mktemp -d "$candidate_dir/.render.XXXXXXXX")"
trap 'rm -r -- "$temporary_dir"' EXIT
compose=(docker compose -f "$source_dir/compose.yml")
for environment in "${environments[@]}"; do
  compose+=(-f "$source_dir/compose.$environment.yml")
done

# Retain relative mounts so the result can be transferred to a different host
# and applied with that host's permanent edge directory as its project directory.
printf '# ogb-edge-profile: %s\n' "$profile" >"$temporary_dir/compose.yml"
"${compose[@]}" config --no-path-resolution >>"$temporary_dir/compose.yml"
printf '# ogb-edge-profile: %s\n' "$profile" >"$temporary_dir/Caddyfile"
for environment in "${environments[@]}"; do
  printf '\n' >>"$temporary_dir/Caddyfile"
  cat "$source_dir/Caddyfile.$environment" >>"$temporary_dir/Caddyfile"
done

mv -- "$temporary_dir/compose.yml" "$candidate_dir/compose.yml"
mv -- "$temporary_dir/Caddyfile" "$candidate_dir/Caddyfile"
printf 'Rendered %s edge profile in %s\n' "$profile" "$candidate_dir"
