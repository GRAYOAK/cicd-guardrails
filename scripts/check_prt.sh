#!/usr/bin/env bash
# OWASP CICD-SEC-04: Poisoned Pipeline Execution (PPE)
#
# Prüft ob pull_request_target in Workflow-Dateien vorkommt.
# Ignoriert Kommentarzeilen und Inline-Kommentare.
#
# Exit 0 = sauber
# Exit 1 = Findings gefunden

set -euo pipefail

PATH_ROOT="${1:-.}"
WORKFLOWS_DIR="$PATH_ROOT/.github/workflows"
FAIL=0

# GitHub Actions Annotation (wird als inline PR-Kommentar angezeigt)
gh_error() { echo "::error file=${1},line=${2}::${3}"; }
gh_notice() { echo "::notice file=${1}::${2}"; }

shopt -s nullglob
files=("$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ℹ️  Keine Workflow-Dateien in $WORKFLOWS_DIR gefunden."
  exit 0
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  # awk: Kommentarzeilen überspringen, Inline-Kommentare entfernen, dann prüfen
  findings=$(awk '
    /^[[:space:]]*#/ { next }          # ganze Kommentarzeile → skip
    {
      line = $0
      sub(/#.*$/, "", line)            # Inline-Kommentar entfernen
      if (line ~ /pull_request_target/) {
        print NR ": " $0
      }
    }
  ' "$file")

  if [[ -n "$findings" ]]; then
    echo "❌ $rel"
    while IFS= read -r match; do
      linenum="${match%%:*}"
      echo "   $match"
      gh_error "$rel" "$linenum" "pull_request_target verwendet – Poisoned Pipeline Execution Risiko (OWASP CICD-SEC-04)"
    done <<< "$findings"

    # Besonders gefährlich: Fork-Code wird ausgecheckt
    if grep -q "pull_request\.head\.sha\|pull_request\.head\.ref" "$file"; then
      echo "   🔴 KRITISCH: Workflow checkt auch Fork-Code aus (head.sha/head.ref)!"
      gh_error "$rel" "0" "KRITISCH: pull_request_target + Fork-Checkout kombiniert – aktiver PPE-Angriffspfad"
    fi
    echo ""
    FAIL=1
  fi
done

if [[ $FAIL -eq 0 ]]; then
  echo "✅ PASS: Kein pull_request_target gefunden."
fi

exit $FAIL
