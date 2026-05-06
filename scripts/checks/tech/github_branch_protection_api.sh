#!/usr/bin/env bash

set -euo pipefail

ghbp_require_runtime() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "missing:gh"
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "missing:jq"
    return 1
  fi
  return 0
}

ghbp_default_branch() {
  local repo="$1"
  local repo_json=""
  local branch=""

  if repo_json="$(gh api "repos/${repo}" 2>&1)" && echo "$repo_json" | jq -e . >/dev/null 2>&1; then
    branch="$(echo "$repo_json" | jq -r 'if (.default_branch | type) == "string" and (.default_branch | length) > 0 then .default_branch else empty end')"
  fi

  if [[ -z "$branch" ]]; then
    for candidate in main master; do
      if gh api "repos/${repo}/branches/${candidate}" >/dev/null 2>&1; then
        branch="$candidate"
        break
      fi
    done
  fi

  if [[ -z "$branch" ]]; then
    return 1
  fi

  printf "%s\n" "$branch"
}

ghbp_read_protection() {
  local repo="$1"
  local branch="$2"
  gh api "repos/${repo}/branches/${branch}/protection" 2>&1
}

