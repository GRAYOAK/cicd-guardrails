#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_check_ruby() {
  local path_root="$1"
  while IFS= read -r manifest; do
    local rel
    rel="$(pkg_rel_path "$path_root" "$manifest")"
    if ! pkg_has_any_lockfile "$manifest" "Gemfile.lock"; then
      fb_report "error" "Missing Gemfile.lock next to Gemfile." "$rel" "" \
        "Generate and commit Gemfile.lock."
    fi
  done < <(find "$path_root" -name "Gemfile" -not -path "*/.git/*" 2>/dev/null)
}
