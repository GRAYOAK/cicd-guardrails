#!/usr/bin/env bash
# OWASP CICD-SEC-05: Insufficient PBAC
#
# Prüft ob in allen Workflow-Dateien:
#   1. Ein top-level permissions: Block vorhanden ist
#   2. Jeder Job einen eigenen permissions: Block hat
#
# Exit 0 = alles OK
# Exit 1 = fehlende permissions gefunden

set -euo pipefail

PATH_ROOT="${1:-.}"
WORKFLOWS_DIR="$PATH_ROOT/.github/workflows"
FAIL=0

gh_error() { echo "::error file=${1}::${2}"; }

if ! command -v yq &>/dev/null; then
  echo "❌ yq nicht gefunden. Installation: https://github.com/mikefarah/yq"
  exit 2
fi

shopt -s nullglob
files=("$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ℹ️  Keine Workflow-Dateien in $WORKFLOWS_DIR gefunden."
  exit 0
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  # ── 1. Top-Level permissions ──────────────────────────────────────────────
  if [[ "$(yq '.permissions' "$file")" == "null" ]]; then
    echo "❌ $rel – kein top-level permissions: Block"
    echo "   → GitHub-Default gibt Schreibrechte auf mehrere Scopes."
    echo "   → Fix: permissions: read-all auf oberster Ebene setzen."
    gh_error "$rel" "Kein top-level permissions Block – GitHub-Default ist write auf mehrere Scopes (OWASP CICD-SEC-05)"
    FAIL=1
  fi

  # ── 2. Permissions pro Job ────────────────────────────────────────────────
  missing=$(yq '.jobs | to_entries | .[] | select(.value.permissions == null) | .key' "$file")
  if [[ -n "$missing" ]]; then
    while IFS= read -r job_id; do
      echo "❌ $rel – Job '$job_id' hat kein permissions: Block"
      echo "   → Fix: permissions: mit nur den nötigen Scopes für diesen Job setzen."
      gh_error "$rel" "Job '$job_id' ohne permissions Block – Least Privilege verletzt (OWASP CICD-SEC-05)"
    done <<< "$missing"
    FAIL=1
  fi

done

if [[ $FAIL -eq 0 ]]; then
  echo "✅ PASS: permissions: in allen Workflows und Jobs definiert."
fi

exit $FAIL
