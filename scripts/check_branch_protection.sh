#!/usr/bin/env bash
# check_branch_protection.sh – CICD-SEC-05
#
# Prüft ob der Standard-Branch (main oder master) mit sinnvollen
# Branch-Protection-Regeln abgesichert ist:
#
#   ✔  Pull Request erforderlich (kein direkter Push auf main)
#   ✔  Mind. 1 Reviewer-Approval (4-Augen-Prinzip)
#   ✔  force-pushes verboten
#
# Benötigt: gh CLI (auf GitHub-hosted Runnern vorinstalliert) + jq
# Token: Branch-Protection lesen erfordert PAT/App mit Administration-Lesezugriff;
# das eingebaute Actions-Token reicht dafür in der Regel nicht.
#
# Verwendung: bash check_branch_protection.sh [--strict]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

REPO="${GITHUB_REPOSITORY:-}"
FAIL=0

if [[ -z "$REPO" ]]; then
  echo "❌ GITHUB_REPOSITORY nicht gesetzt – läuft dieser Script außerhalb von GitHub Actions?"
  exit 1
fi

gh_error()   { echo "::error::$1";   }
gh_warning() { echo "::warning::$1"; }

# ── Branch ermitteln (default branch → main/master fallback) ──────────────────
BRANCH=""

# Prefer default branch from repository metadata. Do not require a separate
# branches/{name} probe: that endpoint can fail (permissions, transient errors)
# even when metadata and protection checks work with the same token.
if REPO_JSON="$(gh api "repos/${REPO}" 2>&1)" && echo "$REPO_JSON" | jq -e . >/dev/null 2>&1; then
  DEFAULT_BRANCH="$(echo "$REPO_JSON" | jq -r 'if (.default_branch | type) == "string" and (.default_branch | length) > 0 then .default_branch else empty end')"
  if [[ -n "$DEFAULT_BRANCH" ]]; then
    BRANCH="$DEFAULT_BRANCH"
  fi
fi

# Fallback when metadata is missing or unreadable.
if [[ -z "$BRANCH" ]]; then
  for b in main master; do
    if gh api "repos/${REPO}/branches/${b}" &>/dev/null 2>&1; then
      BRANCH="$b"
      break
    fi
  done
fi

if [[ -z "$BRANCH" ]]; then
  if [[ -n "${REPO_JSON:-}" ]] && ! echo "$REPO_JSON" | jq -e . >/dev/null 2>&1; then
    REPO_ERR_SNIP="$(echo "$REPO_JSON" | tr '\n' ' ' | cut -c1-400)"
    gh_error "GitHub API lieferte keine gültigen Repo-Metadaten (Auth/Netzwerk/Repo?). ${REPO_ERR_SNIP} (CICD-SEC-05)"
  elif [[ -n "${REPO_JSON:-}" ]] && echo "$REPO_JSON" | jq -e . >/dev/null 2>&1; then
    MSG="$(echo "$REPO_JSON" | jq -r '.message // empty')"
    if [[ -n "$MSG" ]]; then
      gh_error "Repo-Metadaten: ${MSG} (CICD-SEC-05)"
    else
      gh_error "Konnte keinen gültigen Standard-Branch im Repository finden (default_branch fehlt?). (CICD-SEC-05)"
    fi
  else
    gh_error "Konnte keinen gültigen Standard-Branch im Repository finden. (CICD-SEC-05)"
  fi
  exit 1
fi

echo "ℹ️  Prüfe Branch-Protection für: ${REPO}@${BRANCH}"

# ── Protection-Daten abrufen ──────────────────────────────────────────────────
if ! PROTECTION=$(gh api "repos/${REPO}/branches/${BRANCH}/protection" 2>&1); then
  # API-Fehler unterscheiden: 404 = keine Protection, 403 = kein Zugriff
  if echo "$PROTECTION" | grep -q "404"; then
    gh_error "Branch '${BRANCH}' hat keine Branch-Protection-Regeln. \
Direkter Push auf '${BRANCH}' ist möglich – kein 4-Augen-Prinzip erzwungen. (CICD-SEC-05)"
    exit 1
  elif echo "$PROTECTION" | grep -q "403\|Must have admin rights"; then
    gh_warning "Branch-Protection-Check übersprungen: Kein Lesezugriff auf Branch-Protection (403). \
Das eingebaute Actions-Token kann diese API nicht nutzen. \
Für einen vollständigen Check ein PAT oder GitHub-App-Installations-Token mit Administration-Lesezugriff \
auf dieses Repository als GH_TOKEN setzen (z. B. als Repository-Secret in GitHub Actions)."
    exit 0
  else
    gh_error "GitHub API Fehler beim Abrufen der Branch-Protection: ${PROTECTION}"
    exit 1
  fi
fi

# ── 1. Pull Request erforderlich ──────────────────────────────────────────────
REQUIRED_PR_RAW=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews // empty')

if [[ -z "$REQUIRED_PR_RAW" ]]; then
  gh_error "Branch '${BRANCH}': Kein required_pull_request_reviews – \
direkter Push ohne PR ist erlaubt. Kein 4-Augen-Prinzip möglich. (CICD-SEC-05)"
  FAIL=1
else
  echo "✅ Pull Request erforderlich"

  # ── 2. Mindestens 1 Reviewer ────────────────────────────────────────────────
  REQUIRED_COUNT=$(echo "$PROTECTION" \
    | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')

  if [[ "$REQUIRED_COUNT" -lt 1 ]]; then
    gh_error "Branch '${BRANCH}': required_approving_review_count=${REQUIRED_COUNT} – \
Kein 4-Augen-Prinzip. Mindestens 1 Reviewer-Approval erforderlich. (CICD-SEC-05)"
    FAIL=1
  else
    echo "✅ Mindestens ${REQUIRED_COUNT} Reviewer-Approval(s) erforderlich"
  fi

  # ── 3. Stale Reviews verwerfen (Warning) ────────────────────────────────────
  DISMISS_STALE=$(echo "$PROTECTION" \
    | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')

  if [[ "$DISMISS_STALE" != "true" ]]; then
    gh_warning "Branch '${BRANCH}': dismiss_stale_reviews=false – \
Bestehende Approvals bleiben nach neuem Commit im PR gültig. \
Empfehlung: 'Dismiss stale pull request approvals when new commits are pushed' aktivieren."
  else
    echo "✅ Stale reviews werden verworfen"
  fi

  # ── 4. Code-Owner Reviews (Info) ────────────────────────────────────────────
  CODEOWNER=$(echo "$PROTECTION" \
    | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')

  if [[ "$CODEOWNER" != "true" ]]; then
    echo "ℹ️  Code-Owner-Reviews nicht aktiviert (optional, empfohlen für kritische Pfade)"
  else
    echo "✅ Code-Owner-Reviews aktiv"
  fi
fi

# ── 5. Force-Pushes verboten ──────────────────────────────────────────────────
ALLOW_FORCE=$(echo "$PROTECTION" | jq -r '.allow_force_pushes.enabled // false')

if [[ "$ALLOW_FORCE" == "true" ]]; then
  gh_error "Branch '${BRANCH}': allow_force_pushes=true – \
Force-Pushes auf den Hauptbranch erlaubt. Git-History kann überschrieben werden. (CICD-SEC-05)"
  FAIL=1
else
  echo "✅ Force-Pushes verboten"
fi

# ── 6. Branch-Löschung verboten (Warning) ────────────────────────────────────
ALLOW_DELETE=$(echo "$PROTECTION" | jq -r '.allow_deletions.enabled // false')

if [[ "$ALLOW_DELETE" == "true" ]]; then
  gh_warning "Branch '${BRANCH}': allow_deletions=true – \
Der Hauptbranch kann gelöscht werden."
else
  echo "✅ Branch-Löschung verboten"
fi

# ── 7. Admins unterliegen den Regeln ─────────────────────────────────────────
ENFORCE_ADMINS=$(echo "$PROTECTION" | jq -r '.enforce_admins.enabled // false')

if [[ "$ENFORCE_ADMINS" != "true" ]]; then
  gh_warning "Branch '${BRANCH}': enforce_admins=false – \
Repository-Admins können Branch-Protection-Regeln umgehen. \
Empfehlung: 'Do not allow bypassing the above settings' aktivieren."
else
  echo "✅ Branch-Protection gilt auch für Admins"
fi

# ── Ergebnis ──────────────────────────────────────────────────────────────────
echo ""
if [[ $FAIL -ne 0 ]]; then
  echo "❌ Branch-Protection-Check fehlgeschlagen"
  exit 1
else
  echo "✅ Branch-Protection korrekt konfiguriert"
fi
