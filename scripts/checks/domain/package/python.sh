#!/usr/bin/env bash

set -euo pipefail

cicd_sec_03_check_python() {
  local path_root="$1"

  while IFS= read -r manifest; do
    local rel
    rel="$(pkg_rel_path "$path_root" "$manifest")"
    if ! pkg_has_any_lockfile "$manifest" "poetry.lock" "uv.lock"; then
      fb_report "error" "Missing poetry or uv lockfile next to pyproject.toml." "$rel" "" \
        "Generate and commit poetry.lock or uv.lock."
    fi
  done < <(find "$path_root" -name "pyproject.toml" -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null)

  while IFS= read -r req_file; do
    local rel
    rel="$(pkg_rel_path "$path_root" "$req_file")"
    local unpinned
    unpinned="$(grep -vE '^\s*(#|-r |--|-i |$)' "$req_file" | grep -v '==' || true)"
    if [[ -n "$unpinned" ]]; then
      while IFS= read -r line; do
        fb_report "error" "Unpinned python dependency '${line}'." "$rel" "" \
          "Pin each dependency with exact == version."
      done <<<"$unpinned"
    fi
  done < <(find "$path_root" -name "requirements*.txt" -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null)
}
