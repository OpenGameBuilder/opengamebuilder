#!/usr/bin/env bash
set -euo pipefail

web_root="${1:?Pass the published wwwroot directory}"
if [ ! -f "$web_root/index.html" ] || [ ! -f "$web_root/appsettings.json" ]; then
  echo 'Published web root is missing index.html or appsettings.json.' >&2
  exit 1
fi

# The Release artifact must resolve its API from the browser origin. In particular,
# a fork must not ship an official host as its implicit API destination.
if grep -Eiq '"BaseUrl"[[:space:]]*:' "$web_root/appsettings.json"; then
  echo 'Default published configuration must not specify an API base URL.' >&2
  exit 1
fi
if grep -RiEq '(^|[^[:alnum:]])(www\.|staging\.)?opengamebuilder\.com' "$web_root"/appsettings*.json; then
  echo 'Published configuration references an official API host.' >&2
  exit 1
fi
shopt -s nullglob
environment_settings=("$web_root"/appsettings.*.json*)
if [ "${#environment_settings[@]}" -ne 0 ]; then
  echo 'Environment-specific API configuration was published.' >&2
  exit 1
fi

boot_scripts=("$web_root"/_framework/dotnet.*.js)
if [ "${#boot_scripts[@]}" -eq 0 ] ||
   ! grep -q '"applicationEnvironment": "Production"' "${boot_scripts[@]}"; then
  echo 'Published WASM bootstrap does not select Production.' >&2
  exit 1
fi
if grep -q 'appsettings.Development.json' "${boot_scripts[@]}"; then
  echo 'Published WASM bootstrap still references the Development API override.' >&2
  exit 1
fi
