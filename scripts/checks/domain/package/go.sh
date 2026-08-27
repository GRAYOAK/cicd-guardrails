#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_run_go_package_policy() {
  local path_root="$1"
  shift
  cicd_sec_03_run_same_directory_policy \
    "$path_root" "go" "go" "Run go mod tidy and commit go.sum." "$@"
}
