#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_audit_js_ts_package_json() {
  local path_root="$1"
  local manifest="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$manifest")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if ! pkg_has_any_lockfile "$manifest" "package-lock.json" "yarn.lock" "pnpm-lock.yaml"; then
    fb_report "error" "Missing npm lockfile near package.json." "$rel" "" \
      "Generate and commit package-lock.json, yarn.lock, or pnpm-lock.yaml." "js_ts"
  fi
}

cicd_sec_03_audit_js_ts_lock_package_lock() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "package-lock.json is empty." "$rel" "" \
      "Regenerate package-lock.json with npm install." "js_ts"
    return 0
  fi
  if [[ $(wc -c <"$lockfile" 2>/dev/null || echo 0) -lt 64 ]]; then
    return 0
  fi
  if ! grep -qE '"lockfileVersion"[[:space:]]*:' "$lockfile" 2>/dev/null; then
    fb_report "error" "package-lock.json missing lockfileVersion (invalid lockfile)." "$rel" "" \
      "Regenerate package-lock.json with npm install." "js_ts"
  fi
}

cicd_sec_03_audit_js_ts_lock_yarn() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "yarn.lock is empty." "$rel" "" \
      "Regenerate yarn.lock with yarn install." "js_ts"
  fi
}

cicd_sec_03_audit_js_ts_lock_pnpm() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "pnpm-lock.yaml is empty." "$rel" "" \
      "Regenerate pnpm-lock.yaml with pnpm install." "js_ts"
    return 0
  fi
  if [[ $(wc -c <"$lockfile" 2>/dev/null || echo 0) -lt 64 ]]; then
    return 0
  fi
  if ! grep -qE '^lockfileVersion:' "$lockfile" 2>/dev/null; then
    fb_report "error" "pnpm-lock.yaml missing lockfileVersion header." "$rel" "" \
      "Regenerate pnpm-lock.yaml with pnpm install." "js_ts"
  fi
}
