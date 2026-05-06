#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"
PASS=0
FAIL=0
LAST_OUTPUT=""
LAST_EXIT=0

setup() {
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/.github/workflows" "$TMP/bin"
}

teardown() {
  rm -rf "$TMP"
}

assert_exit() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_contains() {
  local description="$1"
  local expected="$2"
  if [[ "$LAST_OUTPUT" == *"$expected"* ]]; then
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description (missing '$expected')"
    FAIL=$((FAIL + 1))
  fi
}

run_check() {
  local script="$1"
  shift
  local output_file
  output_file="$(mktemp)"
  set +e
  bash "$script" "$@" >"$output_file" 2>&1
  LAST_EXIT=$?
  set -e
  LAST_OUTPUT="$(python3 - <<'PY' "$output_file"
import pathlib, sys
print(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"))
PY
)"
  rm -f "$output_file"
}

echo ""
echo "▶ check_prt.sh"
setup
cp "$FIXTURES_DIR/bad-prt.yml" "$TMP/.github/workflows/ci.yml"
run_check "$SCRIPTS_DIR/check_prt.sh" "$TMP"
assert_exit "detects pull_request_target usage" 1 "$LAST_EXIT"
assert_output_contains "includes Searched block" "### Searched"
assert_output_contains "includes Found block" "### Found"
assert_output_contains "includes Remediation block" "### Remediation"
teardown

echo ""
echo "▶ check_pinning.sh"
setup
cp "$FIXTURES_DIR/bad-pinning.yml" "$TMP/.github/workflows/ci.yml"
run_check "$SCRIPTS_DIR/check_pinning.sh" "$TMP"
assert_exit "detects unpinned action references" 1 "$LAST_EXIT"
teardown

echo ""
echo "▶ check_permissions.sh"
setup
cp "$FIXTURES_DIR/good-workflow.yml" "$TMP/.github/workflows/ci.yml"
run_check "$SCRIPTS_DIR/check_permissions.sh" "$TMP"
assert_exit "passes for valid permissions blocks" 0 "$LAST_EXIT"
teardown

echo ""
echo "▶ check_lockfiles.sh"
setup
echo '{"name":"demo"}' > "$TMP/package.json"
run_check "$SCRIPTS_DIR/check_lockfiles.sh" "$TMP"
assert_exit "fails when npm lockfile is missing" 1 "$LAST_EXIT"
teardown

echo ""
echo "▶ check_runner_access.sh"
setup
cat > "$TMP/.github/workflows/ci.yml" <<'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: self-hosted
    steps:
      - run: echo hello
EOF
cat > "$TMP/bin/yq" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == ".jobs | to_entries | .[] | select(.value[\"runs-on\"] == \"self-hosted\") | .key" ]]; then
  echo "test"
  exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/yq"
PATH="$TMP/bin:$PATH" run_check "$SCRIPTS_DIR/checks/domain/check_runner_access.sh" "$TMP"
assert_exit "warns about generic self-hosted labels" 0 "$LAST_EXIT"
assert_output_contains "uses SEC-05 runner access designation" "CICD-SEC-05-RUNNER-ACCESS"
teardown

echo ""
echo "▶ check_runner_hardening.sh"
setup
cat > "$TMP/.github/workflows/ci.yml" <<'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ubuntu
      options: --privileged
    steps:
      - run: sudo whoami
EOF
cat > "$TMP/bin/yq" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == ".jobs | to_entries | .[] | select(.value.container.options != null) | select(.value.container.options | test(\"--privileged\")) | .key" ]]; then
  echo "test"
  exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/yq"
PATH="$TMP/bin:$PATH" run_check "$SCRIPTS_DIR/checks/domain/check_runner_hardening.sh" "$TMP"
assert_exit "fails on privileged runner configuration" 1 "$LAST_EXIT"
assert_output_contains "uses SEC-07 hardening designation" "CICD-SEC-07-RUNNER-HARDENING"
teardown

echo ""
echo "▶ check_flow_control.sh"
setup
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "api" && "$2" == repos/example/repo ]]; then
  echo '{"default_branch":"main"}'
  exit 0
fi
if [[ "$1" == "api" && "$2" == repos/example/repo/branches/main/protection ]]; then
  cat <<JSON
{
  "required_pull_request_reviews": {"required_approving_review_count": 0},
  "allow_force_pushes": {"enabled": true},
  "allow_deletions": {"enabled": false},
  "enforce_admins": {"enabled": true}
}
JSON
  exit 0
fi
exit 1
EOF
cat > "$TMP/bin/jq" <<'EOF'
#!/usr/bin/env bash
python3 -c "import json,sys; d=json.load(sys.stdin); q=sys.argv[1] if len(sys.argv)>1 else '.'
if q=='.': print(json.dumps(d)); sys.exit(0)
if 'default_branch' in q: print(d.get('default_branch','')); sys.exit(0)
if 'required_pull_request_reviews // empty' in q: v=d.get('required_pull_request_reviews'); print('' if v in (None,{}) else json.dumps(v)); sys.exit(0)
if 'required_approving_review_count' in q: print(d.get('required_pull_request_reviews',{}).get('required_approving_review_count',0)); sys.exit(0)
if 'allow_force_pushes.enabled' in q: print(str(d.get('allow_force_pushes',{}).get('enabled',False)).lower()); sys.exit(0)
if 'allow_deletions.enabled' in q: print(str(d.get('allow_deletions',{}).get('enabled',False)).lower()); sys.exit(0)
if 'enforce_admins.enabled' in q: print(str(d.get('enforce_admins',{}).get('enabled',False)).lower()); sys.exit(0)
print('')"
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/jq"
PATH="$TMP/bin:$PATH" GITHUB_REPOSITORY="example/repo" run_check "$SCRIPTS_DIR/checks/domain/check_flow_control.sh"
assert_exit "fails on weak flow controls" 1 "$LAST_EXIT"
assert_output_contains "uses SEC-01 flow designation" "CICD-SEC-01-FLOW"
teardown

echo ""
echo "▶ check_pbac_branch_policy.sh"
setup
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "api" && "$2" == repos/example/repo ]]; then
  echo '{"default_branch":"main"}'
  exit 0
fi
if [[ "$1" == "api" && "$2" == repos/example/repo/branches/main/protection ]]; then
  cat <<JSON
{
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "enforce_admins": {"enabled": false}
}
JSON
  exit 0
fi
exit 1
EOF
cat > "$TMP/bin/jq" <<'EOF'
#!/usr/bin/env bash
python3 -c "import json,sys; d=json.load(sys.stdin); q=sys.argv[1] if len(sys.argv)>1 else '.'
if q=='.': print(json.dumps(d)); sys.exit(0)
if 'default_branch' in q: print(d.get('default_branch','')); sys.exit(0)
if 'dismiss_stale_reviews' in q: print(str(d.get('required_pull_request_reviews',{}).get('dismiss_stale_reviews',False)).lower()); sys.exit(0)
if 'require_code_owner_reviews' in q: print(str(d.get('required_pull_request_reviews',{}).get('require_code_owner_reviews',False)).lower()); sys.exit(0)
if 'enforce_admins.enabled' in q: print(str(d.get('enforce_admins',{}).get('enabled',False)).lower()); sys.exit(0)
print('')"
EOF
chmod +x "$TMP/bin/gh" "$TMP/bin/jq"
PATH="$TMP/bin:$PATH" GITHUB_REPOSITORY="example/repo" run_check "$SCRIPTS_DIR/checks/domain/check_pbac_branch_policy.sh"
assert_exit "reports branch policy findings with deterministic designation" 1 "$LAST_EXIT"
assert_output_contains "uses SEC-05 branch designation" "CICD-SEC-05-BRANCH"
teardown

echo ""
echo "▶ aggregate_risk_summary.sh"
setup
mkdir -p "$TMP/target" "$TMP/results"
cat > "$TMP/results/CICD-SEC-01-FLOW.json" <<'EOF'
{"check_id":"CICD-SEC-01-FLOW","title":"Flow control policy check","status":"FAIL","counts":{"errors":1,"warnings":0,"notices":0},"owasp_reference":"https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-01-Insufficient-Flow-Control-Mechanisms/"}
EOF
cat > "$TMP/results/CICD-SEC-07-RUNNER-HARDENING.json" <<'EOF'
{"check_id":"CICD-SEC-07-RUNNER-HARDENING","title":"Runner hardening check","status":"FAIL","counts":{"errors":1,"warnings":0,"notices":0},"owasp_reference":"https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-07-Insecure-System-Configuration/"}
EOF
run_check "$SCRIPTS_DIR/aggregate_risk_summary.sh" "$TMP/target" "$TMP/results"
assert_exit "returns exit 0 for summary output" 0 "$LAST_EXIT"
assert_output_contains "prints executive snapshot" "Executive snapshot:"
assert_output_contains "includes OWASP short reference labels" "[OWASP CICD-SEC-01-FLOW]"
teardown

echo ""
echo "═══════════════════════════════════════"
echo "  $PASS passed  |  $FAIL failed"
echo "═══════════════════════════════════════"

[[ $FAIL -eq 0 ]] || exit 1

