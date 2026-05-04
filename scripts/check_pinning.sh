#!/usr/bin/env bash
# OWASP CICD-SEC-08: Ungoverned Usage of 3rd-Party Services
#
# Prüft ob alle `uses:`-Referenzen auf einen vollen 40-stelligen SHA gepinnt sind.
# Lehnt @v1, @main, @latest und fehlendes @ ab.
# Ignoriert lokale Actions (./path/to/action).
#
# Exit 0 = alle Actions korrekt gepinnt
# Exit 1 = unpinnde Actions gefunden

set -euo pipefail

PATH_ROOT="${1:-.}"
FAIL=0

gh_error() { echo "::error file=${1},line=${2}::${3}"; }

shopt -s nullglob
files=(
  "$PATH_ROOT"/.github/workflows/*.yml
  "$PATH_ROOT"/.github/workflows/*.yaml
  "$PATH_ROOT"/actions/**/action.yml
  "$PATH_ROOT"/actions/**/action.yaml
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ℹ️  Keine Workflow-/Action-Dateien gefunden."
  exit 0
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  # Pro Zeile:
  #   1. Kommentarzeilen überspringen
  #   2. Inline-Kommentar entfernen (für die Analyse)
  #   3. `uses:`-Zeilen filtern
  #   4. Lokale Actions (./...) überspringen
  #   5. SHA-gepinnte (@<40 hex>) überspringen
  #   6. Rest = unpinnd → ausgeben
  findings=$(awk '
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/#.*$/, "", line)
      if (line !~ /uses:/) next
      if (line ~ /uses:[[:space:]]*\.\//) next     # lokale Action
      if (line ~ /@[0-9a-f]{40}[[:space:]]*$/) next  # SHA gepinnt
      print NR ": " $0
    }
  ' "$file")

  if [[ -n "$findings" ]]; then
    echo "❌ $rel"
    while IFS= read -r match; do
      linenum="${match%%:*}"
      ref=$(echo "$match" | grep -o 'uses:.*' | sed 's/uses:[[:space:]]*//')
      echo "   $match"
      gh_error "$rel" "$linenum" "Unpinnde Action '$ref' – SHA-Pinning verwenden (OWASP CICD-SEC-08)"
    done <<< "$findings"
    echo ""
    FAIL=1
  fi
done

if [[ $FAIL -eq 0 ]]; then
  echo "✅ PASS: Alle Actions auf vollständige SHA gepinnt."
else
  echo "FIX: uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2"
  echo "     SHA ermitteln: git ls-remote https://github.com/actions/checkout refs/tags/v4"
  echo "     Automatisch: Dependabot mit package-ecosystem: github-actions"
fi

exit $FAIL
