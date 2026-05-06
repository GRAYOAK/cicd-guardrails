#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_SCRIPTS_DIR}/lib/feedback.sh"
source "${ROOT_SCRIPTS_DIR}/checks/tech/github_branch_protection_api.sh"

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true
REPO="${GITHUB_REPOSITORY:-}"

fb_init "CICD-SEC-01-FLOW" "Flow control policy check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-01-Insufficient-Flow-Control-Mechanisms/"
fb_add_searched "Default branch metadata for the current repository"
fb_add_searched "Required pull request reviews and review counts"
fb_add_searched "Force push and branch deletion settings"

if [[ -z "$REPO" ]]; then
  fb_report "error" "GITHUB_REPOSITORY is not set." "" "" \
    "Run this check in GitHub Actions with repository context."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

if ! rt_msg="$(ghbp_require_runtime)"; then
  fb_report "error" "Runtime dependency is missing (${rt_msg})." "" "" \
    "Install gh and jq in the runner image."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" true)"
fi

if ! branch="$(ghbp_default_branch "$REPO")"; then
  fb_report "error" "Could not identify a valid default branch." "" "" \
    "Set a valid default branch and ensure API access to repository metadata."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

if ! protection="$(ghbp_read_protection "$REPO" "$branch")"; then
  if echo "$protection" | rg "404" >/dev/null 2>&1; then
    fb_report "error" "No branch protection rules are configured for '${branch}'." "" "" \
      "Require pull requests and at least one approval on the default branch."
    fb_auto_status "$STRICT"
    fb_summary
    exit "$(fb_exit_code "$STRICT" false)"
  elif echo "$protection" | rg "Upgrade to GitHub Pro or make this repository public" >/dev/null 2>&1; then
    fb_set_status "SKIPPED"
    fb_report "warning" "Branch protection endpoint unavailable for current repository plan." "" "" \
      "Use a plan that supports branch protection API checks."
    fb_summary
    exit "$(fb_exit_code "$STRICT" false)"
  elif echo "$protection" | rg "403|Must have admin rights" >/dev/null 2>&1; then
    fb_set_status "SKIPPED"
    fb_report "warning" "Token cannot read branch protection rules (403)." "" "" \
      "Pass admin token with branch protection read access to GH_TOKEN."
    fb_summary
    exit "$(fb_exit_code "$STRICT" false)"
  fi

  fb_report "error" "Unexpected GitHub API response while reading branch protection." "" "" \
    "Inspect API output and token permissions in workflow logs."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

required_pr_raw="$(echo "$protection" | jq -r '.required_pull_request_reviews // empty')"
if [[ -z "$required_pr_raw" ]]; then
  fb_report "error" "Pull request reviews are not required for '${branch}'." "" "" \
    "Enable required pull request reviews on the default branch."
else
  required_count="$(echo "$protection" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')"
  if [[ "$required_count" -lt 1 ]]; then
    fb_report "error" "Required approving review count is '${required_count}'." "" "" \
      "Set required approving review count to at least 1."
  else
    fb_report "notice" "Review approval threshold is set to ${required_count}." "" "" \
      "No remediation needed for review count."
  fi
fi

allow_force="$(echo "$protection" | jq -r '.allow_force_pushes.enabled // false')"
if [[ "$allow_force" == "true" ]]; then
  fb_report "error" "Force pushes are allowed on '${branch}'." "" "" \
    "Disable force pushes on the default branch."
fi

allow_delete="$(echo "$protection" | jq -r '.allow_deletions.enabled // false')"
if [[ "$allow_delete" == "true" ]]; then
  fb_report "warning" "Branch deletion is allowed on '${branch}'." "" "" \
    "Disable branch deletion for protected default branch."
fi

fb_auto_status "$STRICT"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT" false)"

