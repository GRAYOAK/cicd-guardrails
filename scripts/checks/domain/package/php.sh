#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_check_php() {
  local path_root="$1"
  while IFS= read -r manifest; do
    local rel
    rel="$(pkg_rel_path "$path_root" "$manifest")"
    if ! pkg_has_any_lockfile "$manifest" "composer.lock"; then
      fb_report "error" "Missing composer.lock next to composer.json." "$rel" "" \
        "Run composer install and commit composer.lock."
    fi
  done < <(find "$path_root" -name "composer.json" -not -path "*/.git/*" 2>/dev/null)
}
