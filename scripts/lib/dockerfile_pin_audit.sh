#!/usr/bin/env bash

set -euo pipefail

dockerfile_pin_scan_file() {
  local path_root="$1"
  local abs_file="$2"
  local rel="${abs_file#"${path_root%/}"/}"

  local line num rest
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    num="${line%%:*}"
    rest="${line#*:}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    if [[ "$rest" =~ ^FROM[[:space:]]+scratch(|[[:space:]]|$) ]]; then
      continue
    fi
    if [[ "$rest" =~ \$ ]]; then
      continue
    fi
    if [[ "$rest" =~ @sha256:[a-f0-9]{64} ]]; then
      continue
    fi
    if [[ "$rest" =~ ^FROM[[:space:]]+ ]]; then
      fb_report "error" "Base image in FROM is not pinned to a digest (@sha256:...)." "$rel" "$num" \
        "Pin each external FROM to an immutable digest (sha256)." "docker"
    fi
  done < <(grep -n '^[[:space:]]*FROM[[:space:]]' "$abs_file" 2>/dev/null || true)
}
