#!/usr/bin/env bash

# Loads merged Python package policy: shipped flat defaults plus optional
# package_policy.python from the scanned repo's .guardrails.file-patterns.yml.

set -euo pipefail

PACKAGE_POLICY_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PP_DEFAULTS_YML="${PACKAGE_POLICY_LIB}/../config/package_policy.defaults.yml"
PP_TARGET_ROOT=""
PP_PYTHON_MERGED_TMP=""

pp_cleanup() {
  if [[ -n "${PP_PYTHON_MERGED_TMP:-}" && -f "$PP_PYTHON_MERGED_TMP" ]]; then
    rm -f "$PP_PYTHON_MERGED_TMP"
  fi
  PP_PYTHON_MERGED_TMP=""
}

pp_init() {
  local target_root="${1:-.}"
  PP_TARGET_ROOT="$(cd "$target_root" && pwd)"
  pp_cleanup
  if [[ ! -f "$PP_DEFAULTS_YML" ]]; then
    return 0
  fi
  PP_PYTHON_MERGED_TMP="$(mktemp "${TMPDIR:-/tmp}/guardrails.pp.python.XXXXXX")"
  local overlay="${PP_TARGET_ROOT}/.guardrails.file-patterns.yml"
  if ! command -v yq >/dev/null 2>&1; then
    cp "$PP_DEFAULTS_YML" "$PP_PYTHON_MERGED_TMP"
    return 0
  fi
  if [[ -f "$overlay" ]]; then
    export PP_LOAD_DEFAULTS="$PP_DEFAULTS_YML"
    export PP_LOAD_OVERLAY="$overlay"
    if ! yq -n '(load(strenv(PP_LOAD_DEFAULTS)) // {}) * (load(strenv(PP_LOAD_OVERLAY)) | .package_policy.python // {})' >"$PP_PYTHON_MERGED_TMP" 2>/dev/null; then
      cp "$PP_DEFAULTS_YML" "$PP_PYTHON_MERGED_TMP"
    fi
    unset PP_LOAD_DEFAULTS PP_LOAD_OVERLAY
  else
    cp "$PP_DEFAULTS_YML" "$PP_PYTHON_MERGED_TMP"
  fi
}

pp_python_merged_file() {
  if [[ -n "${PP_PYTHON_MERGED_TMP:-}" && -f "$PP_PYTHON_MERGED_TMP" ]]; then
    printf '%s' "$PP_PYTHON_MERGED_TMP"
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
  if command -v yq >/dev/null 2>&1; then
    yq -r ".hash_validators[\"${basename}\"] // \"\"" "$mf" 2>/dev/null || true
  else
    pp__awk_validator_value "$mf" "$basename"
  fi
}
