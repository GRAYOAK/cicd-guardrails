#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_audit_go_mod() {
  local path_root="$1"
  local manifest="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$manifest")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if ! pkg_has_any_lockfile "$manifest" "go.sum"; then
    fb_report "error" "Missing go.sum next to go.mod." "$rel" "" \
      "Run go mod tidy and commit go.sum." "go"
  fi
}

cicd_sec_03_audit_go_sum() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "go.sum is empty." "$rel" "" \
      "Run go mod tidy and commit go.sum." "go"
  fi
}
