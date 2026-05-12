#!/usr/bin/env bash

set -euo pipefail

FP_TARGET_ROOT=""
FP_CONFIG_PATH=""
FP_VALIDATION_SKIP_PATHS=()
FP_MERGED_EXCLUDES=()

fp_default_excludes() {
  printf '%s\n' "*/.git/*" "*/node_modules/*" "*/.venv/*" "*/target/*"
}

fp_init() {
  local target="${1:-.}"
  FP_TARGET_ROOT="$(cd "$target" && pwd)"
  FP_CONFIG_PATH="${FP_TARGET_ROOT}/.guardrails.file-patterns.yml"
  FP_VALIDATION_SKIP_PATHS=()
  FP_MERGED_EXCLUDES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && FP_MERGED_EXCLUDES+=("$line")
  done < <(fp_default_excludes)

  if [[ -f "$FP_CONFIG_PATH" ]] && command -v yq >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -n "$line" && "$line" != "null" ]] && FP_MERGED_EXCLUDES+=("$line")
    done < <(yq -r '.global_excludes[]? // empty' "$FP_CONFIG_PATH" 2>/dev/null || true)

    while IFS= read -r line; do
      [[ -n "$line" && "$line" != "null" ]] && FP_VALIDATION_SKIP_PATHS+=("$line")
    done < <(yq -r '.validation_skip_paths[]? // empty' "$FP_CONFIG_PATH" 2>/dev/null || true)
  fi
}

fp_rel_path() {
  local abs="$1"
  printf '%s' "${abs#"$FP_TARGET_ROOT"/}"
}

fp_should_skip_validation() {
  local rel="$1"
  local pat
  for pat in ${FP_VALIDATION_SKIP_PATHS[@]+"${FP_VALIDATION_SKIP_PATHS[@]}"}; do
    [[ -z "$pat" ]] && continue
    if [[ "$rel" == $pat ]]; then
      return 0
    fi
    if [[ "/$rel" == $pat ]]; then
      return 0
    fi
  done
  return 1
}

fp_find_with_names() {
  local root="$1"
  shift
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  local find_args=()
  find_args+=(find "$root")
  local ex
  for ex in ${FP_MERGED_EXCLUDES[@]+"${FP_MERGED_EXCLUDES[@]}"}; do
    find_args+=(-not -path "$ex")
  done
  if [[ $# -eq 1 ]]; then
    find_args+=(-name "$1")
  else
    find_args+=("(")
    local first=true
    for n in "$@"; do
      if $first; then
        first=false
        find_args+=(-name "$n")
      else
        find_args+=(-o -name "$n")
      fi
    done
    find_args+=(")")
  fi
  find_args+=(-type f)
  "${find_args[@]}" 2>/dev/null || true
}

fp_find_workflow_yamls() {
  local wf="${FP_TARGET_ROOT}/.github/workflows"
  [[ -d "$wf" ]] || return 0
  fp_find_with_names "$wf" "*.yml" "*.yaml"
}

fp_find_dockerfiles() {
  fp_find_with_names "$FP_TARGET_ROOT" "Dockerfile" "Dockerfile.*"
}

fp_find_composite_actions() {
  local ad="${FP_TARGET_ROOT}/actions"
  [[ -d "$ad" ]] || return 0
  fp_find_with_names "$ad" "action.yml" "action.yaml"
}
