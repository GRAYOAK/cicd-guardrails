#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_audit_rust_cargo_toml() {
  local path_root="$1"
  local manifest="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$manifest")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if ! pkg_has_any_lockfile "$manifest" "Cargo.lock"; then
    fb_report "error" "Missing Cargo.lock next to Cargo.toml." "$rel" "" \
      "Generate and commit Cargo.lock." "rust"
  fi
}

cicd_sec_03_audit_rust_cargo_lock() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "Cargo.lock is empty." "$rel" "" \
      "Run cargo generate-lockfile and commit Cargo.lock." "rust"
    return 0
  fi
  if [[ $(wc -c <"$lockfile" 2>/dev/null || echo 0) -lt 80 ]]; then
    return 0
  fi
  if ! grep -qE '^version = ' "$lockfile" 2>/dev/null; then
    fb_report "error" "Cargo.lock appears invalid." "$rel" "" \
      "Run cargo generate-lockfile and commit Cargo.lock." "rust"
  fi
}
