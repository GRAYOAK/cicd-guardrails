#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${SCRIPT_DIR}/lib/feedback.sh"

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

REPO="${GITHUB_REPOSITORY:-}"

fb_init "CICD-SEC-05" "Branch protection policy check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-05-Insufficient-PBAC/"
fb_add_searched "Default branch metadata for the current repository"
fb_add_searched "Required pull request reviews and review counts"
fb_add_searched "Force push, branch deletion, and admin bypass settings"

if [[ -z "$REPO" ]]; then
  fb_report "error" "GITHUB_REPOSITORY is not set." "" "" \
    "Run this check in GitHub Actions with repository context."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

if ! command -v gh >/dev/null 2>&1; then
  fb_report "error" "gh CLI is missing." "" "" "Install gh in the runner image."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" true)"
fi

if ! command -v jq >/dev/null 2>&1; then
  fb_report "error" "jq is missing." "" "" "Install jq in the runner image."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" true)"
fi

branch=""
repo_json=""
if repo_json="$(gh api "repos/${REPO}" 2>&1)" && echo "$repo_json" | jq -e . >/dev/null 2>&1; then
  branch="$(echo "$repo_json" | jq -r 'if (.default_branch | type) == "string" and (.default_branch | length) > 0 then .default_branch else empty end')"
fi

if [[ -z "$branch" ]]; then
  for candidate in main master; do
    if gh api "repos/${REPO}/branches/${candidate}" >/dev/null 2>&1; then
      branch="$candidate"
      break
    fi
  done
fi

if [[ -z "$branch" ]]; then
  fb_report "error" "Could not identify a valid default branch." "" "" \
    "Set a valid default branch and ensure API access to repository metadata."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

if ! protection="$(gh api "repos/${REPO}/branches/${branch}/protection" 2>&1)"; then
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

  dismiss_stale="$(echo "$protection" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')"
  if [[ "$dismiss_stale" != "true" ]]; then
    fb_report "warning" "Stale pull request approvals are not dismissed automatically." "" "" \
      "Enable stale approval dismissal for safer review guarantees."
  fi

  codeowner="$(echo "$protection" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')"
  if [[ "$codeowner" != "true" ]]; then
    fb_report "notice" "Code owner reviews are not required." "" "" \
      "Enable code owner reviews for critical paths when applicable."
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

enforce_admins="$(echo "$protection" | jq -r '.enforce_admins.enabled // false')"
if [[ "$enforce_admins" != "true" ]]; then
  fb_report "warning" "Admins can bypass branch protection rules." "" "" \
    "Enable admin enforcement so rules apply to all users."
fi

fb_auto_status "$STRICT"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT" false)"
