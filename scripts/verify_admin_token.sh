#!/usr/bin/env bash
# Verifies PAT passed into the reusable workflow can read repository metadata
# and the branch protection API for the calling repository (CI).
#
# Optional env (from workflow):
#   GH_TOKEN               token used by gh
#   GUARDRAILS_HAS_ADMIN_SECRET  "true" if admin-token was passed
#   GITHUB_REPOSITORY      set by Actions
#
# Usage: bash verify_admin_token.sh [--strict]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

REPO="${GITHUB_REPOSITORY:-}"
HAS_ADMIN_SECRET="${GUARDRAILS_HAS_ADMIN_SECRET:-false}"

gh_error()   { echo "::error::$1";   }
gh_warning() { echo "::warning::$1"; }

summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
  fi
}

verify_token() {
  local repo_json prot_out api_msg branch viewer_login perm_pull perm_push perm_admin perm_maintain

  if ! repo_json="$(gh api "repos/${REPO}" 2>&1)"; then
    gh_error "Cannot read repository metadata or token invalid: $(echo "$repo_json" | tr '\n' ' ' | cut -c1-400) (CICD-SEC-05-VERIFY)"
    return 1
  fi
  if ! echo "$repo_json" | jq -e . >/dev/null 2>&1; then
    gh_error "Repository metadata is not valid JSON: $(echo "$repo_json" | tr '\n' ' ' | cut -c1-400) (CICD-SEC-05-VERIFY)"
    return 1
  fi
  api_msg="$(echo "$repo_json" | jq -r '.message // empty')"
  if [[ -n "$api_msg" ]]; then
    gh_error "GitHub API: ${api_msg} (CICD-SEC-05-VERIFY)"
    return 1
  fi
  viewer_login="$(gh api user --jq '.login' 2>/dev/null || true)"
  perm_pull="$(echo "$repo_json" | jq -r '.permissions.pull // false')"
  perm_push="$(echo "$repo_json" | jq -r '.permissions.push // false')"
  perm_admin="$(echo "$repo_json" | jq -r '.permissions.admin // false')"
  perm_maintain="$(echo "$repo_json" | jq -r '.permissions.maintain // false')"
  branch="$(echo "$repo_json" | jq -r 'if (.default_branch | type) == "string" and (.default_branch | length) > 0 then .default_branch else empty end')"
  if [[ -z "$branch" ]]; then
    gh_error "No default_branch in repository metadata. (CICD-SEC-05-VERIFY)"
    return 1
  fi
  if ! prot_out="$(gh api "repos/${REPO}/branches/${branch}/protection" 2>&1)"; then
    if echo "$prot_out" | grep -q "Upgrade to GitHub Pro or make this repository public"; then
      gh_warning "Branch protection check skipped: feature unavailable for this repository plan (private repo without required GitHub plan). (CICD-SEC-05-VERIFY)"
      summary "Result: **SKIPPED** (branch protection endpoint unavailable for current repository plan)."
      return 0
    elif echo "$prot_out" | grep -q "403\|Must have admin rights"; then
      gh_error "Branch protection API returned 403 for '${REPO}'. Ensure this token can read protection rules on this repository and is authorized for SAML SSO if required. (CICD-SEC-05-VERIFY)"
      summary ""
      summary "**403:** API denied. Repo: \`${REPO}\`."
      summary "- token user: \`${viewer_login:-unknown}\`"
      summary "- repo permissions from /repos endpoint: pull=\`${perm_pull}\`, push=\`${perm_push}\`, maintain=\`${perm_maintain}\`, admin=\`${perm_admin}\`"
      summary "- raw API message: \`$(echo "$prot_out" | tr '\n' ' ' | cut -c1-350)\`"
      return 1
    elif echo "$prot_out" | grep -q "404"; then
      echo "OK: branch protection API reachable (no rules on '${branch}' → HTTP 404)."
      summary "Result: **PASS** (404 = no protection rules configured)."
      return 0
    fi
    gh_error "Unexpected branch protection response: $(echo "$prot_out" | tr '\n' ' ' | cut -c1-500) (CICD-SEC-05-VERIFY)"
    return 1
  fi
  echo "OK: branch protection readable for '${REPO}@${branch}'."
  summary "Result: **PASS** (protection payload returned)."
  return 0
}

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  summary "## Admin token check (CICD-SEC-05-VERIFY)"
  summary ""
  summary "- Repository: \`${REPO:-<unset>}\`"
  summary "- Event: \`${GITHUB_EVENT_NAME:-unknown}\`"
  summary "- Admin token passed into reusable workflow: \`${HAS_ADMIN_SECRET}\`"
  summary ""
fi

if [[ -z "$REPO" ]]; then
  gh_error "GITHUB_REPOSITORY is not set. (CICD-SEC-05-VERIFY)"
  exit 1
fi

if [[ "$HAS_ADMIN_SECRET" != "true" ]]; then
  msg="No admin PAT was passed into this reusable workflow. Map GUARDRAILS_ADMIN_TOKEN in the caller to admin-token. Fork pull_request runs often have no secrets. (CICD-SEC-05-VERIFY)"
  if [[ "$STRICT" == "true" ]]; then
    gh_error "$msg"
    summary ""
    summary "**Hint:** Pass at least one non-empty secret from the caller repository."
    exit 1
  fi
  gh_warning "$msg"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  gh_error "gh CLI is missing. (CICD-SEC-05-VERIFY)"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  gh_error "jq is missing. (CICD-SEC-05-VERIFY)"
  exit 1
fi

if ! verify_token; then
  if [[ "$STRICT" == "true" ]]; then
    gh_error "Admin token check failed (see logs and job summary). (CICD-SEC-05-VERIFY)"
    summary "Result: **FAIL**"
    exit 1
  fi
  gh_warning "Admin token check failed; continuing because strict mode is off. (CICD-SEC-05-VERIFY)"
  summary "Result: **WARN** (non-strict: failures do not fail the job)"
  exit 0
fi

exit 0
