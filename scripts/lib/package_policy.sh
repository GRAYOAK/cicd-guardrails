#!/usr/bin/env bash

# Loads merged package policies: shipped defaults plus optional ecosystem
# overlays from the scanned repo's .guardrails.file-patterns.yml.

set -euo pipefail

PACKAGE_POLICY_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PP_DEFAULTS_YML="${PACKAGE_POLICY_LIB}/../config/package_policy.defaults.yml"
PP_TARGET_ROOT=""
PP_PYTHON_MERGED_TMP=""
PP_JAVASCRIPT_MERGED_TMP=""

pp_cleanup() {
  if [[ -n "${PP_PYTHON_MERGED_TMP:-}" && -f "$PP_PYTHON_MERGED_TMP" ]]; then
    rm -f "$PP_PYTHON_MERGED_TMP"
  fi
  if [[ -n "${PP_JAVASCRIPT_MERGED_TMP:-}" && -f "$PP_JAVASCRIPT_MERGED_TMP" ]]; then
    rm -f "$PP_JAVASCRIPT_MERGED_TMP"
  fi
  PP_PYTHON_MERGED_TMP=""
  PP_JAVASCRIPT_MERGED_TMP=""
}

pp__merge_policy() {
  local defaults="$1"
  local overlay_key="$2"
  local output="$3"
  local overlay="${PP_TARGET_ROOT}/.guardrails.file-patterns.yml"
  if ! command -v yq >/dev/null 2>&1 || [[ ! -f "$overlay" ]]; then
    cp "$defaults" "$output"
    return 0
  fi
  export PP_LOAD_DEFAULTS="$defaults"
  export PP_LOAD_OVERLAY="$overlay"
  export PP_OVERLAY_KEY="$overlay_key"
  if ! yq -n '(load(strenv(PP_LOAD_DEFAULTS)) // {}) * (load(strenv(PP_LOAD_OVERLAY)) | .package_policy[strenv(PP_OVERLAY_KEY)] // {})' >"$output" 2>/dev/null; then
    cp "$defaults" "$output"
  fi
  unset PP_LOAD_DEFAULTS PP_LOAD_OVERLAY PP_OVERLAY_KEY
}

pp_init() {
  local target_root="${1:-.}"
  PP_TARGET_ROOT="$(cd "$target_root" && pwd)"
  pp_cleanup
  if [[ ! -f "$PP_DEFAULTS_YML" ]]; then
    return 0
  fi
  PP_PYTHON_MERGED_TMP="$(mktemp "${TMPDIR:-/tmp}/guardrails.pp.python.XXXXXX")"
  pp__merge_policy "$PP_DEFAULTS_YML" "python" "$PP_PYTHON_MERGED_TMP"

  local javascript_defaults="${PACKAGE_POLICY_LIB}/../config/package_policy.javascript.defaults.yml"
  if [[ -f "$javascript_defaults" ]]; then
    PP_JAVASCRIPT_MERGED_TMP="$(mktemp "${TMPDIR:-/tmp}/guardrails.pp.javascript.XXXXXX")"
    pp__merge_policy "$javascript_defaults" "javascript" "$PP_JAVASCRIPT_MERGED_TMP"
  fi
}

pp_python_merged_file() {
  if [[ -n "${PP_PYTHON_MERGED_TMP:-}" && -f "$PP_PYTHON_MERGED_TMP" ]]; then
    printf '%s' "$PP_PYTHON_MERGED_TMP"
    return 0
  fi
  printf ''
}

pp_javascript_merged_file() {
  if [[ -n "${PP_JAVASCRIPT_MERGED_TMP:-}" && -f "$PP_JAVASCRIPT_MERGED_TMP" ]]; then
    printf '%s' "$PP_JAVASCRIPT_MERGED_TMP"
    return 0
  fi
  printf ''
}

pp__awk_string_list() {
  local mf="$1"
  local key="$2"
  awk -v key="$key" '
    $0 ~ "^" key ":" { g = 1; next }
    g && /^[a-zA-Z@]/ && $0 !~ /^  / { exit }
    g && /^  - / { sub(/^  - /, "", $0); print }
  ' "$mf"
}

pp__awk_validator_value() {
  local mf="$1"
  local bn="$2"
  awk -v bn="$bn" '
    /^hash_validators:/ { g = 1; next }
    g && /^[a-zA-Z@]/ && $0 !~ /^  / { exit }
    g && $0 ~ "^  " {
      split($0, parts, ":")
      key = parts[1]
      gsub(/^ +/, "", key)
      if (key == bn) {
        val = $0
        sub(/^[^:]+:[[:space:]]*/, "", val)
        print val
        exit
      }
    }
  ' "$mf"
}

pp__validator_value() {
  local mf="$1"
  local basename="$2"
  if command -v yq >/dev/null 2>&1; then
    export PP_LOOKUP_BASENAME="$basename"
    yq -r '.hash_validators[strenv(PP_LOOKUP_BASENAME)] // ""' "$mf" 2>/dev/null || true
    unset PP_LOOKUP_BASENAME
  else
    pp__awk_validator_value "$mf" "$basename"
  fi
}

pp__awk_nested_string_lists() {
  local mf="$1"
  local key="$2"
  awk -v key="$key" '
    $0 ~ "^" key ":" { g = 1; next }
    g && /^[a-zA-Z@]/ && $0 !~ /^  / { exit }
    g && /^  - - / {
      if (combo != "") print combo
      sub(/^  - - /, "", $0)
      combo = $0
      next
    }
    g && /^    - / {
      sub(/^    - /, "", $0)
      combo = combo " " $0
    }
    END { if (combo != "") print combo }
  ' "$mf"
}

pp_python_trigger_names() {
  local mf
  mf="$(pp_python_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  if command -v yq >/dev/null 2>&1; then
    yq -r '(.triggers // [])[]' "$mf" 2>/dev/null || true
  else
    pp__awk_string_list "$mf" "triggers"
  fi
}

pp_python_satisfier_names() {
  local mf
  mf="$(pp_python_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  if command -v yq >/dev/null 2>&1; then
    yq -r '(.satisfiers // [])[]' "$mf" 2>/dev/null || true
  else
    pp__awk_string_list "$mf" "satisfiers"
  fi
}

pp_python_validator_for() {
  local basename="$1"
  local mf
  mf="$(pp_python_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  pp__validator_value "$mf" "$basename"
}

pp_javascript_trigger_names() {
  local mf
  mf="$(pp_javascript_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  if command -v yq >/dev/null 2>&1; then
    yq -r '(.triggers // [])[]' "$mf" 2>/dev/null || true
  else
    pp__awk_string_list "$mf" "triggers"
  fi
}

pp_javascript_satisfier_names() {
  local mf
  mf="$(pp_javascript_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  if command -v yq >/dev/null 2>&1; then
    yq -r '(.satisfiers // [])[]' "$mf" 2>/dev/null || true
  else
    pp__awk_string_list "$mf" "satisfiers"
  fi
}

pp_javascript_allowed_combo_sorted_space_lines() {
  local mf
  mf="$(pp_javascript_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  if command -v yq >/dev/null 2>&1; then
    local json_lines
    if ! json_lines="$(yq -o=json -I=0 '(.allowed_trigger_combinations // [])[]' "$mf" 2>/dev/null)"; then
      pp_javascript_allowed_combo_sorted_space_lines_fallback "$mf"
      return 0
    fi
    while IFS= read -r j; do
      [[ -z "$j" || "$j" == "null" ]] && continue
      python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.argv[1]))))' "$j" 2>/dev/null || true
    done <<<"$json_lines"
  else
    pp_javascript_allowed_combo_sorted_space_lines_fallback "$mf"
  fi
}

pp_javascript_allowed_combo_sorted_space_lines_fallback() {
  local mf="$1"
  local combo
  while IFS= read -r combo; do
    [[ -z "$combo" ]] && continue
    python3 -c 'import sys; print(" ".join(sorted(sys.argv[1].split())))' "$combo"
  done < <(pp__awk_nested_string_lists "$mf" "allowed_trigger_combinations")
}

pp_javascript_validator_for() {
  local basename="$1"
  local mf
  mf="$(pp_javascript_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  pp__validator_value "$mf" "$basename"
}
