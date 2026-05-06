#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_SCRIPTS_DIR}/lib/feedback.sh"
source "${ROOT_SCRIPTS_DIR}/checks/tech/workflow_runner_scan.sh"

PATH_ROOT="${1:-.}"
STRICT=false
[[ "${2:-}" == "--strict" ]] && STRICT=true

fb_init "CICD-SEC-05-RUNNER-ACCESS" "Runner access policy check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-05-Insufficient-PBAC/"
fb_add_searched "Generic self-hosted runner labels in workflow jobs"

if ! wrs_require_yq; then
  fb_report "error" "Missing required runtime dependency yq." "" "" \
    "Install yq in the runner environment before running this check."
  fb_summary
  exit "$(fb_exit_code "$STRICT" true)"
fi

files=()
while IFS= read -r file; do
  [[ -n "$file" ]] && files+=("$file")
done < <(wrs_list_workflow_files "$PATH_ROOT")

if [[ ${#files[@]} -eq 0 ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "No workflow files found; no action required."
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"
  generic_jobs="$(wrs_find_generic_self_hosted_jobs "$file")"
  if [[ -n "$generic_jobs" ]]; then
    while IFS= read -r job; do
      fb_report "warning" "Job '${job}' uses generic self-hosted runner labels." "$rel" "" \
        "Use explicit runner labels such as self-hosted, linux, and environment tags."
    done <<<"$generic_jobs"
  fi
done

fb_auto_status "$STRICT"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT" false)"

