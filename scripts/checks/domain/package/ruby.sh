#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_audit_ruby_gemfile() {
  local path_root="$1"
  local manifest="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$manifest")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if ! pkg_has_any_lockfile "$manifest" "Gemfile.lock"; then
    fb_report "error" "Missing Gemfile.lock next to Gemfile." "$rel" "" \
      "Generate and commit Gemfile.lock." "ruby"
  fi
}

cicd_sec_03_audit_ruby_gemfile_lock() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "Gemfile.lock is empty." "$rel" "" \
      "Run bundle install and commit Gemfile.lock." "ruby"
  fi
}
