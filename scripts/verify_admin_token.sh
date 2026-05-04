#!/usr/bin/env bash
# Verifies that a PAT was supplied for branch-protection checks and that it can
# read the branch protection API for the calling repository. Intended for CI.
#
# Env:
#   GITHUB_REPOSITORY       caller repo (set by Actions)
#   GH_TOKEN                token used for gh (PAT or default token)
#   GUARDRAILS_HAS_ADMIN_SECRET  "true" if the reusable workflow received a
#                            non-empty admin secret (set in the workflow only)
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

if [[ -z "$REPO" ]]; then
  gh_error "GITHUB_REPOSITORY is not set. (CICD-SEC-05-VERIFY)"
  exit 1
fi

if [[ "$HAS_ADMIN_SECRET" != "true" ]]; then
  msg="No admin PAT was passed into this reusable workflow; branch protection cannot be read via API. (CICD-SEC-05-VERIFY)"
  if [[ "$STRICT" == "true" ]]; then
    gh_error "$msg"
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

if ! REPO_JSON="$(gh api "repos/${REPO}" 2>&1)"; then
  REPO_SNIP="$(echo "$REPO_JSON" | tr '\n' ' ' | cut -c1-400)"
  gh_error "PAT cannot reach repository metadata or token is invalid: ${REPO_SNIP} (CICD-SEC-05-VERIFY)"
  exit 1
fi

if ! echo "$REPO_JSON" | jq -e . >/dev/null 2>&1; then
  REPO_SNIP="$(echo "$REPO_JSON" | tr '\n' ' ' | cut -c1-400)"
  gh_error "Repository metadata response is not valid JSON: ${REPO_SNIP} (CICD-SEC-05-VERIFY)"
  exit 1
fi

API_MSG="$(echo "$REPO_JSON" | jq -r '.message // empty')"
if [[ -n "$API_MSG" ]]; then
  gh_error "GitHub API: ${API_MSG} (CICD-SEC-05-VERIFY)"
  exit 1
fi

BRANCH="$(echo "$REPO_JSON" | jq -r 'if (.default_branch | type) == "string" and (.default_branch | length) > 0 then .default_branch else empty end')"
if [[ -z "$BRANCH" ]]; then
  gh_error "No default_branch in repository metadata. (CICD-SEC-05-VERIFY)"
  exit 1
fi

if ! PROT_OUT="$(gh api "repos/${REPO}/branches/${BRANCH}/protection" 2>&1)"; then
  if echo "$PROT_OUT" | grep -q "403\|Must have admin rights"; then
    gh_error "PAT cannot read branch protection (403). Grant Administration: Read on this repository (fine-grained PAT) or use a classic PAT with sufficient repo access. (CICD-SEC-05-VERIFY)"
    exit 1
  elif echo "$PROT_OUT" | grep -q "404"; then
    echo "OK: PAT can read branch protection API (no rules on '${BRANCH}' → HTTP 404)."
    exit 0
  fi
  PROT_SNIP="$(echo "$PROT_OUT" | tr '\n' ' ' | cut -c1-500)"
  gh_error "Unexpected branch protection API response: ${PROT_SNIP} (CICD-SEC-05-VERIFY)"
  exit 1
fi

echo "OK: PAT can read branch protection API for '${REPO}@${BRANCH}'."
