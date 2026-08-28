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
# shellcheck source=scripts/checks/domain/package/validators.sh
source "${PACKAGE_DIR}/validators.sh"
# shellcheck source=scripts/checks/domain/package/policy_runner.sh
source "${PACKAGE_DIR}/policy_runner.sh"

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

SEC03_PYTHON_MODE="$(cfg_sec03_ecosystem_mode "python")"
SEC03_UNSUPPORTED_MODE="$(cfg_sec03_unsupported_mode)"

fp_init "$PATH_ROOT"
pp_init "$PATH_ROOT"
trap pp_cleanup EXIT

fb_add_searched "Inventory-gated package policies (Python, JavaScript/TypeScript/Bun, Dart, Go, Rust, Ruby, PHP)"
fb_add_searched "Unsupported dependency signals (Maven, Gradle, NuGet, Deno, Pipenv, Conda)"
fb_add_searched "GitHub workflow YAML files for third-party action SHA pins"
fb_add_searched "Dockerfiles for digest-pinned base images"

declare -A SEC03_INVENTORY=()
declare -a SEC03_WORKFLOWS=()
declare -a SEC03_DOCKERFILES=()
declare -a SEC03_UNSUPPORTED=()

sec03_inventory_name_union() {
  local ecosystem
  pp_python_trigger_names
  pp_python_satisfier_names
  pp_javascript_trigger_names
  pp_javascript_satisfier_names
  while IFS= read -r ecosystem; do
    [[ -z "$ecosystem" ]] && continue
    ecosystem_policy_detect_names "$ecosystem"
    ecosystem_policy_file_names "$ecosystem"
  done < <(ecosystem_policy_ids)
  printf '%s\n' \
    "pom.xml" "build.gradle" "build.gradle.kts" "*.csproj" "*.fsproj" "packages.lock.json" \
    "deno.json" "Pipfile" "environment.yml" "Dockerfile" "Dockerfile.*"
}

sec03_collect_inventory() {
  local path basename
  local -a names=()
  mapfile -t names < <(sec03_inventory_name_union | sort -u)
  while IFS= read -r path; do
    [[ -z "$path" || ! -f "$path" ]] && continue
    basename="${path##*/}"
    if [[ -n "${SEC03_INVENTORY[$basename]+set}" ]]; then
      SEC03_INVENTORY["$basename"]+=$'\n'"$path"
    else
      SEC03_INVENTORY["$basename"]="$path"
    fi

    case "$basename" in
      Dockerfile|Dockerfile.*) SEC03_DOCKERFILES+=("$path") ;;
      pom.xml|build.gradle|build.gradle.kts|*.csproj|*.fsproj|packages.lock.json|deno.json|Pipfile|environment.yml)
        SEC03_UNSUPPORTED+=("$path")
        ;;
    esac
  done < <(fp_find_with_names "$PATH_ROOT" "${names[@]}")
  mapfile -t SEC03_WORKFLOWS < <(fp_find_workflow_yamls)
}

sec03_inventory_paths() {
  local basename="$1"
  [[ -n "${SEC03_INVENTORY[$basename]+set}" ]] || return 0
  printf '%s\n' "${SEC03_INVENTORY[$basename]}"
}

sec03_inventory_has_any() {
  local basename
  for basename in "$@"; do
    [[ -n "${SEC03_INVENTORY[$basename]+set}" ]] && return 0
  done
  return 1
}

sec03_inventory_has_names_from() {
  local name
  while IFS= read -r name; do
    [[ -n "$name" && -n "${SEC03_INVENTORY[$name]+set}" ]] && return 0
  done
  return 1
}

sec03_inventory_paths_for_names() {
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] && sec03_inventory_paths "$name"
  done
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

sec03_phase_python_package_policy() {
  if [[ "$SEC03_PYTHON_MODE" == "off" ]]; then
    fb_add_coverage "Python skipped by config"
    return 0
  fi

  if sec03_inventory_has_names_from < <(pp_python_trigger_names); then
    local -a files=()
    mapfile -t files < <(sec03_inventory_paths_for_names < <(pp_python_trigger_names))
    cicd_sec_03_run_python_package_policy "$PATH_ROOT" "${files[@]+"${files[@]}"}" || true
  else
    fb_add_coverage "Python package_policy: skipped; no configured trigger files found in inventory."
  fi
}

sec03_ecosystem_mode() {
  cfg_sec03_ecosystem_mode "$1"
}

sec03_ecosystem_detect_names() {
  if [[ "$1" == "javascript" ]]; then
    pp_javascript_trigger_names
  else
    ecosystem_policy_detect_names "$1"
  fi
}

sec03_ecosystem_label() {
  case "$1" in
    javascript) printf '%s' "JavaScript/TypeScript" ;;
    dart) printf '%s' "Dart" ;;
    go) printf '%s' "Go" ;;
    rust) printf '%s' "Rust" ;;
    ruby) printf '%s' "Ruby" ;;
    php) printf '%s' "PHP" ;;
    *) printf '%s' "$1" ;;
  esac
}

sec03_phase_manifests_and_requirements() {
  local ecosystem label mode trigger_desc
  local -a files=()
  while IFS= read -r ecosystem; do
    [[ -z "$ecosystem" ]] && continue
    label="$(sec03_ecosystem_label "$ecosystem")"
    mode="$(sec03_ecosystem_mode "$ecosystem")"
    if [[ "$mode" == "off" ]]; then
      if [[ "$ecosystem" == "javascript" ]]; then
        fb_add_coverage "JavaScript skipped by config"
      else
        fb_add_coverage "${label} skipped by config"
      fi
      continue
    fi
    if sec03_inventory_has_names_from < <(sec03_ecosystem_detect_names "$ecosystem"); then
      mapfile -t files < <(sec03_inventory_paths_for_names < <(sec03_ecosystem_detect_names "$ecosystem"))
      cicd_sec_03_run_ecosystem_policy "$PATH_ROOT" "$ecosystem" "${files[@]+"${files[@]}"}" || true
    else
      trigger_desc="$(sec03_ecosystem_detect_names "$ecosystem" | paste -sd', ' -)"
      fb_add_coverage "${label} ecosystems.yml policy: skipped; no configured detection files (${trigger_desc:-none configured}) found in inventory."
    fi
  done < <(ecosystem_policy_ids)
}

sec03_phase_unsupported_ecosystems() {
  local path rel basename ecosystem
  if [[ "$SEC03_UNSUPPORTED_MODE" == "off" ]]; then
    fb_add_coverage "Unsupported ecosystems skipped by config"
    return 0
  fi

  for path in "${SEC03_UNSUPPORTED[@]+"${SEC03_UNSUPPORTED[@]}"}"; do
    rel="$(fp_rel_path "$path")"
    fp_should_skip_validation "$rel" && continue
    basename="${path##*/}"
    case "$basename" in
      pom.xml) ecosystem="Maven" ;;
      build.gradle|build.gradle.kts) ecosystem="Gradle" ;;
      *.csproj|*.fsproj|packages.lock.json) ecosystem="NuGet" ;;
      deno.json) ecosystem="Deno" ;;
      Pipfile) ecosystem="Pipenv" ;;
      environment.yml) ecosystem="Conda" ;;
      *) continue ;;
    esac
    fb_report "notice" "Unsupported ${ecosystem} dependency signal '${basename}' detected; dependency policy validation was skipped." \
      "$rel" "" "Review and pin ${ecosystem} dependencies with ecosystem-native tooling." "unsupported"
  done
  fb_add_coverage "Unsupported dependency signals: ${#SEC03_UNSUPPORTED[@]} file(s) detected; notices do not fail the check."
}

sec03_report_config_notices() {
  local ecosystem_id invalid_entry invalid_id invalid_value

  while IFS= read -r ecosystem_id; do
    [[ -z "$ecosystem_id" ]] && continue
    fb_report "notice" "Unknown SEC-03 ecosystem key '${ecosystem_id}'; ignoring it." \
      ".guardrails.yml" "" "Use one of: javascript, python, dart, go, rust, ruby, php." "configuration"
  done < <(cfg_sec03_unknown_ecosystem_keys)

  while IFS= read -r invalid_entry; do
    [[ -z "$invalid_entry" ]] && continue
    invalid_id="${invalid_entry%%=*}"
    invalid_value="${invalid_entry#*=}"
    fb_report "notice" "Invalid SEC-03 ecosystem mode '${invalid_value}' for '${invalid_id}'; using default 'fail'." \
      ".guardrails.yml" "" "Set the ecosystem mode to 'fail' or 'off'." "configuration"
  done < <(cfg_sec03_invalid_ecosystem_values)
}

sec03_phase_workflows_and_dockerfiles() {
  local wf df
  fb_phase "workflows"
  for wf in "${SEC03_WORKFLOWS[@]}"; do
    [[ -z "$wf" || ! -f "$wf" ]] && continue
    local rel
    rel="$(fp_rel_path "$wf")"
    if fp_should_skip_validation "$rel"; then
      continue
    fi
    action_pin_scan_file "$PATH_ROOT" "$wf" "workflows" || true
  done

  fb_phase "docker"
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

fb_phase "inventory"
sec03_collect_inventory
sec03_report_config_notices
fb_phase "python"
sec03_phase_python_package_policy
fb_phase "js"
sec03_phase_manifests_and_requirements
fb_phase "lockfiles"
fb_phase "unsupported"
sec03_phase_unsupported_ecosystems
sec03_phase_workflows_and_dockerfiles

fb_phase "summary"
for sec03_name in package.json pubspec.yaml go.mod Cargo.toml Gemfile composer.json package-lock.json yarn.lock pnpm-lock.yaml bun.lockb pubspec.lock go.sum Cargo.lock Gemfile.lock composer.lock; do
  mapfile -t sec03_files < <(sec03_inventory_paths "$sec03_name")
  case "$sec03_name" in
    package.json|pubspec.yaml|go.mod|Cargo.toml|Gemfile|composer.json)
      sec03__coverage_inventory "Manifest" "$sec03_name" "${sec03_files[@]+"${sec03_files[@]}"}"
      ;;
    *)
      sec03__coverage_inventory "Lock" "$sec03_name" "${sec03_files[@]+"${sec03_files[@]}"}"
      ;;
  esac
done
sec03__coverage_workflows_and_dockerfiles

fb_auto_status "$STRICT_MODE"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT_MODE" false)"
