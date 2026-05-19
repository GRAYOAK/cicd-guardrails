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

fb_init "CICD-SEC-04-POISONED-PIPELINE" "Poisoned pipeline check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-04-Poisoned-Pipeline-Execution/"
cfg_init "$PATH_ROOT"
fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"
fb_add_searched "Workflow files under ${WORKFLOWS_DIR}"
fb_add_searched "Unsafe trigger pattern pull_request_target outside comments"
fb_add_searched "Critical combination with head.sha or head.ref checkout"

shopt -s nullglob
files=("$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml)

if [[ ${#files[@]} -eq 0 ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "No workflow files found; no action required."
  fb_add_coverage "No workflow files matched ${WORKFLOWS_DIR}/*.yml or *.yaml."
  fb_summary
  exit "$(fb_exit_code false false)"
fi

lim="$(fb_coverage_path_sample_limit)"
cov_s="" cov_i=0
for file in "${files[@]}"; do
  cov_i=$((cov_i + 1))
  [[ $cov_i -gt $lim ]] && break
  rel="${file#"$PATH_ROOT/"}"
  cov_s="${cov_s:+$cov_s; }${rel}"
done
cov_more=""
[[ ${#files[@]} -gt $lim ]] && cov_more=" (+$((${#files[@]} - lim)) more)"
fb_add_coverage "pull_request_target scan: ${#files[@]} workflow file(s)${cov_s:+; sample: }${cov_s}${cov_more}"

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  findings="$(awk '
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/#.*$/, "", line)
      if (line ~ /pull_request_target/) {
        print NR ": " $0
      }
    }
  ' "$file")"

  if [[ -n "$findings" ]]; then
    while IFS= read -r match; do
      linenum="${match%%:*}"
      fb_report "error" "pull_request_target enables poisoned pipeline execution risk." "$rel" "$linenum" \
        "Use pull_request and avoid pull_request_target for untrusted pull requests."
    done <<<"$findings"

    if rg -n "pull_request\\.head\\.sha|pull_request\\.head\\.ref" "$file" >/dev/null 2>&1; then
      fb_report "error" "Critical path: trigger is combined with checkout of fork head refs." "$rel" "1" \
        "Remove head ref checkout for untrusted events and isolate privileged jobs."
    fi
  fi
done

fb_auto_status false
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code false false)"
