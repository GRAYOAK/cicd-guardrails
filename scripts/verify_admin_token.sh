#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${SCRIPT_DIR}/lib/feedback.sh"

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

REPO="${GITHUB_REPOSITORY:-}"
HAS_ADMIN_SECRET="${GUARDRAILS_HAS_ADMIN_SECRET:-false}"

fb_init "CICD-SEC-05-VERIFY" "Admin token check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-05-Insufficient-PBAC/"
fb_add_searched "Repository metadata API access"
fb_add_searched "Branch protection API access for repository default branch"
fb_add_searched "Presence of admin token mapping in reusable workflow"

if [[ -z "$REPO" ]]; then
  fb_report "error" "GITHUB_REPOSITORY is not set." "" "" \
    "Run this check in GitHub Actions with repository context."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

if [[ "$HAS_ADMIN_SECRET" != "true" ]]; then
  fb_report "warning" "No admin token was passed into this reusable workflow." "" "" \
    "Map caller secret GUARDRAILS_ADMIN_TOKEN to admin-token for full verification."
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

if ! repo_json="$(gh api "repos/${REPO}" 2>&1)"; then
  fb_report "error" "Cannot read repository metadata with provided token." "" "" \
    "Grant token repository read access and ensure SSO authorization if required."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

if ! echo "$repo_json" | jq -e . >/dev/null 2>&1; then
  fb_report "error" "Repository metadata response is not valid JSON." "" "" \
    "Verify token, repository access, and API response integrity."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

api_msg="$(echo "$repo_json" | jq -r '.message // empty')"
if [[ -n "$api_msg" ]]; then
  fb_report "error" "GitHub API returned an error: ${api_msg}." "" "" \
    "Use a token with sufficient permissions for repository metadata and branch protection."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

branch="$(echo "$repo_json" | jq -r 'if (.default_branch | type) == "string" and (.default_branch | length) > 0 then .default_branch else empty end')"
if [[ -z "$branch" ]]; then
  fb_report "error" "No default branch found in repository metadata." "" "" \
    "Set a valid default branch in repository settings."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

if ! prot_out="$(gh api "repos/${REPO}/branches/${branch}/protection" 2>&1)"; then
  if echo "$prot_out" | rg "Upgrade to GitHub Pro or make this repository public" >/dev/null 2>&1; then
    fb_set_status "SKIPPED"
    fb_report "notice" "Branch protection endpoint is unavailable for current repository plan." "" "" \
      "Use repository plan that supports branch protection API when strict verification is required."
    fb_summary
    exit "$(fb_exit_code "$STRICT" false)"
  elif echo "$prot_out" | rg "403|Must have admin rights" >/dev/null 2>&1; then
    fb_report "error" "Token cannot read branch protection rules (403)." "" "" \
      "Grant admin or maintain-level access and ensure SSO authorization for the token identity."
    fb_auto_status "$STRICT"
    fb_summary
    exit "$(fb_exit_code "$STRICT" false)"
  elif echo "$prot_out" | rg "404" >/dev/null 2>&1; then
    fb_report "notice" "Branch protection endpoint is reachable and no rules are configured (404)." "" "" \
      "Configure branch protection rules if your policy requires them."
    fb_auto_status "$STRICT"
    fb_summary
    exit "$(fb_exit_code "$STRICT" false)"
  fi

  fb_report "error" "Unexpected branch protection API response." "" "" \
    "Inspect workflow logs and token permissions for API access failures."
  fb_auto_status "$STRICT"
  fb_summary
  exit "$(fb_exit_code "$STRICT" false)"
fi

fb_report "notice" "Branch protection payload is readable for ${REPO}@${branch}." "" "" \
  "No remediation needed for token access."
fb_auto_status "$STRICT"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT" false)"
