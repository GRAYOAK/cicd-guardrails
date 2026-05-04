#!/usr/bin/env bash
# Verifies PAT(s) passed into the reusable workflow can read repository metadata
# and the branch protection API for the calling repository (CI).
#
# Optional env (from workflow):
#   GUARDRAILS_PAT_CLASSIC   classic PAT (maps to admin-token)
#   GUARDRAILS_PAT_FG      fine-grained PAT (maps to admin-token-fg)
#   GITHUB_REPOSITORY      set by Actions
#
# If both are set, both are checked. In --strict, every supplied token must pass.
#
# Usage: bash verify_admin_token.sh [--strict]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

REPO="${GITHUB_REPOSITORY:-}"
CLASSIC="${GUARDRAILS_PAT_CLASSIC:-}"
FG="${GUARDRAILS_PAT_FG:-}"

gh_error()   { echo "::error::$1";   }
gh_warning() { echo "::warning::$1"; }

summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
  fi
}

verify_one() {
  local label="$1"
  local token="$2"
  local repo_json prot_out api_msg branch

  if ! repo_json="$(GH_TOKEN="$token" gh api "repos/${REPO}" 2>&1)"; then
    gh_error "[${label}] Cannot read repository metadata or token invalid: $(echo "$repo_json" | tr '\n' ' ' | cut -c1-400) (CICD-SEC-05-VERIFY)"
    return 1
  fi
  if ! echo "$repo_json" | jq -e . >/dev/null 2>&1; then
    gh_error "[${label}] Repository metadata is not valid JSON: $(echo "$repo_json" | tr '\n' ' ' | cut -c1-400) (CICD-SEC-05-VERIFY)"
    return 1
  fi
  api_msg="$(echo "$repo_json" | jq -r '.message // empty')"
  if [[ -n "$api_msg" ]]; then
    gh_error "[${label}] GitHub API: ${api_msg} (CICD-SEC-05-VERIFY)"
    return 1
  fi
  branch="$(echo "$repo_json" | jq -r 'if (.default_branch | type) == "string" and (.default_branch | length) > 0 then .default_branch else empty end')"
  if [[ -z "$branch" ]]; then
    gh_error "[${label}] No default_branch in repository metadata. (CICD-SEC-05-VERIFY)"
    return 1
  fi
  if ! prot_out="$(GH_TOKEN="$token" gh api "repos/${REPO}/branches/${branch}/protection" 2>&1)"; then
    if echo "$prot_out" | grep -q "403\|Must have admin rights"; then
      gh_error "[${label}] Branch protection API returned 403 for '${REPO}'. Fine-grained: Metadata Read and Administration Read on this repo. Classic: repo scope where needed. Org SAML: authorize the PAT. (CICD-SEC-05-VERIFY)"
      summary ""
      summary "**403 (${label}):** PAT is set but denied. Confirm this repo is on the token: \`${REPO}\`."
      return 1
    elif echo "$prot_out" | grep -q "404"; then
      echo "OK [${label}]: branch protection API reachable (no rules on '${branch}' → HTTP 404)."
      summary "- **${label}:** PASS (404 = no protection rules configured)."
      return 0
    fi
    gh_error "[${label}] Unexpected branch protection response: $(echo "$prot_out" | tr '\n' ' ' | cut -c1-500) (CICD-SEC-05-VERIFY)"
    return 1
  fi
  echo "OK [${label}]: branch protection readable for '${REPO}@${branch}'."
  summary "- **${label}:** PASS (protection payload returned)."
  return 0
}

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  summary "## Admin token check (CICD-SEC-05-VERIFY)"
  summary ""
  summary "- Repository: \`${REPO:-<unset>}\`"
  summary "- Event: \`${GITHUB_EVENT_NAME:-unknown}\`"
  summary "- Classic PAT supplied: $([[ -n "$CLASSIC" ]] && echo yes || echo no)"
  summary "- Fine-grained PAT supplied: $([[ -n "$FG" ]] && echo yes || echo no)"
  summary ""
fi

if [[ -z "$REPO" ]]; then
  gh_error "GITHUB_REPOSITORY is not set. (CICD-SEC-05-VERIFY)"
  exit 1
fi

if [[ -z "$CLASSIC" ]] && [[ -z "$FG" ]]; then
  msg="No admin PAT passed (neither classic nor fine-grained). Map GUARDRAILS_ADMIN_TOKEN / GUARDRAILS_ADMIN_TOKEN_FG in the caller to admin-token / admin-token-fg. Fork pull_request runs often have no secrets. (CICD-SEC-05-VERIFY)"
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

FAIL=0
if [[ -n "$CLASSIC" ]]; then
  summary "### Classic PAT"
  if ! verify_one "classic" "$CLASSIC"; then
    FAIL=1
  fi
  summary ""
fi

if [[ -n "$FG" ]]; then
  summary "### Fine-grained PAT"
  if ! verify_one "fine-grained" "$FG"; then
    FAIL=1
  fi
  summary ""
fi

if [[ $FAIL -ne 0 ]]; then
  if [[ "$STRICT" == "true" ]]; then
    gh_error "One or more PAT checks failed (see logs and job summary). (CICD-SEC-05-VERIFY)"
    summary "Result: **FAIL**"
    exit 1
  fi
  gh_warning "One or more PAT checks failed; continuing because strict mode is off. (CICD-SEC-05-VERIFY)"
  summary "Result: **WARN** (non-strict: failures do not fail the job)"
  exit 0
fi

summary "Result: **PASS** (all supplied token(s) can read branch protection)."
exit 0
