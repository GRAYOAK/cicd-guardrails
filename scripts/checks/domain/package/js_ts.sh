#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_check_js_ts() {
  local path_root="$1"
  while IFS= read -r manifest; do
    local rel
    rel="$(pkg_rel_path "$path_root" "$manifest")"
    if ! pkg_has_any_lockfile "$manifest" "package-lock.json" "yarn.lock" "pnpm-lock.yaml"; then
      fb_report "error" "Missing npm lockfile near package.json." "$rel" "" \
        "Generate and commit package-lock.json, yarn.lock, or pnpm-lock.yaml."
    fi
  done < <(find "$path_root" -name "package.json" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)
}
