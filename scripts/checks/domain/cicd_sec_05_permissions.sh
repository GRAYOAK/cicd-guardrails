#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${ROOT_SCRIPTS_DIR}/lib/feedback.sh"
# shellcheck source=scripts/lib/config.sh
source "${ROOT_SCRIPTS_DIR}/lib/config.sh"

PATH_ROOT="${1:-.}"
WORKFLOWS_DIR="${PATH_ROOT}/.github/workflows"
MISSING_RUNTIME=false

fb_init "CICD-SEC-05-PERMISSIONS" "Workflow permissions check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-05-Insufficient-PBAC/"
cfg_init "$PATH_ROOT"
fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"
fb_add_searched "Top-level permissions block in each workflow file"
fb_add_searched "Job-level permissions block for each job"

if ! command -v yq >/dev/null 2>&1; then
  MISSING_RUNTIME=true
  fb_report "error" "Missing required runtime dependency yq." "" "" \
    "Install yq in the runner environment before running this check."
  fb_summary
  exit "$(fb_exit_code false "$MISSING_RUNTIME")"
fi

shopt -s nullglob
files=("$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml)

if [[ ${#files[@]} -eq 0 ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "No workflow files found; no action required."
  fb_summary
  exit "$(fb_exit_code false false)"
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  if [[ "$(yq '.permissions' "$file")" == "null" ]]; then
    fb_report "error" "Top-level permissions block is missing." "$rel" "" \
      "Add top-level permissions with least privilege, for example read-all."
  fi

  missing="$(yq '.jobs | to_entries | .[] | select(.value.permissions == null) | .key' "$file")"
  if [[ -n "$missing" ]]; then
    while IFS= read -r job_id; do
      fb_report "error" "Job '${job_id}' is missing a permissions block." "$rel" "" \
        "Define minimal job-level permissions for this job."
    done <<<"$missing"
  fi
done

fb_auto_status false
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code false false)"
