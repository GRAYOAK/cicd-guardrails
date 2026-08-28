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

cfg__resolve_check_id() {
  local check_id="$1"
  case "$check_id" in
    CICD-SEC-03) echo "CICD-SEC-03-DEPENDENCY-CHAIN" ;;
    CICD-SEC-04) echo "CICD-SEC-04-POISONED-PIPELINE" ;;
    CICD-SEC-06) echo "CICD-SEC-06-SECRET-SCAN" ;;
    CICD-SEC-08) echo "CICD-SEC-08-ACTION-PINNING" ;;
    *) echo "$check_id" ;;
  esac
}

cfg_check_mode() {
  local check_id="$1"
  local default="fail"

  if [[ -z "$check_id" ]]; then
    echo "$default"
    return 0
  fi

  check_id="$(cfg__resolve_check_id "$check_id")"

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

cfg__sec03_ecosystem_id_known() {
  case "$1" in
    javascript|python|dart|go|rust|ruby|php) return 0 ;;
    *) return 1 ;;
  esac
}

cfg__sec03_ecosystem_raw_value() {
  local ecosystem_id="$1"

  if ! cfg__sec03_ecosystem_id_known "$ecosystem_id" ||
      ! cfg__file_available ||
      ! cfg__yq_available; then
    return 0
  fi

  yq -r ".checks[\"CICD-SEC-03-DEPENDENCY-CHAIN\"].ecosystems[\"${ecosystem_id}\"] | select(. != null) | tostring" \
    "$CFG_PATH" 2>/dev/null || true
}

cfg_sec03_ecosystem_mode() {
  local ecosystem_id="$1"
  local default="fail"
  local val

  if ! cfg__sec03_ecosystem_id_known "$ecosystem_id"; then
    echo "$default"
    return 0
  fi

  val="$(cfg__sec03_ecosystem_raw_value "$ecosystem_id")"
  case "$val" in
    fail|off) echo "$val" ;;
    *) echo "$default" ;;
  esac
}

cfg_sec03_unsupported_mode() {
  local default="notice"
  local val

  if ! cfg__file_available || ! cfg__yq_available; then
    echo "$default"
    return 0
  fi

  val="$(yq -r '.checks["CICD-SEC-03-DEPENDENCY-CHAIN"].unsupported_ecosystems | select(. != null) | tostring' \
    "$CFG_PATH" 2>/dev/null || true)"
  case "$val" in
    notice|off) echo "$val" ;;
    *) echo "$default" ;;
  esac
}

cfg_sec03_unknown_ecosystem_keys() {
  local ecosystem_id

  if ! cfg__file_available || ! cfg__yq_available; then
    return 0
  fi

  while IFS= read -r ecosystem_id; do
    [[ -z "$ecosystem_id" ]] && continue
    cfg__sec03_ecosystem_id_known "$ecosystem_id" || printf '%s\n' "$ecosystem_id"
  done < <(
    yq -r '(.checks["CICD-SEC-03-DEPENDENCY-CHAIN"].ecosystems // {}) | keys | .[]' \
      "$CFG_PATH" 2>/dev/null || true
  )
}

cfg_sec03_invalid_ecosystem_values() {
  local ecosystem_id val

  for ecosystem_id in javascript python dart go rust ruby php; do
    val="$(cfg__sec03_ecosystem_raw_value "$ecosystem_id")"
    case "$val" in
      ""|fail|off) ;;
      *) printf '%s=%s\n' "$ecosystem_id" "$val" ;;
    esac
  done
}
