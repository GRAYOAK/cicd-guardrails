#!/usr/bin/env bash

# Centralized reader for .guardrails.yml in the target repository.
# Provides context lookups and per-check mode overrides used by all checks
# and by the aggregate risk summary. Conservative defaults apply when the
# file or yq are unavailable, so checks remain safe in degraded environments.

CFG_TARGET_DIR=""
CFG_PATH=""

cfg_init() {
  CFG_TARGET_DIR="${1:-.}"
  CFG_PATH="${CFG_TARGET_DIR%/}/.guardrails.yml"
}

cfg__yq_available() {
  command -v yq >/dev/null 2>&1
}

cfg__file_available() {
  [[ -n "$CFG_PATH" && -f "$CFG_PATH" ]]
}

cfg_context() {
  local key="$1"
  local default="${2:-unknown}"

  if ! cfg__file_available || ! cfg__yq_available; then
    echo "$default"
    return 0
  fi

  local val
  val="$(yq -r "$key // \"\"" "$CFG_PATH" 2>/dev/null || true)"
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "$default"
  else
    echo "$val"
  fi
}

cfg_check_mode() {
  local check_id="$1"
  local default="fail"

  if [[ -z "$check_id" ]]; then
    echo "$default"
    return 0
  fi

  if ! cfg__file_available || ! cfg__yq_available; then
    echo "$default"
    return 0
  fi

  local val
  val="$(yq -r ".checks[\"${check_id}\"].mode // \"\"" "$CFG_PATH" 2>/dev/null || true)"
  case "$val" in
    fail|warn|off) echo "$val" ;;
    *) echo "$default" ;;
  esac
}
