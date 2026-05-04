#!/usr/bin/env bash
# OWASP CICD-SEC-03: Dependency Chain Abuse
#
# Prüft ob zu jedem Package-Manifest ein Lock-File existiert.
# Unterstützte Ökosysteme: npm, Poetry, Ruby, Rust, Go, PHP
# Für pip/requirements.txt: prüft ob alle Versionen mit == gepinnt sind.
#
# Exit 0 = alle Manifeste haben Lock-Files
# Exit 1 = fehlende oder unvollständige Lock-Files

set -euo pipefail

PATH_ROOT="${1:-.}"
FAIL=0

gh_error() { echo "::error file=${1}::${2}"; }

# Verzeichnisse die ignoriert werden
PRUNE="-not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/.venv/*'"

check_lockfile() {
  local manifest="$1"
  local dir
  dir=$(dirname "$manifest")
  shift
  local lockfiles=("$@")

  for lf in "${lockfiles[@]}"; do
    [[ -f "$dir/$lf" ]] && return 0
  done
  return 1
}

# ── npm ───────────────────────────────────────────────────────────────────────
while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "package-lock.json" "yarn.lock" "pnpm-lock.yaml"; then
    echo "❌ [npm] $rel – kein Lock-File (package-lock.json / yarn.lock / pnpm-lock.yaml)"
    echo "   FIX: npm install  oder  yarn install"
    gh_error "$rel" "Kein npm Lock-File – Dependency Chain Abuse möglich (OWASP CICD-SEC-03)"
    FAIL=1
  fi
done < <(find "$PATH_ROOT" -name "package.json" \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

# ── Poetry / uv ───────────────────────────────────────────────────────────────
while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "poetry.lock" "uv.lock"; then
    echo "❌ [Poetry] $rel – kein Lock-File (poetry.lock / uv.lock)"
    echo "   FIX: poetry lock  oder  uv lock"
    FAIL=1
  fi
done < <(find "$PATH_ROOT" -name "pyproject.toml" \
  -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null)

# ── pip requirements.txt – prüfe ob alle Versionen mit == gepinnt ─────────────
while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  # Zeilen die kein == haben (und keine Kommentare / -r includes / leere Zeilen)
  unpinned=$(grep -vE '^\s*(#|-r |--|-i |$)' "$f" | grep -v "==" || true)
  if [[ -n "$unpinned" ]]; then
    echo "❌ [pip] $rel – unpinnde Abhängigkeiten:"
    while IFS= read -r line; do
      echo "   → $line"
    done <<< "$unpinned"
    echo "   FIX: Versionen mit == pinnen, z.B. requests==2.31.0"
    gh_error "$rel" "Unpinnde pip-Abhängigkeiten – == Pinning verwenden (OWASP CICD-SEC-03)"
    FAIL=1
  fi
done < <(find "$PATH_ROOT" -name "requirements*.txt" \
  -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null)

# ── Ruby ──────────────────────────────────────────────────────────────────────
while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "Gemfile.lock"; then
    echo "❌ [Ruby] $rel – kein Gemfile.lock"
    echo "   FIX: bundle install"
    FAIL=1
  fi
done < <(find "$PATH_ROOT" -name "Gemfile" -not -path "*/.git/*" 2>/dev/null)

# ── Rust ──────────────────────────────────────────────────────────────────────
while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "Cargo.lock"; then
    echo "❌ [Rust] $rel – kein Cargo.lock"
    echo "   FIX: cargo build (wird automatisch erzeugt, committe es)"
    FAIL=1
  fi
done < <(find "$PATH_ROOT" -name "Cargo.toml" \
  -not -path "*/.git/*" -not -path "*/target/*" 2>/dev/null)

# ── Go ────────────────────────────────────────────────────────────────────────
while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "go.sum"; then
    echo "❌ [Go] $rel – kein go.sum"
    echo "   FIX: go mod tidy"
    FAIL=1
  fi
done < <(find "$PATH_ROOT" -name "go.mod" -not -path "*/.git/*" 2>/dev/null)

# ── PHP (Composer) ────────────────────────────────────────────────────────────
while IFS= read -r f; do
  rel="${f#"$PATH_ROOT/"}"
  if ! check_lockfile "$f" "composer.lock"; then
    echo "❌ [PHP] $rel – kein composer.lock"
    echo "   FIX: composer install"
    FAIL=1
  fi
done < <(find "$PATH_ROOT" -name "composer.json" -not -path "*/.git/*" 2>/dev/null)

# ─────────────────────────────────────────────────────────────────────────────
if [[ $FAIL -eq 0 ]]; then
  echo "✅ PASS: Alle Dependency-Manifeste haben Lock-Files."
fi

exit $FAIL
