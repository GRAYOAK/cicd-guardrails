#!/usr/bin/env bash

set -euo pipefail

# Runs simple ecosystem policies where trigger and satisfier files must share a
# directory. Policy accessors are provided by scripts/lib/package_policy.sh.
cicd_sec_03_run_same_directory_policy() {
  local path_root="$1"
  local policy_key="$2"
  local ecosystem="$3"
  local remediation="$4"
  shift 4
  local -a manifests=("$@")

  local satisfier_fn="pp_${policy_key}_satisfier_names"
  local validator_fn="pp_${policy_key}_validator_for"
  local -a satisfiers=()
  local satisfier
  while IFS= read -r satisfier; do
    [[ -n "$satisfier" ]] && satisfiers+=("$satisfier")
  done < <("$satisfier_fn")
  if ((${#satisfiers[@]} == 0)); then
    fb_report "warning" "No satisfiers are configured for package_policy.${policy_key}; validation was skipped." "" "" \
      "Configure at least one same-directory satisfier for package_policy.${policy_key}." "$ecosystem"
    return 0
  fi

  local manifest rel dir present validator
  for manifest in "${manifests[@]+"${manifests[@]}"}"; do
    [[ -n "$manifest" && -f "$manifest" ]] || continue
    rel="$(pkg_rel_path "$path_root" "$manifest")"
    fp_should_skip_validation "$rel" && continue
    dir="$(dirname "$manifest")"
    present=""
    for satisfier in "${satisfiers[@]+"${satisfiers[@]}"}"; do
      if [[ -f "${dir}/${satisfier}" ]]; then
        present="$satisfier"
        break
      fi
    done

    if [[ -z "$present" ]]; then
      fb_report "error" "Missing ${satisfiers[0]} next to ${manifest##*/}." "$rel" "" \
        "$remediation" "$ecosystem"
      continue
    fi

    validator="$("$validator_fn" "$present")"
    case "$validator" in
      nonempty_file)
        if [[ ! -s "${dir}/${present}" ]]; then
          fb_report "error" "${present} is empty." "$(pkg_rel_path "$path_root" "${dir}/${present}")" "" \
            "$remediation" "$ecosystem"
        fi
        ;;
      "")
        ;;
      *)
        fb_report "warning" "Unknown ${ecosystem} lock validator '${validator}'." \
          "$(pkg_rel_path "$path_root" "${dir}/${present}")" "" \
          "Fix package_policy.${policy_key}.hash_validators in the defaults or overlay." "$ecosystem"
        ;;
    esac
  done
}
