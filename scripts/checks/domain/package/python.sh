#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_audit_python_pyproject() {
  local path_root="$1"
  local manifest="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$manifest")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if ! pkg_has_any_lockfile "$manifest" "poetry.lock" "uv.lock"; then
    fb_report "error" "Missing poetry or uv lockfile next to pyproject.toml." "$rel" "" \
      "Generate and commit poetry.lock or uv.lock." "python"
  fi
}

cicd_sec_03_audit_python_requirements() {
  local path_root="$1"
  local req_file="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$req_file")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  local unpinned
  unpinned="$(grep -vE '^\s*(#|-r |--|-i |$)' "$req_file" | grep -v '==' || true)"
  if [[ -n "$unpinned" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      fb_report "error" "Unpinned python dependency '${line}'." "$rel" "" \
        "Pin each dependency with exact == version." "python"
    done <<<"$unpinned"
  fi
}

cicd_sec_03_audit_python_lock_poetry() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "poetry.lock is empty." "$rel" "" \
      "Run poetry lock and commit poetry.lock." "python"
  fi
}

cicd_sec_03_audit_python_lock_uv() {
  local path_root="$1"
  local lockfile="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$lockfile")"
  if fp_should_skip_validation "$rel"; then
    return 0
  fi
  if [[ ! -s "$lockfile" ]]; then
    fb_report "error" "uv.lock is empty." "$rel" "" \
      "Run uv lock and commit uv.lock." "python"
  fi
}
