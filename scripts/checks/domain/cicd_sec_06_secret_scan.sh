#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${ROOT_SCRIPTS_DIR}/lib/feedback.sh"
# shellcheck source=scripts/lib/config.sh
source "${ROOT_SCRIPTS_DIR}/lib/config.sh"

PATH_ROOT="${1:-.}"
SEC06_REMEDIATION="Remove secrets from git history and replace with secure secret management."

fb_init "CICD-SEC-06-SECRET-SCAN" "Secret scan check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-06-Insufficient-Credential-Hygiene/"
cfg_init "$PATH_ROOT"
fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"
fb_add_searched "Repository source history and files for leaked secrets"
fb_add_searched "Patterns detected by gitleaks ruleset"

if [[ ! -x "./gitleaks" ]]; then
  fb_report "error" "gitleaks binary is not available in working directory." "" "" \
    "Install gitleaks before invoking this script."
  fb_auto_status false
  fb_summary
  exit "$(fb_exit_code false true)"
fi

if ! command -v jq >/dev/null 2>&1; then
  fb_report "error" "jq is not available." "" "" \
    "Install jq before invoking this script."
  fb_auto_status false
  fb_summary
  exit "$(fb_exit_code false true)"
fi

shallow_note="unknown"
if [[ -d "${PATH_ROOT}/.git" ]]; then
  if [[ -f "${PATH_ROOT}/.git/shallow" ]]; then
    shallow_note="yes (shallow clone)"
  else
    shallow_note="no"
  fi
fi

report_json="$(mktemp)"
output_file="$(mktemp)"
set +e
./gitleaks detect \
  --source "$PATH_ROOT" \
  --exit-code 1 \
  --report-path "$report_json" \
  --report-format json \
  --redact \
  >"$output_file" 2>&1
scan_code=$?
set -e

finding_count=0
if [[ -s "$report_json" ]] && jq -e 'type == "array" and length > 0' "$report_json" >/dev/null 2>&1; then
  while IFS=$'\t' read -r file line rule commit; do
    [[ -z "$file" && -z "$line" && -z "$rule" ]] && continue
    message="gitleaks rule \"${rule}\""
    if [[ -n "$commit" ]]; then
      message+=" (commit ${commit})"
    fi
    fb_report "error" "$message" "$file" "$line" "$SEC06_REMEDIATION" "gitleaks"
    finding_count=$((finding_count + 1))
  done < <(
    jq -r '
      [.[]
        | {
            file: (.File // ""),
            line: ((.StartLine // "") | tostring),
            rule: (.RuleID // "unknown"),
            commit: ((.Commit // "") | if length > 8 then .[0:8] else . end)
          }]
      | unique_by(.file + "\u0000" + .line + "\u0000" + .rule)
      | .[]
      | [.file, .line, .rule, .commit]
      | @tsv
    ' "$report_json" 2>/dev/null || true
  )
fi

if [[ $scan_code -eq 0 ]]; then
  fb_add_coverage "gitleaks detect on source path '${PATH_ROOT}' found no leaks; shallow clone metadata: ${shallow_note}."
  fb_add_remediation "No remediation needed."
  fb_auto_status false
  fb_summary
  rm -f "$output_file" "$report_json"
  exit "$(fb_exit_code false false)"
fi

if [[ $scan_code -eq 1 ]]; then
  if [[ $finding_count -eq 0 ]]; then
    fb_report "error" "Potential secret exposure detected by gitleaks." "" "" \
      "$SEC06_REMEDIATION"
  fi
  fb_add_coverage "gitleaks detect on source path '${PATH_ROOT}' reported ${finding_count} unique finding(s) (file, line, rule); shallow clone metadata: ${shallow_note}."
  fb_auto_status false
  fb_summary
  rm -f "$output_file" "$report_json"
  exit "$(fb_exit_code false false)"
fi

fb_report "error" "gitleaks failed unexpectedly with exit code ${scan_code}." "" "" \
  "Inspect runner logs and gitleaks installation."
fb_add_coverage "gitleaks detect on source path '${PATH_ROOT}' did not complete; shallow clone metadata: ${shallow_note}."
fb_auto_status false
fb_summary
rm -f "$output_file" "$report_json"
exit "$(fb_exit_code false true)"
