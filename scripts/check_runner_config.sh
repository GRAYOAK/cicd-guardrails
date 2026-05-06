#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH_ROOT="${1:-.}"
STRICT_FLAG="${2:-}"

bash "${SCRIPT_DIR}/checks/domain/check_runner_access.sh" "${PATH_ROOT}" "${STRICT_FLAG}"
bash "${SCRIPT_DIR}/checks/domain/check_runner_hardening.sh" "${PATH_ROOT}" "${STRICT_FLAG}"
