#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_check_rust() {
  local path_root="$1"
  while IFS= read -r manifest; do
    local rel
    rel="$(pkg_rel_path "$path_root" "$manifest")"
    if ! pkg_has_any_lockfile "$manifest" "Cargo.lock"; then
      fb_report "error" "Missing Cargo.lock next to Cargo.toml." "$rel" "" \
        "Generate and commit Cargo.lock."
    fi
  done < <(find "$path_root" -name "Cargo.toml" -not -path "*/.git/*" -not -path "*/target/*" 2>/dev/null)
}
