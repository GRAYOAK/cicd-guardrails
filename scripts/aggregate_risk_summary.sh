#!/usr/bin/env bash

set -euo pipefail

TARGET_DIR="${1:-target}"
RESULTS_DIR="${2:-guardrails-results}"

CONFIG_PATH="${TARGET_DIR}/.guardrails.yml"

read_config() {
  local key="$1"
  local default="$2"

  if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "$default"
    return
  fi

  if ! command -v yq >/dev/null 2>&1; then
    echo "$default"
    return
  fi

  local val
  val="$(yq -r "$key // \"\"" "$CONFIG_PATH" 2>/dev/null || true)"
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "$default"
  else
    echo "$val"
  fi
}

visibility="$(read_config '.context.visibility' 'unknown')"
software_type="$(read_config '.context.software_type' 'unknown')"
runner_type="$(read_config '.context.runner_type' 'unknown')"
data_sensitivity="$(read_config '.context.data_sensitivity' 'unknown')"
deployment_criticality="$(read_config '.context.deployment_criticality' 'unknown')"

base_score() {
  case "$1" in
    CICD-SEC-06*) echo 100 ;; # credentials/secrets
    CICD-SEC-04*) echo 90 ;;  # poisoned pipeline
    CICD-SEC-05-VERIFY*) echo 30 ;; # verifier, not the control itself
    CICD-SEC-05*) echo 80 ;;  # permissions / branch protection
    CICD-SEC-07*|CICD-SEC-05-07*) echo 70 ;; # runner config
    CICD-SEC-08*) echo 60 ;;  # third-party pinning
    CICD-SEC-03*) echo 40 ;;  # dependency lockfiles
    *) echo 25 ;;
  esac
}

context_multiplier_pct() {
  local check_id="$1"
  local pct=100

  case "$visibility" in
    public)
      case "$check_id" in
        CICD-SEC-06*|CICD-SEC-04*|CICD-SEC-08*) pct=$((pct + 15)) ;;
      esac
      ;;
  esac

  case "$software_type" in
    open_source)
      case "$check_id" in
        CICD-SEC-06*|CICD-SEC-08*|CICD-SEC-04*) pct=$((pct + 10)) ;;
      esac
      ;;
    private_software)
      case "$check_id" in
        CICD-SEC-06*|CICD-SEC-05*|CICD-SEC-07*|CICD-SEC-05-07*) pct=$((pct + 10)) ;;
      esac
      ;;
  esac

  case "$runner_type" in
    self_hosted)
      case "$check_id" in
        CICD-SEC-07*|CICD-SEC-05-07*) pct=$((pct + 25)) ;;
      esac
      ;;
    github_hosted)
      case "$check_id" in
        CICD-SEC-07*|CICD-SEC-05-07*) pct=$((pct - 10)) ;;
      esac
      ;;
  esac

  case "$data_sensitivity" in
    high)
      case "$check_id" in
        CICD-SEC-06*|CICD-SEC-05*|CICD-SEC-07*|CICD-SEC-05-07*) pct=$((pct + 15)) ;;
      esac
      ;;
  esac

  case "$deployment_criticality" in
    prod|regulated)
      case "$check_id" in
        CICD-SEC-06*|CICD-SEC-05*|CICD-SEC-07*|CICD-SEC-05-07*) pct=$((pct + 10)) ;;
      esac
      ;;
  esac

  if [[ $pct -lt 50 ]]; then pct=50; fi
  if [[ $pct -gt 200 ]]; then pct=200; fi
  echo "$pct"
}

status_weight_pct() {
  case "$1" in
    FAIL) echo 100 ;;
    WARN) echo 60 ;;
    PASS|SKIPPED) echo 0 ;;
    *) echo 0 ;;
  esac
}

derive_fix_hint() {
  case "$1" in
    CICD-SEC-06*) echo "Remove secrets from git history and rotate credentials immediately. Enforce secret scanning and use a dedicated secret store." ;;
    CICD-SEC-04*) echo "Avoid pull_request_target for untrusted PRs. Separate privileged jobs and prevent checking out fork head refs." ;;
    CICD-SEC-05*) echo "Apply least-privilege permissions and enforce protected branch policies (PR required, approvals, no force pushes)." ;;
    CICD-SEC-07*|CICD-SEC-05-07*) echo "Harden self-hosted runners, restrict labels, remove privileged/sudo usage, and isolate sensitive workloads." ;;
    CICD-SEC-08*) echo "Pin all third-party actions to full commit SHAs and keep them updated via automation." ;;
    CICD-SEC-03*) echo "Add and commit lockfiles and pin dependencies to exact versions where applicable." ;;
    *) echo "Review findings and apply the recommended remediation." ;;
  esac
}

print_summary() {
  local out
  out="## Risk summary and fix order\n\n"
  out+="- Context:\n"
  out+="  - visibility: \`${visibility}\`\n"
  out+="  - software_type: \`${software_type}\`\n"
  out+="  - runner_type: \`${runner_type}\`\n"
  out+="  - data_sensitivity: \`${data_sensitivity}\`\n"
  out+="  - deployment_criticality: \`${deployment_criticality}\`\n"

  if [[ ! -f "$CONFIG_PATH" ]]; then
    out+="\n- Note: no \`.guardrails.yml\` found in the target repository. Using conservative defaults.\n"
  elif ! command -v yq >/dev/null 2>&1; then
    out+="\n- Note: \`.guardrails.yml\` found but \`yq\` is missing; using conservative defaults.\n"
  fi

  out+="\n### Prioritized fix order\n"
  out+="$1\n"

  printf "%b" "$out"
}

best_effort_results=()
while IFS= read -r f; do
  best_effort_results+=("$f")
done < <(find "$RESULTS_DIR" -type f -name "*.json" 2>/dev/null || true)

if [[ ${#best_effort_results[@]} -eq 0 ]]; then
  msg="No check results found. Ensure each check job uploads JSON artifacts.\n"
  print_summary "- No results available.\n\n${msg}"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    print_summary "- No results available.\n\n${msg}" >>"$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi

rows=()
for file in "${best_effort_results[@]}"; do
  check_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["check_id"])' "$file")"
  title="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["title"])' "$file")"
  status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$file")"
  owasp="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("owasp_reference",""))' "$file")"

  b="$(base_score "$check_id")"
  m="$(context_multiplier_pct "$check_id")"
  w="$(status_weight_pct "$status")"
  score=$(( b * m * w / 10000 ))

  rows+=("${score}\t${check_id}\t${status}\t${title}\t${owasp}")
done

IFS=$'\n' sorted=($(printf "%s\n" "${rows[@]}" | sort -nr -k1,1))

list=""
rank=0
for r in "${sorted[@]}"; do
  score="${r%%$'\t'*}"
  rest="${r#*$'\t'}"
  check_id="${rest%%$'\t'*}"
  rest="${rest#*$'\t'}"
  status="${rest%%$'\t'*}"
  rest="${rest#*$'\t'}"
  title="${rest%%$'\t'*}"
  owasp="${rest#*$'\t'}"

  if [[ "$score" -le 0 ]]; then
    continue
  fi

  rank=$((rank + 1))
  hint="$(derive_fix_hint "$check_id")"

  list+="${rank}. **${check_id}** — ${title}\n"
  list+="   - status: \`${status}\`\n"
  list+="   - risk_score: \`${score}\`\n"
  if [[ -n "$owasp" ]]; then
    list+="   - owasp: ${owasp}\n"
  fi
  list+="   - fix: ${hint}\n"
done

if [[ -z "$list" ]]; then
  list="- No actionable findings based on current results.\n"
fi

final="$(print_summary "$list")"
printf "%b\n" "$final"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf "%b\n" "$final" >>"$GITHUB_STEP_SUMMARY"
fi

