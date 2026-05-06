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
    CICD-SEC-01*) echo 85 ;;  # flow control
    CICD-SEC-05-VERIFY*) echo 30 ;; # verifier, not the control itself
    CICD-SEC-05-BRANCH*|CICD-SEC-05-RUNNER-ACCESS*) echo 80 ;;  # branch governance and runner access
    CICD-SEC-07*|CICD-SEC-07-RUNNER-HARDENING*) echo 70 ;; # runner hardening
    CICD-SEC-05*) echo 80 ;;  # permissions / pbac default
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
        CICD-SEC-06*|CICD-SEC-04*|CICD-SEC-08*|CICD-SEC-01*) pct=$((pct + 15)) ;;
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
        CICD-SEC-06*|CICD-SEC-05*|CICD-SEC-07*|CICD-SEC-01*) pct=$((pct + 10)) ;;
      esac
      ;;
  esac

  case "$runner_type" in
    self_hosted)
      case "$check_id" in
        CICD-SEC-07*|CICD-SEC-05-RUNNER-ACCESS*) pct=$((pct + 25)) ;;
      esac
      ;;
    github_hosted)
      case "$check_id" in
        CICD-SEC-07*|CICD-SEC-05-RUNNER-ACCESS*) pct=$((pct - 10)) ;;
      esac
      ;;
  esac

  case "$data_sensitivity" in
    high)
      case "$check_id" in
        CICD-SEC-06*|CICD-SEC-05*|CICD-SEC-07*|CICD-SEC-01*) pct=$((pct + 15)) ;;
      esac
      ;;
  esac

  case "$deployment_criticality" in
    prod|regulated)
      case "$check_id" in
        CICD-SEC-06*|CICD-SEC-05*|CICD-SEC-07*|CICD-SEC-01*) pct=$((pct + 10)) ;;
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
    CICD-SEC-01*) echo "Require pull requests with approvals, and disallow force pushes or destructive branch actions on protected branches." ;;
    CICD-SEC-05-BRANCH*) echo "Enable governance controls such as admin enforcement, stale review invalidation, and code-owner review requirements." ;;
    CICD-SEC-05-RUNNER-ACCESS*) echo "Use explicit self-hosted runner labels and isolate sensitive workloads by trust boundary." ;;
    CICD-SEC-05*) echo "Apply least-privilege permissions and enforce protected branch policies (PR required, approvals, no force pushes)." ;;
    CICD-SEC-07*) echo "Harden self-hosted runners, remove privileged and sudo usage, and isolate sensitive workloads." ;;
    CICD-SEC-08*) echo "Pin all third-party actions to full commit SHAs and keep them updated via automation." ;;
    CICD-SEC-03*) echo "Add and commit lockfiles and pin dependencies to exact versions where applicable." ;;
    *) echo "Review findings and apply the recommended remediation." ;;
  esac
}

derive_problem() {
  case "$1" in
    CICD-SEC-06*) echo "Credentials or secrets are present in repository content or history." ;;
    CICD-SEC-04*) echo "Privileged pull request execution can run untrusted contributor-controlled code." ;;
    CICD-SEC-01*) echo "Flow-control gates on protected branches are weak or missing." ;;
    CICD-SEC-05-BRANCH*) echo "Branch governance and authorization controls are not consistently enforced." ;;
    CICD-SEC-05-RUNNER-ACCESS*) echo "Self-hosted runner selection is too broad for trust boundaries." ;;
    CICD-SEC-05*) echo "Access boundaries in workflows or branches are too permissive." ;;
    CICD-SEC-07*) echo "Runner isolation and hardening controls are insufficient for sensitive workloads." ;;
    CICD-SEC-08*) echo "Third-party workflow actions are not pinned to immutable revisions." ;;
    CICD-SEC-03*) echo "Dependencies are not locked to deterministic versions." ;;
    *) echo "Security control findings require review and remediation." ;;
  esac
}

derive_exploit_path() {
  case "$1" in
    CICD-SEC-06*) echo "An attacker can reuse leaked credentials to access infrastructure, package registries, or deployment targets." ;;
    CICD-SEC-04*) echo "A malicious fork PR can abuse privileged workflow context to execute trusted jobs with untrusted code." ;;
    CICD-SEC-01*) echo "An attacker can bypass review flow and push unsafe changes directly into protected branches." ;;
    CICD-SEC-05-BRANCH*) echo "A privileged actor can bypass governance checks and modify protected branches without intended controls." ;;
    CICD-SEC-05-RUNNER-ACCESS*) echo "A compromised job can land on overbroad self-hosted runners and access sensitive runtime surfaces." ;;
    CICD-SEC-05*) echo "An attacker with limited repository access can modify workflows or branches to escalate CI/CD privileges." ;;
    CICD-SEC-07*) echo "Compromised jobs can pivot through weak runner controls into the host or adjacent workloads." ;;
    CICD-SEC-08*) echo "A compromised upstream action tag can inject malicious behavior into your trusted pipeline." ;;
    CICD-SEC-03*) echo "Unpinned dependencies allow stealth dependency drift and malicious package substitution." ;;
    *) echo "The finding can be chained with other weaknesses to widen pipeline compromise impact." ;;
  esac
}

derive_impact() {
  case "$1" in
    CICD-SEC-06*) echo "High likelihood of credential abuse, secret exfiltration, and unauthorized production access." ;;
    CICD-SEC-04*) echo "Pipeline takeover with potential artifact tampering and secret exposure." ;;
    CICD-SEC-01*) echo "Repository flow controls can be bypassed, reducing confidence in reviewed and approved changes." ;;
    CICD-SEC-05-BRANCH*) echo "Governance exceptions can silently weaken branch protection and authorization guarantees." ;;
    CICD-SEC-05-RUNNER-ACCESS*) echo "Weak runner segregation increases blast radius across workloads and environments." ;;
    CICD-SEC-05*) echo "Unauthorized changes can bypass governance and weaken merge/deploy trust." ;;
    CICD-SEC-07*) echo "Runner compromise can lead to lateral movement and persistent CI/CD backdoors." ;;
    CICD-SEC-08*) echo "Supply-chain compromise of builds and downstream artifacts." ;;
    CICD-SEC-03*) echo "Reduced build integrity and increased risk of vulnerable or malicious dependency intake." ;;
    *) echo "Security posture degradation with elevated probability of pipeline abuse." ;;
  esac
}

severity_for_score() {
  local score="$1"
  if [[ "$score" -ge 70 ]]; then
    echo "Critical"
  elif [[ "$score" -ge 40 ]]; then
    echo "High"
  else
    echo "Medium"
  fi
}

owasp_label() {
  echo "OWASP $1"
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

  rows+=("${score}"$'\t'"${check_id}"$'\t'"${status}"$'\t'"${title}"$'\t'"${owasp}")
done

IFS=$'\n' sorted=($(printf "%s\n" "${rows[@]}" | sort -nr -k1,1))

critical=""
high=""
medium=""
critical_count=0
high_count=0
medium_count=0
rank_critical=0
rank_high=0
rank_medium=0
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

  severity="$(severity_for_score "$score")"
  hint="$(derive_fix_hint "$check_id")"
  problem="$(derive_problem "$check_id")"
  exploit="$(derive_exploit_path "$check_id")"
  impact="$(derive_impact "$check_id")"
  reference_label="$(owasp_label "$check_id")"
  entry="1. **${check_id}** — ${title}\n"
  entry+="   - Status: \`${status}\`\n"
  entry+="   - Risk score: \`${score}\`\n"
  entry+="   - Problem: ${problem}\n"
  entry+="   - Exploit path: ${exploit}\n"
  entry+="   - Impact: ${impact}\n"
  entry+="   - Fix first: ${hint}\n"
  if [[ -n "$owasp" ]]; then
    entry+="   - Reference: [${reference_label}](${owasp})\n"
  fi

  case "$severity" in
    Critical)
      rank_critical=$((rank_critical + 1))
      critical_count=$((critical_count + 1))
      entry="${rank_critical}${entry:1}"
      critical+="${entry}\n"
      ;;
    High)
      rank_high=$((rank_high + 1))
      high_count=$((high_count + 1))
      entry="${rank_high}${entry:1}"
      high+="${entry}\n"
      ;;
    *)
      rank_medium=$((rank_medium + 1))
      medium_count=$((medium_count + 1))
      entry="${rank_medium}${entry:1}"
      medium+="${entry}\n"
      ;;
  esac
done

list="- Executive snapshot: Critical \`${critical_count}\` | High \`${high_count}\` | Medium \`${medium_count}\`\n\n"

if [[ -n "$critical" ]]; then
  list+="#### Critical\n${critical}\n"
fi
if [[ -n "$high" ]]; then
  list+="#### High\n${high}\n"
fi
if [[ -n "$medium" ]]; then
  list+="#### Medium\n${medium}\n"
fi

if [[ "$critical_count" -eq 0 && "$high_count" -eq 0 && "$medium_count" -eq 0 ]]; then
  list+="- No actionable findings based on current results.\n"
fi

final="$(print_summary "$list")"
printf "%b\n" "$final"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf "%b\n" "$final" >>"$GITHUB_STEP_SUMMARY"
fi

