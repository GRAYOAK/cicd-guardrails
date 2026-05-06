#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${SCRIPT_DIR}/lib/feedback.sh"

PATH_ROOT="${1:-.}"
STRICT=false
[[ "${2:-}" == "--strict" ]] && STRICT=true
WORKFLOWS_DIR="${PATH_ROOT}/.github/workflows"
MISSING_RUNTIME=false

fb_init "CICD-SEC-05-07" "Runner configuration check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-05-Insufficient-PBAC/ , https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-07-Insecure-System-Configuration/"
fb_add_searched "Privileged container options in workflow jobs"
fb_add_searched "Generic self-hosted runner labels"
fb_add_searched "Use of sudo in run steps"

if ! command -v yq >/dev/null 2>&1; then
  MISSING_RUNTIME=true
  fb_report "error" "Missing required runtime dependency yq." "" "" \
    "Install yq in the runner environment before running this check."
  fb_summary
  exit "$(fb_exit_code "$STRICT" "$MISSING_RUNTIME")"
fi

shopt -s nullglob
files=("$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml)

if [[ ${#files[@]} -eq 0 ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "No workflow files found; no action required."
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  privileged_jobs="$(yq '.jobs | to_entries | .[] | select(.value.container.options != null) | select(.value.container.options | test("--privileged")) | .key' "$file" 2>/dev/null || true)"
  if [[ -n "$privileged_jobs" ]]; then
    while IFS= read -r job; do
      fb_report "error" "Job '${job}' uses privileged container options." "$rel" "" \
        "Avoid privileged mode and isolate sensitive steps on hardened runners."
    done <<<"$privileged_jobs"
  fi

  generic_jobs="$(yq '.jobs | to_entries | .[] | select(.value["runs-on"] == "self-hosted") | .key' "$file" 2>/dev/null || true)"
  if [[ -n "$generic_jobs" ]]; then
    while IFS= read -r job; do
      fb_report "warning" "Job '${job}' uses generic self-hosted runner labels." "$rel" "" \
        "Use explicit runner labels such as self-hosted, linux, and environment tags."
    done <<<"$generic_jobs"
  fi

  sudo_lines="$(rg -n "\\bsudo\\b" "$file" || true)"
  if [[ -n "$sudo_lines" ]]; then
    while IFS= read -r line; do
      line_num="${line%%:*}"
      fb_report "warning" "sudo command found in workflow step." "$rel" "$line_num" \
        "Remove sudo unless elevated privileges are required and reviewed."
    done <<<"$sudo_lines"
  fi
done

fb_auto_status "$STRICT"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT" false)"
