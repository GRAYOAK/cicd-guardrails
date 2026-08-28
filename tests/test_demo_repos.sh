#!/usr/bin/env bash
# File-based outcome harness for GRAYOAK demo fixtures.
# Expected: well all 0; errors overall != 0 (SEC-03 failing is sufficient).
# Exit 2 from a check is infrastructure (missing tool), not an expected errors-red.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN_DIR="${ROOT_DIR}/scripts/checks/domain"
PARENT_DIR="$(cd "${ROOT_DIR}/.." && pwd)"

WELL_PATH="${GUARDRAILS_DEMO_WELL_PATH:-${PARENT_DIR}/cicd-guardrails-demo-well}"
ERRORS_PATH="${GUARDRAILS_DEMO_ERRORS_PATH:-${PARENT_DIR}/cicd-guardrails-demo-errors}"

# File-based checks only. Skip CICD-SEC-01-FLOW and CICD-SEC-05-BRANCH (API / token).
FILE_CHECKS=(
  cicd_sec_03_dependency_chain.sh
  cicd_sec_04_poisoned_pipeline.sh
  cicd_sec_05_permissions.sh
  cicd_sec_05_runner_access.sh
  cicd_sec_06_secret_scan.sh
  cicd_sec_07_runner_hardening.sh
  cicd_sec_08_action_pinning.sh
)

infra=0
well_bad=0
errors_finding=0
errors_sec03_finding=0
LAST_EXIT=0

require_dir() {
  local label="$1" path="$2"
  if [[ ! -d "$path" ]]; then
    echo "INFRA: ${label} path is missing: ${path}"
    echo "Set GUARDRAILS_DEMO_WELL_PATH / GUARDRAILS_DEMO_ERRORS_PATH, or clone siblings next to cicd-guardrails."
    exit 2
  fi
}

run_one() {
  local script="$1" target="$2" label="$3"
  local tmp
  tmp="$(mktemp -d)"
  # SEC-06 requires ./gitleaks in the process cwd (not PATH).
  if command -v gitleaks >/dev/null 2>&1; then
    ln -s "$(command -v gitleaks)" "${tmp}/gitleaks"
  elif [[ -x "${ROOT_DIR}/gitleaks" ]]; then
    ln -s "${ROOT_DIR}/gitleaks" "${tmp}/gitleaks"
  fi
  set +e
  (
    cd "$tmp"
    bash "${DOMAIN_DIR}/${script}" "$target"
  )
  LAST_EXIT=$?
  set -e
  rm -rf "$tmp"
  echo "  ${label} ${script} => ${LAST_EXIT}"
}

echo "Demo well:    ${WELL_PATH}"
echo "Demo errors:  ${ERRORS_PATH}"
require_dir "well" "$WELL_PATH"
require_dir "errors" "$ERRORS_PATH"

echo
echo "=== well (expect every file-based check exit 0) ==="
for script in "${FILE_CHECKS[@]}"; do
  run_one "$script" "$WELL_PATH" "well"
  if [[ "$LAST_EXIT" -eq 2 ]]; then
    echo "  INFRA: ${script} exited 2 on well"
    infra=1
  elif [[ "$LAST_EXIT" -ne 0 ]]; then
    echo "  FAIL: well ${script} expected 0, got ${LAST_EXIT}"
    well_bad=1
  fi
done

echo
echo "=== errors (expect overall != 0; SEC-03 fail is sufficient) ==="
for script in "${FILE_CHECKS[@]}"; do
  run_one "$script" "$ERRORS_PATH" "errors"
  if [[ "$LAST_EXIT" -eq 2 ]]; then
    echo "  INFRA: ${script} exited 2 on errors"
    infra=1
  elif [[ "$LAST_EXIT" -ne 0 ]]; then
    errors_finding=1
    if [[ "$script" == "cicd_sec_03_dependency_chain.sh" ]]; then
      errors_sec03_finding=1
    fi
  fi
done

echo
if [[ "$infra" -ne 0 ]]; then
  echo "Harness failed: infrastructure (exit 2), not an expected demo-errors finding."
  exit 2
fi
if [[ "$well_bad" -ne 0 ]]; then
  echo "Harness failed: demo-well had non-zero file-based checks."
  exit 1
fi
if [[ "$errors_finding" -eq 0 ]]; then
  echo "Harness failed: demo-errors produced no findings (all file-based checks exited 0)."
  exit 1
fi
if [[ "$errors_sec03_finding" -eq 1 ]]; then
  echo "demo-errors SEC-03 failed as expected (sufficient negative signal)."
else
  echo "demo-errors was red overall; SEC-03 itself passed (other file-based checks failed)."
fi
echo "Harness passed: well all 0; errors overall != 0."
exit 0
