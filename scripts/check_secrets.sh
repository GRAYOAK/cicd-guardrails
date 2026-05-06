#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${SCRIPT_DIR}/lib/feedback.sh"

PATH_ROOT="${1:-.}"

fb_init "CICD-SEC-06" "Secret scanning check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-06-Insufficient-Credential-Hygiene/"
fb_add_searched "Repository source history and files for leaked secrets"
fb_add_searched "Patterns detected by gitleaks ruleset"

if [[ ! -x "./gitleaks" ]]; then
  fb_report "error" "gitleaks binary is not available in working directory." "" "" \
    "Install gitleaks before invoking this script."
  fb_auto_status false
  fb_summary
  exit "$(fb_exit_code false true)"
fi

output_file="$(mktemp)"
set +e
./gitleaks detect --source "$PATH_ROOT" --exit-code 1 --redact >"$output_file" 2>&1
scan_code=$?
set -e

if [[ $scan_code -eq 0 ]]; then
  fb_add_remediation "No remediation needed."
  fb_auto_status false
  fb_summary
  rm -f "$output_file"
  exit 0
fi

if [[ $scan_code -eq 1 ]]; then
  fb_report "error" "Potential secret exposure detected by gitleaks." "" "" \
    "Remove secrets from git history and replace with secure secret management."
  if [[ -s "$output_file" ]]; then
    snippet="$(sed -n '1,25p' "$output_file" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')"
    fb_report "notice" "gitleaks output snippet: ${snippet}" "" "" \
      "Review full workflow logs for complete findings."
  fi
  fb_auto_status false
  fb_summary
  rm -f "$output_file"
  exit 1
fi

fb_report "error" "gitleaks failed unexpectedly with exit code ${scan_code}." "" "" \
  "Inspect runner logs and gitleaks installation."
fb_auto_status false
fb_summary
rm -f "$output_file"
exit 1
