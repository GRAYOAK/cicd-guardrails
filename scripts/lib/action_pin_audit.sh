#!/usr/bin/env bash

set -euo pipefail

action_pin_scan_file() {
  local path_root="$1"
  local abs_file="$2"
  local ecosystem="${3:-workflows}"
  local rel="${abs_file#"${path_root%/}"/}"

  local findings
  findings="$(awk '
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/#.*$/, "", line)
      # Only YAML action steps: leading optional "  - " then uses:
      if (line !~ /^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]/) next
      if (line ~ /uses:[[:space:]]*\.\//) next
      if (line ~ /@[0-9a-f]{40}[[:space:]]*$/) next
      print NR ": " $0
    }
  ' "$abs_file" 2>/dev/null || true)"

  if [[ -z "$findings" ]]; then
    return 0
  fi

  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    local linenum="${match%%:*}"
    local ref
    ref="$(echo "$match" | sed -E 's/^[0-9]+:[[:space:]]*//' | sed -E 's/.*uses:[[:space:]]*//')"
    fb_report "error" "Unpinned action reference '${ref}'." "$rel" "$linenum" \
      "Pin every third-party action to a full commit SHA." "$ecosystem"
  done <<<"$findings"
}

action_pin_scan_paths_from_stdin() {
  local path_root="$1"
  while IFS= read -r abs_file; do
    [[ -z "$abs_file" || ! -f "$abs_file" ]] && continue
    action_pin_scan_file "$path_root" "$abs_file" || true
  done
}
