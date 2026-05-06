#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_check_go() {
  local path_root="$1"
  while IFS= read -r manifest; do
    local rel
    rel="$(pkg_rel_path "$path_root" "$manifest")"
    if ! pkg_has_any_lockfile "$manifest" "go.sum"; then
      fb_report "error" "Missing go.sum next to go.mod." "$rel" "" \
        "Run go mod tidy and commit go.sum."
    fi
  done < <(find "$path_root" -name "go.mod" -not -path "*/.git/*" 2>/dev/null)
}
