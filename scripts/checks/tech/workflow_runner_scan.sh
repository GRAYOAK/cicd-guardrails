#!/usr/bin/env bash

set -euo pipefail

wrs_require_yq() {
  command -v yq >/dev/null 2>&1
}

wrs_list_workflow_files() {
  local path_root="$1"
  local workflows_dir="${path_root}/.github/workflows"
  shopt -s nullglob
  local files=("${workflows_dir}"/*.yml "${workflows_dir}"/*.yaml)
  printf "%s\n" "${files[@]}"
}

wrs_find_privileged_jobs() {
  local file="$1"
  yq '.jobs | to_entries | .[] | select(.value.container.options != null) | select(.value.container.options | test("--privileged")) | .key' "$file" 2>/dev/null || true
}

wrs_find_generic_self_hosted_jobs() {
  local file="$1"
  yq '.jobs | to_entries | .[] | select(.value["runs-on"] == "self-hosted") | .key' "$file" 2>/dev/null || true
}

wrs_find_sudo_lines() {
  local file="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -n "\\bsudo\\b" "$file" || true
  else
    grep -nE "\\<sudo\\>" "$file" || true
  fi
}

