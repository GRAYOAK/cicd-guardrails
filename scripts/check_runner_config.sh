#!/usr/bin/env bash
# OWASP CICD-SEC-05 / CICD-SEC-07: Runner-Konfiguration
#
# Prüft Workflows auf problematische Runner-Einstellungen:
#   - --privileged Container-Option            → Error
#   - runs-on: self-hosted ohne weitere Labels → Warning
#   - sudo in run-Steps                        → Warning
#
# Exit 0 = keine Probleme (oder nur Warnings ohne --strict)
# Exit 1 = Errors, oder Warnings mit --strict

set -euo pipefail

PATH_ROOT="${1:-.}"
STRICT="${2:-}"
WORKFLOWS_DIR="$PATH_ROOT/.github/workflows"
ERRORS=0
WARNINGS=0

if ! command -v yq &>/dev/null; then
  echo "❌ yq nicht gefunden. Installation: https://github.com/mikefarah/yq"
  exit 2
fi

shopt -s nullglob
files=("$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ℹ️  Keine Workflow-Dateien gefunden."
  exit 0
fi

for file in "${files[@]}"; do
  rel="${file#"$PATH_ROOT/"}"

  # ── --privileged Container ────────────────────────────────────────────────
  # yq gibt alle container.options-Werte aus; grep sucht nach --privileged
  privileged_jobs=$(yq '.jobs | to_entries | .[] |
    select(.value.container.options != null) |
    select(.value.container.options | test("--privileged")) |
    .key' "$file" 2>/dev/null || true)

  if [[ -n "$privileged_jobs" ]]; then
    while IFS= read -r job; do
      echo "❌ $rel – Job '$job' startet Container mit --privileged"
      echo "   Privilegierte Container vermeiden. Falls nötig: explizites Review erzwingen."
    done <<< "$privileged_jobs"
    ERRORS=$((ERRORS + 1))
  fi

  # ── self-hosted ohne Labels ───────────────────────────────────────────────
  generic_jobs=$(yq '.jobs | to_entries | .[] |
    select(.value["runs-on"] == "self-hosted") |
    .key' "$file" 2>/dev/null || true)

  if [[ -n "$generic_jobs" ]]; then
    while IFS= read -r job; do
      echo "⚠️  $rel – Job '$job' nutzt generisches 'self-hosted' ohne Labels"
      echo "   FIX: runs-on: [self-hosted, linux, production]"
    done <<< "$generic_jobs"
    WARNINGS=$((WARNINGS + 1))
  fi

  # ── sudo in run-Steps ─────────────────────────────────────────────────────
  # grep direkt auf Datei – einfacher als yq für run-Block-Inhalte
  sudo_lines=$(grep -n "\bsudo\b" "$file" | grep -v "^\s*#" || true)
  if [[ -n "$sudo_lines" ]]; then
    echo "⚠️  $rel – sudo verwendet:"
    while IFS= read -r line; do
      echo "   $line"
    done <<< "$sudo_lines"
    echo "   Prüfe ob root-Rechte wirklich nötig sind."
    WARNINGS=$((WARNINGS + 1))
  fi

done

# ── Ergebnis ─────────────────────────────────────────────────────────────────
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo "✅ PASS: Keine Runner-Konfigurationsprobleme gefunden."
  exit 0
fi

[[ $ERRORS -gt 0 ]] && echo "" && echo "→ $ERRORS Fehler, $WARNINGS Warnungen gefunden."

if [[ $ERRORS -gt 0 ]] || [[ -n "$STRICT" && $WARNINGS -gt 0 ]]; then
  exit 1
fi

exit 0
