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

PATH_ROOT="${1:-.}"
STRICT_MODE="false"
if [[ "${2:-}" == "--strict" ]]; then
  STRICT_MODE="true"
fi

fb_init "CICD-SEC-03" "Dependency pinning and lockfile check" "https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-03-Dependency-Chain-Abuse/"
cfg_init "$PATH_ROOT"
fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"
fb_add_searched "JavaScript and TypeScript package manifests with sibling lockfiles"
fb_add_searched "Python pyproject manifests with sibling poetry or uv lockfiles"
fb_add_searched "Python requirements files with exact version pinning"
fb_add_searched "Go modules with sibling go.sum lockfiles"
fb_add_searched "Rust package manifests with sibling Cargo.lock lockfiles"
fb_add_searched "Ruby package manifests with sibling Gemfile.lock lockfiles"
fb_add_searched "PHP package manifests with sibling composer.lock lockfiles"

cicd_sec_03_check_js_ts "$PATH_ROOT"
cicd_sec_03_check_python "$PATH_ROOT"
cicd_sec_03_check_go "$PATH_ROOT"
cicd_sec_03_check_rust "$PATH_ROOT"
cicd_sec_03_check_ruby "$PATH_ROOT"
cicd_sec_03_check_php "$PATH_ROOT"

fb_auto_status "$STRICT_MODE"
if [[ "$FB_STATUS" == "PASS" ]]; then
  fb_add_remediation "No remediation needed."
fi
fb_summary
exit "$(fb_exit_code "$STRICT_MODE" false)"
