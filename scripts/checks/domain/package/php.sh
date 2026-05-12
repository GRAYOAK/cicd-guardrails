#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_audit_php_composer_json() {
  local path_root="$1"
  local manifest="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$manifest")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if ! pkg_has_any_lockfile "$manifest" "composer.lock"; then
    fb_report "error" "Missing composer.lock next to composer.json." "$rel" "" \
      "Run composer install and commit composer.lock." "php"
  fi
}

cicd_sec_03_audit_php_composer_lock() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "composer.lock is empty." "$rel" "" \
      "Run composer install and commit composer.lock." "php"
    return 0
  fi
  if [[ $(wc -c <"$lockfile" 2>/dev/null || echo 0) -lt 120 ]]; then
    return 0
  fi
  if ! grep -qE '"packages"' "$lockfile" 2>/dev/null; then
    fb_report "error" "composer.lock missing packages section (invalid lockfile)." "$rel" "" \
      "Run composer install and commit composer.lock." "php"
  fi
}
