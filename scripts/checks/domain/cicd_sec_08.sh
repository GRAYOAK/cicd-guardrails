#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${ROOT_SCRIPTS_DIR}/lib/feedback.sh"
# shellcheck source=scripts/lib/config.sh
source "${ROOT_SCRIPTS_DIR}/lib/config.sh"
# shellcheck source=scripts/lib/file_patterns.sh
source "${ROOT_SCRIPTS_DIR}/lib/file_patterns.sh"
# shellcheck source=scripts/lib/action_pin_audit.sh
source "${ROOT_SCRIPTS_DIR}/lib/action_pin_audit.sh"

PATH_ROOT_ARG="${1:-.}"
PATH_ROOT="$(cd "$PATH_ROOT_ARG" && pwd)"

fb_init "CICD-SEC-08" "Action pinning check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-08-Ungoverned-Usage-of-3rd-Party-Services/"
cfg_init "$PATH_ROOT"
fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"

if [[ "$FB_MODE" == "off" ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "Check disabled via configuration."
  fb_summary
  exit "$(fb_exit_code false false)"
fi

fp_init "$PATH_ROOT"

fb_add_searched "Composite action definitions under actions/ directory"
fb_add_searched "uses: references that are not pinned to a full 40-char SHA"
fb_add_searched "Disallowed refs such as tags, branches, latest, or missing @"

files=()
while IFS= read -r f; do
  [[ -n "$f" ]] && files+=("$f")
done < <(fp_find_composite_actions)

if [[ ${#files[@]} -eq 0 ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "No composite action files under actions/; no action required."
  fb_summary
  exit "$(fb_exit_code false false)"
fi

for file in "${files[@]}"; do
  action_pin_scan_file "$PATH_ROOT" "$file" "composite-action" || true
done

fb_auto_status false
if [[ "$FB_STATUS" != "PASS" ]]; then
  fb_add_remediation "Example: uses: actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd"
  fb_add_remediation "Use automation to keep pinned SHAs updated."
else
  fb_add_remediation "No remediation needed."
fi

fb_summary
exit "$(fb_exit_code false false)"
