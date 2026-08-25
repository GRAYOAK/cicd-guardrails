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
# shellcheck source=scripts/lib/package_policy.sh
source "${ROOT_SCRIPTS_DIR}/lib/package_policy.sh"
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

fb_init "CICD-SEC-03-DEPENDENCY-CHAIN" "Dependency chain check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-03-Dependency-Chain-Abuse/"
cfg_init "$PATH_ROOT"
fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"

if [[ "$FB_MODE" == "off" ]]; then
  fb_set_status "SKIPPED"
  fb_add_remediation "Check disabled via configuration."
  fb_add_coverage "Check disabled via configuration before any repository scan."
  fb_summary
  exit "$(fb_exit_code "$STRICT_MODE" false)"
fi

fp_init "$PATH_ROOT"
pp_init "$PATH_ROOT"
trap pp_cleanup EXIT

fb_add_searched "Python package_policy directories (triggers, satisfiers, hashes)"
fb_add_searched "Package manifests and lockfiles (npm, pnpm, yarn, go, Cargo, Ruby, PHP)"
fb_add_searched "GitHub workflow YAML files for third-party action SHA pins"
fb_add_searched "Dockerfiles for digest-pinned base images"

declare -a SEC03_PACKAGE_JSON=()
declare -a SEC03_GO_MOD=()
declare -a SEC03_CARGO_TOML=()
declare -a SEC03_GEMFILE=()
declare -a SEC03_COMPOSER_JSON=()
declare -a SEC03_PACKAGE_LOCK=()
declare -a SEC03_YARN_LOCK=()
declare -a SEC03_PNPM_LOCK=()
declare -a SEC03_GO_SUM=()
declare -a SEC03_CARGO_LOCK=()
declare -a SEC03_GEMFILE_LOCK=()
declare -a SEC03_COMPOSER_LOCK=()
declare -a SEC03_WORKFLOWS=()
declare -a SEC03_DOCKERFILES=()

sec03_collect_inventory() {
  local path basename
  while IFS= read -r path; do
    [[ -z "$path" || ! -f "$path" ]] && continue
    basename="${path##*/}"
    case "$basename" in
      package.json) SEC03_PACKAGE_JSON+=("$path") ;;
      go.mod) SEC03_GO_MOD+=("$path") ;;
      Cargo.toml) SEC03_CARGO_TOML+=("$path") ;;
      Gemfile) SEC03_GEMFILE+=("$path") ;;
      composer.json) SEC03_COMPOSER_JSON+=("$path") ;;
      package-lock.json) SEC03_PACKAGE_LOCK+=("$path") ;;
      yarn.lock) SEC03_YARN_LOCK+=("$path") ;;
      pnpm-lock.yaml) SEC03_PNPM_LOCK+=("$path") ;;
      go.sum) SEC03_GO_SUM+=("$path") ;;
      Cargo.lock) SEC03_CARGO_LOCK+=("$path") ;;
      Gemfile.lock) SEC03_GEMFILE_LOCK+=("$path") ;;
      composer.lock) SEC03_COMPOSER_LOCK+=("$path") ;;
    esac
  done < <(
    fp_find_with_names "$PATH_ROOT" \
      "package.json" "go.mod" "Cargo.toml" "Gemfile" "composer.json" \
      "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "go.sum" \
      "Cargo.lock" "Gemfile.lock" "composer.lock"
  )

  while IFS= read -r path; do
    [[ -n "$path" && -f "$path" ]] && SEC03_WORKFLOWS+=("$path")
  done < <(fp_find_workflow_yamls)
  while IFS= read -r path; do
    [[ -n "$path" && -f "$path" ]] && SEC03_DOCKERFILES+=("$path")
  done < <(fp_find_dockerfiles)
}

sec03__coverage_inventory() {
  local phase_name="$1"
  local filename="$2"
  shift 2
  local total=0 skipped=0 audited=0
  local lim samp="" n=0 abs_path
  lim="$(fb_coverage_path_sample_limit)"
  for abs_path in "$@"; do
    [[ -z "$abs_path" || ! -f "$abs_path" ]] && continue
    total=$((total + 1))
    local rel
    rel="$(fp_rel_path "$abs_path")"
    if fp_should_skip_validation "$rel"; then
      skipped=$((skipped + 1))
      continue
    fi
    audited=$((audited + 1))
    if [[ $n -lt $lim ]]; then
      samp="${samp:+$samp; }${rel}"
      n=$((n + 1))
    fi
  done
  fb_add_coverage "${phase_name} (${filename}): found ${total}, skipped by repository validation rules ${skipped}, evaluated ${audited}${samp:+; sample: }${samp}"
}

sec03__coverage_workflows_and_dockerfiles() {
  local w_total=0 w_skip=0 w_aud=0 d_total=0 d_skip=0 d_aud=0
  local lim ws="" ds="" wn=0 dn=0
  lim="$(fb_coverage_path_sample_limit)"
  for wf in "${SEC03_WORKFLOWS[@]}"; do
    [[ -z "$wf" || ! -f "$wf" ]] && continue
    w_total=$((w_total + 1))
    local wrel
    wrel="$(fp_rel_path "$wf")"
    if fp_should_skip_validation "$wrel"; then
      w_skip=$((w_skip + 1))
      continue
    fi
    w_aud=$((w_aud + 1))
    if [[ $wn -lt $lim ]]; then
      ws="${ws:+$ws; }${wrel}"
      wn=$((wn + 1))
    fi
  done
  for df in "${SEC03_DOCKERFILES[@]}"; do
    [[ -z "$df" || ! -f "$df" ]] && continue
    d_total=$((d_total + 1))
    local drel
    drel="$(fp_rel_path "$df")"
    if fp_should_skip_validation "$drel"; then
      d_skip=$((d_skip + 1))
      continue
    fi
    d_aud=$((d_aud + 1))
    if [[ $dn -lt $lim ]]; then
      ds="${ds:+$ds; }${drel}"
      dn=$((dn + 1))
    fi
  done
  fb_add_coverage "Workflow YAML for third-party action pins: ${w_total} files (${w_skip} skipped, ${w_aud} evaluated)${ws:+; sample: }${ws}"
  fb_add_coverage "Dockerfiles for digest-pinned bases: ${d_total} files (${d_skip} skipped, ${d_aud} evaluated)${ds:+; sample: }${ds}"
}

sec03_for_each_file() {
  local callback="$1"
  shift
  local abs_path
  for abs_path in "$@"; do
    [[ -z "$abs_path" || ! -f "$abs_path" ]] && continue
    local rel
    rel="$(fp_rel_path "$abs_path")"
    if fp_should_skip_validation "$rel"; then
      continue
    fi
    "$callback" "$PATH_ROOT" "$abs_path" || true
  done
}

sec03_phase_python_package_policy() {
  cicd_sec_03_run_python_package_policy "$PATH_ROOT" || true
}

sec03_phase_manifests_and_requirements() {
  cicd_sec_03_run_javascript_package_policy "$PATH_ROOT" --files "${SEC03_PACKAGE_JSON[@]}" || true
  sec03_for_each_file cicd_sec_03_audit_go_mod "${SEC03_GO_MOD[@]}"
  sec03_for_each_file cicd_sec_03_audit_rust_cargo_toml "${SEC03_CARGO_TOML[@]}"
  sec03_for_each_file cicd_sec_03_audit_ruby_gemfile "${SEC03_GEMFILE[@]}"
  sec03_for_each_file cicd_sec_03_audit_php_composer_json "${SEC03_COMPOSER_JSON[@]}"
}

sec03_phase_lockfiles() {
  sec03_for_each_file cicd_sec_03_audit_go_sum "${SEC03_GO_SUM[@]}"
  sec03_for_each_file cicd_sec_03_audit_rust_cargo_lock "${SEC03_CARGO_LOCK[@]}"
  sec03_for_each_file cicd_sec_03_audit_ruby_gemfile_lock "${SEC03_GEMFILE_LOCK[@]}"
  sec03_for_each_file cicd_sec_03_audit_php_composer_lock "${SEC03_COMPOSER_LOCK[@]}"
}

sec03_phase_workflows_and_dockerfiles() {
  local wf df
  for wf in "${SEC03_WORKFLOWS[@]}"; do
    [[ -z "$wf" || ! -f "$wf" ]] && continue
    local rel
    rel="$(fp_rel_path "$wf")"
    if fp_should_skip_validation "$rel"; then
      continue
    fi
    action_pin_scan_file "$PATH_ROOT" "$wf" "workflows" || true
  done

  for df in "${SEC03_DOCKERFILES[@]}"; do
    [[ -z "$df" || ! -f "$df" ]] && continue
    local rel
    rel="$(fp_rel_path "$df")"
    if fp_should_skip_validation "$rel"; then
      continue
    fi
    dockerfile_pin_scan_file "$PATH_ROOT" "$df" || true
  done
}

sec03_collect_inventory
sec03_phase_python_package_policy
sec03_phase_manifests_and_requirements
sec03_phase_lockfiles
sec03_phase_workflows_and_dockerfiles

sec03__coverage_inventory "Manifest" "package.json" "${SEC03_PACKAGE_JSON[@]}"
sec03__coverage_inventory "Manifest" "go.mod" "${SEC03_GO_MOD[@]}"
sec03__coverage_inventory "Manifest" "Cargo.toml" "${SEC03_CARGO_TOML[@]}"
sec03__coverage_inventory "Manifest" "Gemfile" "${SEC03_GEMFILE[@]}"
sec03__coverage_inventory "Manifest" "composer.json" "${SEC03_COMPOSER_JSON[@]}"
sec03__coverage_inventory "Lock" "package-lock.json" "${SEC03_PACKAGE_LOCK[@]}"
sec03__coverage_inventory "Lock" "yarn.lock" "${SEC03_YARN_LOCK[@]}"
sec03__coverage_inventory "Lock" "pnpm-lock.yaml" "${SEC03_PNPM_LOCK[@]}"
sec03__coverage_inventory "Lock" "go.sum" "${SEC03_GO_SUM[@]}"
sec03__coverage_inventory "Lock" "Cargo.lock" "${SEC03_CARGO_LOCK[@]}"
sec03__coverage_inventory "Lock" "Gemfile.lock" "${SEC03_GEMFILE_LOCK[@]}"
sec03__coverage_inventory "Lock" "composer.lock" "${SEC03_COMPOSER_LOCK[@]}"
sec03__coverage_workflows_and_dockerfiles

fb_auto_status "$STRICT_MODE"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT_MODE" false)"
