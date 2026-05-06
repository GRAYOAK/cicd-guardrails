#!/usr/bin/env bash

set -euo pipefail

pkg_rel_path() {
  local path_root="$1"
  local file_path="$2"
  printf '%s' "${file_path#"$path_root"/}"
}

pkg_has_any_lockfile() {
  local manifest="$1"
  shift
  local manifest_dir
  manifest_dir="$(dirname "$manifest")"
  local lockfile
  for lockfile in "$@"; do
    if [[ -f "$manifest_dir/$lockfile" ]]; then
      return 0
    fi
  done
  return 1
}
