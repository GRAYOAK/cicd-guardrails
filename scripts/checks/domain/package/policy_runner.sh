#!/usr/bin/env bash

set -euo pipefail

ECOSYSTEM_POLICY_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../config" && pwd)/ecosystems.yml"

ecosystem_policy_detect_names() {
  local ecosystem="$1"
  awk -v ecosystem="$ecosystem" '
    $0 == "  " ecosystem ":" { in_ecosystem = 1; next }
    in_ecosystem && /^  [^ ]+:/ { exit }
    in_ecosystem && /any_files:/ {
      value = $0
      sub(/^.*\[/, "", value)
      sub(/\].*$/, "", value)
      count = split(value, names, /,[[:space:]]*/)
      for (i = 1; i <= count; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", names[i])
        gsub(/^["'\'']|["'\'']$/, "", names[i])
        if (names[i] != "") print names[i]
      }
      exit
    }
  ' "$ECOSYSTEM_POLICY_CONFIG"
}

ecosystem_policy_file_names() {
  local ecosystem="$1"
  awk -v ecosystem="$ecosystem" '
    $0 == "  " ecosystem ":" { in_ecosystem = 1; next }
    in_ecosystem && /^  [^ ]+:/ { exit }
    in_ecosystem && /^      - name: / {
      value = $0
      sub(/^      - name: /, "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      print value
    }
  ' "$ECOSYSTEM_POLICY_CONFIG"
}

# Emits: file name, rule type, rule argument, message, remediation.
ecosystem_policy_rule_records() {
  local ecosystem="$1"
  awk -v ecosystem="$ecosystem" '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      return value
    }
    function emit() {
      if (file != "" && rule != "") {
        print file "|" rule "|" argument "|" message "|" remediation
        rule = argument = message = remediation = ""
      }
    }
    $0 == "  " ecosystem ":" { in_ecosystem = 1; next }
    in_ecosystem && /^  [^ ]+:/ { emit(); exit }
    in_ecosystem && /^      - name: / {
      emit()
      file = $0
      sub(/^      - name: /, "", file)
      file = clean(file)
      rule = argument = message = remediation = ""
      next
    }
    file != "" && /^          - require_sibling: / {
      emit()
      rule = "require_sibling"
      argument = $0
      sub(/^.*\[/, "", argument)
      sub(/\].*$/, "", argument)
      argument = clean(argument)
      message = remediation = ""
      next
    }
    file != "" && /^          - not_empty: true/ {
      emit()
      rule = "not_empty"
      argument = ""
      message = remediation = ""
      next
    }
    rule != "" && /^            message: / {
      message = $0
      sub(/^            message: /, "", message)
      message = clean(message)
      next
    }
    rule != "" && /^            remediation: / {
      remediation = $0
      sub(/^            remediation: /, "", remediation)
      remediation = clean(remediation)
      next
    }
    END { emit() }
  ' "$ECOSYSTEM_POLICY_CONFIG"
}

cicd_sec_03_run_ecosystem_policy() {
  local path_root="$1"
  local ecosystem="$2"
  shift 2
  local -a detectors=("$@")
  local -a required_siblings=()
  local -A audited_directories=()
  local detector rel dir file rule argument message remediation target sibling

  for detector in "${detectors[@]+"${detectors[@]}"}"; do
    [[ -n "$detector" && -f "$detector" ]] || continue
    rel="$(pkg_rel_path "$path_root" "$detector")"
    fp_should_skip_validation "$rel" && continue
    dir="$(dirname "$detector")"
    [[ -n "${audited_directories[$dir]+set}" ]] && continue
    audited_directories["$dir"]=1

    while IFS='|' read -r file rule argument message remediation; do
      [[ -n "$file" && -n "$rule" ]] || continue
      target="${dir}/${file}"
      case "$rule" in
        require_sibling)
          IFS=',' read -ra required_siblings <<<"$argument"
          for sibling in "${required_siblings[@]}"; do
            sibling="${sibling#"${sibling%%[![:space:]]*}"}"
            sibling="${sibling%"${sibling##*[![:space:]]}"}"
            if [[ ! -f "${dir}/${sibling}" ]]; then
              fb_report "error" "$message" "$(pkg_rel_path "$path_root" "$target")" "" \
                "$remediation" "$ecosystem"
            fi
          done
          ;;
        not_empty)
          if [[ -f "$target" && ! -s "$target" ]]; then
            fb_report "error" "$message" "$(pkg_rel_path "$path_root" "$target")" "" \
              "$remediation" "$ecosystem"
          fi
          ;;
        *)
          fb_report "warning" "Unknown ${ecosystem} ecosystem policy rule '${rule}'." \
            "$(pkg_rel_path "$path_root" "$target")" "" \
            "Fix scripts/config/ecosystems.yml." "$ecosystem"
          ;;
      esac
    done < <(ecosystem_policy_rule_records "$ecosystem")
  done
}
