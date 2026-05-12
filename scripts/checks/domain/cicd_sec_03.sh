#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/package"
# shellcheck source=scripts/lib/feedback.sh
source "${ROOT_SCRIPTS_DIR}/lib/feedback.sh"
# shellcheck source=scripts/lib/config.sh
source "${ROOT_SCRIPTS_DIR}/lib/config.sh"
# shellcheck source=scripts/lib/package_scan.sh
source "${ROOT_SCRIPTS_DIR}/lib/package_scan.sh"
# shellcheck source=scripts/lib/file_patterns.sh
source "${ROOT_SCRIPTS_DIR}/lib/file_patterns.sh"
# shellcheck source=scripts/lib/action_pin_audit.sh
source "${ROOT_SCRIPTS_DIR}/lib/action_pin_audit.sh"
# shellcheck source=scripts/lib/dockerfile_pin_audit.sh
source "${ROOT_SCRIPTS_DIR}/lib/dockerfile_pin_audit.sh"
# shellcheck source=scripts/checks/domain/package/js_ts.sh
source "${PACKAGE_DIR}/js_ts.sh"
# shellcheck source=scripts/checks/domain/package/python.sh
source "${PACKAGE_DIR}/python.sh"
# shellcheck source=scripts/checks/domain/package/go.sh
source "${PACKAGE_DIR}/go.sh"
# shellcheck source=scripts/checks/domain/package/rust.sh
source "${PACKAGE_DIR}/rust.sh"
# shellcheck source=scripts/checks/domain/package/ruby.sh
source "${PACKAGE_DIR}/ruby.sh"
# shellcheck source=scripts/checks/domain/package/php.sh
source "${PACKAGE_DIR}/php.sh"

PATH_ROOT_ARG="${1:-.}"
PATH_ROOT="$(cd "$PATH_ROOT_ARG" && pwd)"
STRICT_MODE="false"
if [[ "${2:-}" == "--strict" ]]; then
  STRICT_MODE="true"
fi

fb_init "CICD-SEC-03" "Dependency pinning and lockfile check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-03-Dependency-Chain-Abuse/"
cfg_init "$PATH_ROOT"
fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"

if [[ "$FB_MODE" == "off" ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "Check disabled via configuration."
  fb_summary
  exit "$(fb_exit_code "$STRICT_MODE" false)"
fi

fp_init "$PATH_ROOT"

fb_add_searched "Package manifests and Python requirements with lock or pin policy"
fb_add_searched "Lockfiles for integrity checks (npm, pnpm, yarn, poetry, uv, go, Cargo, Ruby, PHP)"
fb_add_searched "GitHub workflow YAML files for third-party action SHA pins"
fb_add_searched "Dockerfiles for digest-pinned base images"

sec03_for_each_file() {
  local callback="$1"
  shift
  while IFS= read -r abs_path; do
    [[ -z "$abs_path" || ! -f "$abs_path" ]] && continue
    local rel
    rel="$(fp_rel_path "$abs_path")"
    if fp_should_skip_validation "$rel"; then
      continue
    fi
    "$callback" "$PATH_ROOT" "$abs_path" || true
  done
}

sec03_phase_manifests_and_requirements() {
  sec03_for_each_file cicd_sec_03_audit_js_ts_package_json < <(fp_find_with_names "$PATH_ROOT" "package.json")
  sec03_for_each_file cicd_sec_03_audit_python_pyproject < <(fp_find_with_names "$PATH_ROOT" "pyproject.toml")
  sec03_for_each_file cicd_sec_03_audit_python_requirements < <(fp_find_with_names "$PATH_ROOT" "requirements*.txt")
  sec03_for_each_file cicd_sec_03_audit_go_mod < <(fp_find_with_names "$PATH_ROOT" "go.mod")
  sec03_for_each_file cicd_sec_03_audit_rust_cargo_toml < <(fp_find_with_names "$PATH_ROOT" "Cargo.toml")
  sec03_for_each_file cicd_sec_03_audit_ruby_gemfile < <(fp_find_with_names "$PATH_ROOT" "Gemfile")
  sec03_for_each_file cicd_sec_03_audit_php_composer_json < <(fp_find_with_names "$PATH_ROOT" "composer.json")
}

sec03_phase_lockfiles() {
  sec03_for_each_file cicd_sec_03_audit_js_ts_lock_package_lock < <(fp_find_with_names "$PATH_ROOT" "package-lock.json")
  sec03_for_each_file cicd_sec_03_audit_js_ts_lock_yarn < <(fp_find_with_names "$PATH_ROOT" "yarn.lock")
  sec03_for_each_file cicd_sec_03_audit_js_ts_lock_pnpm < <(fp_find_with_names "$PATH_ROOT" "pnpm-lock.yaml")
  sec03_for_each_file cicd_sec_03_audit_python_lock_poetry < <(fp_find_with_names "$PATH_ROOT" "poetry.lock")
  sec03_for_each_file cicd_sec_03_audit_python_lock_uv < <(fp_find_with_names "$PATH_ROOT" "uv.lock")
  sec03_for_each_file cicd_sec_03_audit_go_sum < <(fp_find_with_names "$PATH_ROOT" "go.sum")
  sec03_for_each_file cicd_sec_03_audit_rust_cargo_lock < <(fp_find_with_names "$PATH_ROOT" "Cargo.lock")
  sec03_for_each_file cicd_sec_03_audit_ruby_gemfile_lock < <(fp_find_with_names "$PATH_ROOT" "Gemfile.lock")
  sec03_for_each_file cicd_sec_03_audit_php_composer_lock < <(fp_find_with_names "$PATH_ROOT" "composer.lock")
}

sec03_phase_workflows_and_dockerfiles() {
  while IFS= read -r wf; do
    [[ -z "$wf" || ! -f "$wf" ]] && continue
    local rel
    rel="$(fp_rel_path "$wf")"
    if fp_should_skip_validation "$rel"; then
      continue
    fi
    action_pin_scan_file "$PATH_ROOT" "$wf" "workflows" || true
  done < <(fp_find_workflow_yamls)

  while IFS= read -r df; do
    [[ -z "$df" || ! -f "$df" ]] && continue
    local rel
    rel="$(fp_rel_path "$df")"
    if fp_should_skip_validation "$rel"; then
      continue
    fi
    dockerfile_pin_scan_file "$PATH_ROOT" "$df" || true
  done < <(fp_find_dockerfiles)
}

sec03_phase_manifests_and_requirements
sec03_phase_lockfiles
sec03_phase_workflows_and_dockerfiles

fb_auto_status "$STRICT_MODE"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT_MODE" false)"
