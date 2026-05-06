#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/feedback.sh
source "${SCRIPT_DIR}/lib/feedback.sh"

PATH_ROOT="${1:-.}"

fb_init "CICD-SEC-03" "Dependency pinning and lockfile check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-03-Dependency-Chain-Abuse/"
fb_add_searched "Manifest files for npm, python, ruby, rust, go, and php"
fb_add_searched "Presence of required lockfiles next to each manifest"
fb_add_searched "Pinned python requirements using =="

check_lockfile() {
  local manifest="$1"
  local dir
  dir="$(dirname "$manifest")"
  shift
  local lockfiles=("$@")

  for lf in "${lockfiles[@]}"; do
    if [[ -f "$dir/$lf" ]]; then
      return 0
    fi
  done
  return 1
}

while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "package-lock.json" "yarn.lock" "pnpm-lock.yaml"; then
    fb_report "error" "Missing npm lockfile near package.json." "$rel" "" \
      "Generate and commit package-lock.json, yarn.lock, or pnpm-lock.yaml."
  fi
done < <(find "$PATH_ROOT" -name "package.json" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "poetry.lock" "uv.lock"; then
    fb_report "error" "Missing poetry or uv lockfile next to pyproject.toml." "$rel" "" \
      "Generate and commit poetry.lock or uv.lock."
  fi
done < <(find "$PATH_ROOT" -name "pyproject.toml" -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null)

while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  unpinned="$(grep -vE '^\s*(#|-r |--|-i |$)' "$f" | grep -v '==' || true)"
  if [[ -n "$unpinned" ]]; then
    while IFS= read -r line; do
      fb_report "error" "Unpinned python dependency '${line}'." "$rel" "" \
        "Pin each dependency with exact == version."
    done <<<"$unpinned"
  fi
done < <(find "$PATH_ROOT" -name "requirements*.txt" -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null)

while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "Gemfile.lock"; then
    fb_report "error" "Missing Gemfile.lock next to Gemfile." "$rel" "" \
      "Generate and commit Gemfile.lock."
  fi
done < <(find "$PATH_ROOT" -name "Gemfile" -not -path "*/.git/*" 2>/dev/null)

while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "Cargo.lock"; then
    fb_report "error" "Missing Cargo.lock next to Cargo.toml." "$rel" "" \
      "Generate and commit Cargo.lock."
  fi
done < <(find "$PATH_ROOT" -name "Cargo.toml" -not -path "*/.git/*" -not -path "*/target/*" 2>/dev/null)

while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "go.sum"; then
    fb_report "error" "Missing go.sum next to go.mod." "$rel" "" \
      "Run go mod tidy and commit go.sum."
  fi
done < <(find "$PATH_ROOT" -name "go.mod" -not -path "*/.git/*" 2>/dev/null)

while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "composer.lock"; then
    fb_report "error" "Missing composer.lock next to composer.json." "$rel" "" \
      "Run composer install and commit composer.lock."
  fi
done < <(find "$PATH_ROOT" -name "composer.json" -not -path "*/.git/*" 2>/dev/null)

fb_auto_status false
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code false false)"
