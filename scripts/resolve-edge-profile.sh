#!/usr/bin/env bash
# Validate the host topology selected by a GitHub deployment environment.
set -euo pipefail

if [[ "$#" != 2 ]]; then
  echo "Usage: resolve-edge-profile.sh <staging|production> <shared|staging|production>" >&2
  exit 1
fi

environment="$1"
profile="$2"
case "$environment:$profile" in
  staging:staging|production:production|staging:shared|production:shared) ;;
  *)
    echo "EDGE_PROFILE must be explicitly set to '$environment' or 'shared' for a staging or production deployment environment." >&2
    exit 1
    ;;
esac

check_production=false
if [[ "$environment:$profile" == staging:shared ]]; then
  check_production=true
fi
environments="$profile"
if [[ "$profile" == shared ]]; then
  environments="production staging"
fi
printf 'profile=%s\ncheck-production=%s\nenvironments=%s\n' "$profile" "$check_production" "$environments"
