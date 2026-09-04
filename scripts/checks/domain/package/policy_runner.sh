#!/usr/bin/env bash

set -euo pipefail

ECOSYSTEM_POLICY_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../config" && pwd)/ecosystems.yml"

ecosystem_policy_ids() {
  awk '
    /^ecosystems:/ { in_ecosystems = 1; next }
    in_ecosystems && /^  [a-zA-Z0-9_-]+:$/ {
      value = $0
      sub(/^  /, "", value)
      sub(/:$/, "", value)
      print value
    }
  ' "$ECOSYSTEM_POLICY_CONFIG"
}

ecosystem_policy_label() {
  local ecosystem="$1"
  local label
  label="$(
    awk -v ecosystem="$ecosystem" '
      $0 == "  " ecosystem ":" { in_ecosystem = 1; next }
      in_ecosystem && /^  [^ ]+:/ { exit }
      in_ecosystem && /^    label: / {
        value = $0
        sub(/^    label: /, "", value)
        gsub(/^["'\'']|["'\'']$/, "", value)
        print value
        exit
      }
    ' "$ECOSYSTEM_POLICY_CONFIG"
  )"
  if [[ -n "$label" ]]; then
    printf '%s' "$label"
  else
    label="${ecosystem//[-_]/ }"
    printf '%s' "${label^}"
  fi
}

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

ecosystem_policy_required_sibling_names() {
  local ecosystem="$1"
  local file rule argument minimum_bytes message remediation sibling
  local -a siblings=()
  while IFS='|' read -r file rule argument minimum_bytes message remediation; do
    [[ "$rule" == "require_sibling" ]] || continue
    IFS=',' read -ra siblings <<<"$argument"
    for sibling in "${siblings[@]}"; do
      sibling="${sibling#"${sibling%%[![:space:]]*}"}"
      sibling="${sibling%"${sibling##*[![:space:]]}"}"
      [[ -n "$sibling" ]] && printf '%s\n' "$sibling"
    done
  done < <(ecosystem_policy_rule_records "$ecosystem")
}

# Emits: file name, rule type, rule argument, minimum bytes, message, remediation.
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
        print file "|" rule "|" argument "|" minimum_bytes "|" message "|" remediation
        rule = argument = minimum_bytes = message = remediation = ""
      }
    }
    $0 == "  " ecosystem ":" { in_ecosystem = 1; next }
    in_ecosystem && /^  [^ ]+:/ { emit(); exit }
    in_ecosystem && /^      - name: / {
      emit()
      file = $0
      sub(/^      - name: /, "", file)
      file = clean(file)
      rule = argument = minimum_bytes = message = remediation = ""
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
    file != "" && /^          - contains: / {
      emit()
      rule = "contains"
      argument = $0
      sub(/^          - contains: /, "", argument)
      argument = clean(argument)
      message = remediation = ""
      next
    }
    file != "" && /^          - validator: / {
      emit()
      rule = "validator"
      argument = $0
      sub(/^          - validator: /, "", argument)
      argument = clean(argument)
      message = remediation = ""
      next
    }
    rule != "" && /^            minimum_bytes: / {
      minimum_bytes = $0
      sub(/^            minimum_bytes: /, "", minimum_bytes)
      minimum_bytes = clean(minimum_bytes)
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

cicd_sec_03_run_named_validator() {
  local validator="$1"
  local path_root="$2"
  local target="$3"
  local ecosystem="$4"
  local context="${5:-$target}"
  case "$validator" in
    javascript_package_policy) sec03_validate_javascript_package_policy "$path_root" "$context" ;;
    package_json_exact_specs) sec03_validate_package_json_exact_specs "$path_root" "$target" ;;
    npm_lock_integrity) sec03_validate_npm_lock_integrity "$path_root" "$target" ;;
    yarn_lock_integrity) sec03_validate_yarn_lock_integrity "$path_root" "$target" ;;
    pnpm_lock_integrity) sec03_validate_pnpm_lock_integrity "$path_root" "$target" ;;
    pip_requirements_txt_hashes) sec03_validate_pip_requirements_txt_hashes "$path_root" "$target" ;;
    poetry_lock_hashes) sec03_validate_poetry_lock_hashes "$path_root" "$target" ;;
    uv_lock_hashes) sec03_validate_uv_lock_hashes "$path_root" "$target" ;;
    nonempty_file)
      if [[ ! -s "$target" ]]; then
        fb_report "error" "$(basename "$target") is empty." "$(pkg_rel_path "$path_root" "$target")" "" \
          "Regenerate the lockfile with the selected package manager and commit it." "$ecosystem"
      fi
      ;;
    *)
      fb_report "error" "Unknown SEC-03 validator '${validator}'; policy execution cannot continue safely." \
        "$(pkg_rel_path "$path_root" "$target")" "" \
        "Fix the validator name in the shipped policy or repository overlay." "$ecosystem"
      ;;
  esac
}

cicd_sec_03_run_ecosystem_policy() {
  local path_root="$1"
  local ecosystem="$2"
  shift 2
  local -a detectors=("$@")
  local -a required_siblings=()
  local -A audited_directories=()
  local detector rel dir file rule argument minimum_bytes message remediation target sibling size

  for detector in "${detectors[@]+"${detectors[@]}"}"; do
    [[ -n "$detector" && -f "$detector" ]] || continue
    rel="$(pkg_rel_path "$path_root" "$detector")"
    fp_should_skip_validation "$rel" && continue
    dir="$(dirname "$detector")"
    [[ -n "${audited_directories[$dir]+set}" ]] && continue
    audited_directories["$dir"]=1

    while IFS='|' read -r file rule argument minimum_bytes message remediation; do
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
        contains)
          if [[ -f "$target" ]]; then
            size="$(wc -c <"$target" 2>/dev/null || echo 0)"
            if [[ -z "$minimum_bytes" || "$size" -ge "$minimum_bytes" ]]; then
              if ! grep -qE -- "$argument" "$target" 2>/dev/null; then
                fb_report "error" "$message" "$(pkg_rel_path "$path_root" "$target")" "" \
                  "$remediation" "$ecosystem"
              fi
            fi
          fi
          ;;
        validator)
          cicd_sec_03_run_named_validator "$argument" "$path_root" "$target" "$ecosystem" "$detector"
          ;;
        *)
          fb_report "error" "Unknown ${ecosystem} ecosystem policy rule '${rule}'." \
            "$(pkg_rel_path "$path_root" "$target")" "" \
            "Fix scripts/config/ecosystems.yml." "$ecosystem"
          ;;
      esac
    done < <(ecosystem_policy_rule_records "$ecosystem")
  done
}
