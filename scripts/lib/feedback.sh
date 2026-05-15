#!/usr/bin/env bash

set -euo pipefail

FB_CHECK_ID=""
FB_TITLE=""
FB_SEARCHED=""
FB_FOUND=""
FB_REMEDIATION=""
FB_ERROR_COUNT=0
FB_WARNING_COUNT=0
FB_NOTICE_COUNT=0
FB_STATUS="PASS"
FB_OWASP_REF=""
FB_MODE="fail"
FB_FOUND_ROWS=()
FB_FINDING_DETAIL_MARKDOWN=""
FB_COVERAGE=""
FB_SCAN_COVERAGE_MARKDOWN=""

fb__coverage_level() {
  case "${GUARDRAILS_COVERAGE:-compact}" in
    off) echo "off" ;;
    full) echo "full" ;;
    *) echo "compact" ;;
  esac
}

# Upper bound on relative paths listed per coverage bullet in compact mode.
fb_coverage_path_sample_limit() {
  case "$(fb__coverage_level)" in
    full) echo "${GUARDRAILS_COVERAGE_FULL_MAX_PATHS:-2000}" ;;
    *)
      local m="${GUARDRAILS_COVERAGE_MAX_PATHS:-15}"
      if [[ -z "$m" || ! "$m" =~ ^[0-9]+$ ]]; then
        m=15
      fi
      echo "$m"
      ;;
  esac
}

fb_add_coverage() {
  if [[ "$(fb__coverage_level)" == "off" ]]; then
    return 0
  fi
  local text="$1"
  [[ -z "$text" ]] && return 0
  FB_COVERAGE+="- ${text}"$'\n'
}

fb__json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

fb_write_result_json() {
  local out_dir="${GUARDRAILS_RESULT_DIR:-}"
  if [[ -z "$out_dir" ]]; then
    return 0
  fi

  mkdir -p "$out_dir"
  local fname="${FB_CHECK_ID//[^a-zA-Z0-9._-]/_}.json"
  local out_path="${out_dir%/}/${fname}"

  local owasp
  owasp="$(fb__json_escape "$FB_OWASP_REF")"
  local detail_json
  detail_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1] or ""))' "${FB_FINDING_DETAIL_MARKDOWN}")"
  local coverage_json
  coverage_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1] or ""))' "${FB_SCAN_COVERAGE_MARKDOWN:-}")"

  cat >"$out_path" <<EOF
{
  "check_id": "$(fb__json_escape "$FB_CHECK_ID")",
  "title": "$(fb__json_escape "$FB_TITLE")",
  "status": "$(fb__json_escape "$FB_STATUS")",
  "mode": "$(fb__json_escape "$FB_MODE")",
  "counts": {
    "errors": ${FB_ERROR_COUNT},
    "warnings": ${FB_WARNING_COUNT},
    "notices": ${FB_NOTICE_COUNT}
  },
  "owasp_reference": "${owasp}",
  "finding_detail_markdown": ${detail_json},
  "scan_coverage_markdown": ${coverage_json}
}
EOF
}

fb_init() {
  FB_CHECK_ID="$1"
  FB_TITLE="$2"
  FB_OWASP_REF="${3:-}"
  FB_SEARCHED=""
  FB_FOUND=""
  FB_REMEDIATION=""
  FB_ERROR_COUNT=0
  FB_WARNING_COUNT=0
  FB_NOTICE_COUNT=0
  FB_STATUS="PASS"
  FB_MODE="fail"
  FB_FOUND_ROWS=()
  FB_FINDING_DETAIL_MARKDOWN=""
  FB_COVERAGE=""
  FB_SCAN_COVERAGE_MARKDOWN=""
}

fb_add_searched() {
  local text="$1"
  FB_SEARCHED+="- ${text}"$'\n'
}

fb_add_remediation() {
  local text="$1"
  if [[ -z "$text" ]]; then
    return
  fi
  FB_REMEDIATION+="- ${text}"$'\n'
}

fb__annotation() {
  local severity="$1"
  local file="$2"
  local line="$3"
  local message="$4"

  if [[ -n "$file" && -n "$line" ]]; then
    echo "::${severity} file=${file},line=${line}::${message}"
  elif [[ -n "$file" ]]; then
    echo "::${severity} file=${file}::${message}"
  else
    echo "::${severity}::${message}"
  fi
}

fb_report() {
  local severity="$1"
  local message="$2"
  local file="${3:-}"
  local line="${4:-}"
  local remediation="${5:-}"
  local ecosystem="${6:-}"

  case "$severity" in
    error) FB_ERROR_COUNT=$((FB_ERROR_COUNT + 1)) ;;
    warning) FB_WARNING_COUNT=$((FB_WARNING_COUNT + 1)) ;;
    *) FB_NOTICE_COUNT=$((FB_NOTICE_COUNT + 1)) ;;
  esac

  fb__annotation "$severity" "$file" "$line" "$message"

  local display_line
  if [[ -n "$file" && -n "$line" ]]; then
    display_line="- [${severity}] ${file}:${line} - ${message}"
    FB_FOUND+="- [${severity}] ${file}:${line} - ${message}"$'\n'
  elif [[ -n "$file" ]]; then
    display_line="- [${severity}] ${file} - ${message}"
    FB_FOUND+="- [${severity}] ${file} - ${message}"$'\n'
  else
    display_line="- [${severity}] ${message}"
    FB_FOUND+="- [${severity}] ${message}"$'\n'
  fi

  if [[ -n "$ecosystem" && -n "$file" ]]; then
    local dir_part="${file%/*}"
    [[ "$dir_part" == "$file" ]] && dir_part="."
    FB_FOUND_ROWS+=("${ecosystem}|${dir_part}|${display_line}")
  fi

  fb_add_remediation "$remediation"
}

# Deduplicate remediation bullets (first-seen order) and add a short intro for the summary.
fb__remediation_for_summary() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    printf '%s' ""
    return 0
  fi
  local bullets
  bullets="$(printf '%s' "$raw" | awk '
    /^- / {
      line = substr($0, 3)
      if (!(line in seen)) {
        seen[line] = 1
        print "- " line
      }
    }
  ')"
  if [[ -z "$bullets" ]]; then
    printf '%s' ""
    return 0
  fi
  printf '%s\n\n%s' \
    "Apply the items below as needed for the findings above; each bullet is listed once even when many findings share the same fix." \
    "$bullets"
}

fb__render_grouped_found() {
  if [[ ${#FB_FOUND_ROWS[@]} -eq 0 ]]; then
    printf '%s' ""
    return 0
  fi
  local sorted
  sorted="$(printf '%s\n' "${FB_FOUND_ROWS[@]}" | LC_ALL=C sort -t'|' -k1,1 -k2,2)"
  local out="" cur_eco="" cur_dir=""
  while IFS='|' read -r eco dir line; do
    [[ -z "$eco" ]] && continue
    if [[ "$eco" != "$cur_eco" ]]; then
      [[ -n "$cur_eco" ]] && out+=$'\n'
      out+="#### ${eco}"$'\n\n'
      cur_eco="$eco"
      cur_dir=""
    fi
    if [[ "$dir" != "$cur_dir" ]]; then
      out+="- **${dir}/**"$'\n'
      cur_dir="$dir"
    fi
    out+="  ${line}"$'\n'
  done <<<"$sorted"
  printf '%s' "$out"
}

fb_set_status() {
  FB_STATUS="$1"
}

fb_set_owasp_ref() {
  FB_OWASP_REF="$1"
}

fb_auto_status() {
  local strict_mode="${1:-false}"

  if [[ "$FB_STATUS" == "SKIPPED" ]]; then
    return
  fi

  if [[ $FB_ERROR_COUNT -gt 0 ]]; then
    FB_STATUS="FAIL"
    return
  fi

  if [[ "$strict_mode" == "true" && $FB_WARNING_COUNT -gt 0 ]]; then
    FB_STATUS="FAIL"
    return
  fi

  if [[ $FB_WARNING_COUNT -gt 0 ]]; then
    FB_STATUS="WARN"
    return
  fi

  FB_STATUS="PASS"
}

# Record the per-check severity override read from .guardrails.yml.
# The actual status mutation happens automatically inside fb_summary so that
# every exit path (early SKIPPED, missing runtime, normal flow) honors it
# without scattering the override logic across check scripts.
# Allowed modes: fail (default) | warn | off.
fb_set_mode() {
  local mode="${1:-fail}"

  case "$mode" in
    fail|warn|off) FB_MODE="$mode" ;;
    *) FB_MODE="fail" ;;
  esac
}

# Apply the recorded mode to the current status and counts. Idempotent.
# warn: downgrade FAIL to WARN, rebucket error counts as warnings.
# off:  report SKIPPED with zero counts; emitted annotations remain visible.
fb_apply_check_mode() {
  case "$FB_MODE" in
    warn)
      if [[ "$FB_STATUS" == "FAIL" ]]; then
        FB_STATUS="WARN"
        FB_WARNING_COUNT=$((FB_WARNING_COUNT + FB_ERROR_COUNT))
        FB_ERROR_COUNT=0
      fi
      ;;
    off)
      FB_STATUS="SKIPPED"
      FB_ERROR_COUNT=0
      FB_WARNING_COUNT=0
      FB_NOTICE_COUNT=0
      ;;
  esac
}

fb_summary() {
  fb_apply_check_mode

  local searched_block="$FB_SEARCHED"
  local found_block="$FB_FOUND"
  local remediation_block="$FB_REMEDIATION"

  if [[ ${#FB_FOUND_ROWS[@]} -gt 0 ]]; then
    found_block="$(fb__render_grouped_found)"
    FB_FINDING_DETAIL_MARKDOWN="$found_block"
    if [[ ${#FB_FINDING_DETAIL_MARKDOWN} -gt 12000 ]]; then
      FB_FINDING_DETAIL_MARKDOWN="${FB_FINDING_DETAIL_MARKDOWN:0:12000}"$'\n\n…(truncated)'
    fi
  fi

  if [[ -z "$searched_block" ]]; then
    searched_block="- No explicit search scope provided."$'\n'
  fi
  if [[ -z "$found_block" ]]; then
    found_block="- No findings."$'\n'
  fi
  if [[ -n "$remediation_block" ]]; then
    remediation_block="$(fb__remediation_for_summary "$remediation_block")"
  fi
  if [[ -z "$remediation_block" ]]; then
    remediation_block="- No action required."$'\n'
  fi

  local cov_level
  cov_level="$(fb__coverage_level)"
  local coverage_block=""
  FB_SCAN_COVERAGE_MARKDOWN=""
  if [[ "$cov_level" != "off" ]]; then
    if [[ -n "${FB_COVERAGE:-}" ]]; then
      coverage_block="$FB_COVERAGE"
      if [[ ${#coverage_block} -gt 10000 ]]; then
        coverage_block="${coverage_block:0:10000}"$'\n\n…(truncated)'
      fi
    else
      coverage_block="- No scan coverage details recorded."$'\n'
    fi
    FB_SCAN_COVERAGE_MARKDOWN="$coverage_block"
  fi

  local report
  report="## ${FB_TITLE} (${FB_CHECK_ID})\n"
  report+="\n"
  report+="- Status: **${FB_STATUS}**\n"
  report+="- Mode: **${FB_MODE}**\n"
  report+="- Designation: **${FB_CHECK_ID}**\n"
  if [[ -n "$FB_OWASP_REF" ]]; then
    report+="- OWASP reference: ${FB_OWASP_REF}\n"
  fi
  report+="- Counts: errors=${FB_ERROR_COUNT}, warnings=${FB_WARNING_COUNT}, notices=${FB_NOTICE_COUNT}\n"
  report+="\n"
  report+="### Searched\n"
  report+="${searched_block}"
  report+="\n"
  if [[ "$cov_level" != "off" ]]; then
    report+="### Scan coverage\n"
    report+="${coverage_block}"
    report+="\n"
  fi
  report+="### Found\n"
  report+="${found_block}"
  report+="\n"
  report+="### Remediation\n"
  report+="${remediation_block}"

  printf "%b\n" "$report"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf "%b\n" "$report" >>"$GITHUB_STEP_SUMMARY"
  fi

  fb_write_result_json
}

fb_exit_code() {
  local strict_mode="${1:-false}"
  local missing_runtime="${2:-false}"

  # mode=off disables the check entirely, including infrastructure failures.
  if [[ "$FB_MODE" == "off" ]]; then
    echo 0
    return
  fi

  if [[ "$missing_runtime" == "true" ]]; then
    echo 2
    return
  fi

  if [[ "$FB_STATUS" == "SKIPPED" || "$FB_STATUS" == "PASS" ]]; then
    echo 0
    return
  fi

  # Per-check severity override takes precedence over the workflow-wide
  # strict input so that staged rollouts via .guardrails.yml work as intended.
  if [[ "$FB_MODE" == "warn" ]]; then
    echo 0
    return
  fi

  if [[ "$FB_STATUS" == "WARN" && "$strict_mode" != "true" ]]; then
    echo 0
    return
  fi

  echo 1
}
