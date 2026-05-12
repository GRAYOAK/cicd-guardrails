#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
DOMAIN_DIR="${SCRIPTS_DIR}/checks/domain"
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

assert_aggregate_critical_scope_order() {
  local description="$1"
  if printf '%s' "$LAST_OUTPUT" | python3 -c '
import sys
s = sys.stdin.read()
assert "#### Critical" in s, "missing Critical section"
start = s.index("#### Critical")
end = s.find("#### High", start)
block = s[start:end] if end != -1 else s[start:]
assert "##### Code" in block and "##### Settings" in block
c = block.index("##### Code")
st = block.index("##### Settings")
line7 = "- **CICD-SEC-07-RUNNER-HARDENING**"
line1 = "- **CICD-SEC-01-FLOW**"
assert line7 in block and line1 in block
off7 = block.index(line7)
off1 = block.index(line1)
assert c < off7 < st < off1, (c, off7, st, off1)
'; then
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description (Critical section Code/Settings order or check_id placement)"
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

write_guardrails_yml() {
  local target_dir="$1"
  local mode="$2"
  local check_id="$3"
  local registry="${4:-public}"
  cat > "$target_dir/.guardrails.yml" <<EOF
context:
  visibility: public
  software_type: open_source
  runner_type: github_hosted
  container_registry: ${registry}
  data_sensitivity: medium
  deployment_criticality: dev
checks:
  ${check_id}:
    mode: ${mode}
EOF
}

echo ""
echo "▶ cicd_sec_04.sh"
setup
cp "$FIXTURES_DIR/bad-prt.yml" "$TMP/.github/workflows/ci.yml"
run_check "$DOMAIN_DIR/cicd_sec_04.sh" "$TMP"
assert_exit "detects pull_request_target usage" 1 "$LAST_EXIT"
assert_output_contains "includes Searched block" "### Searched"
assert_output_contains "includes Found block" "### Found"
assert_output_contains "includes Remediation block" "### Remediation"
assert_output_contains "renders Mode line" "Mode: **fail**"
teardown

echo ""
echo "▶ cicd_sec_08.sh"
setup
mkdir -p "$TMP/actions/sample"
cp "$FIXTURES_DIR/bad-pinning.yml" "$TMP/actions/sample/action.yml"
run_check "$DOMAIN_DIR/cicd_sec_08.sh" "$TMP"
assert_exit "detects unpinned action references in composite action" 1 "$LAST_EXIT"
teardown

echo ""
echo "▶ cicd_sec_05_permissions.sh"
setup
cp "$FIXTURES_DIR/good-workflow.yml" "$TMP/.github/workflows/ci.yml"
run_check "$DOMAIN_DIR/cicd_sec_05_permissions.sh" "$TMP"
assert_exit "passes for valid permissions blocks" 0 "$LAST_EXIT"
assert_output_contains "uses CICD-SEC-05-PERMISSIONS designation" "CICD-SEC-05-PERMISSIONS"
teardown

echo ""
echo "▶ cicd_sec_03.sh"
setup
echo '{"name":"demo"}' > "$TMP/package.json"
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "fails when npm lockfile is missing" 1 "$LAST_EXIT"
teardown

echo ""
echo "▶ cicd_sec_03.sh validation_skip_paths (requires yq)"
if command -v yq >/dev/null 2>&1; then
  setup
  mkdir -p "$TMP/vendor/nested" "$TMP/apps/web"
  echo '{"name":"v"}' >"$TMP/vendor/nested/package.json"
  echo '{}' >"$TMP/vendor/nested/package-lock.json"
  echo '{"name":"w"}' >"$TMP/apps/web/package.json"
  echo '{}' >"$TMP/apps/web/yarn.lock"
  cat >"$TMP/.guardrails.file-patterns.yml" <<'EOF'
version: 1
validation_skip_paths:
  - "vendor/*"
EOF
  run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
  assert_exit "passes when vendor tree skipped and app has lockfile" 0 "$LAST_EXIT"
  teardown
else
  echo "  (skipped: yq not installed)"
fi

echo ""
echo "▶ cicd_sec_03.sh monorepo with mixed services"
setup
mkdir -p "$TMP/services/api" "$TMP/services/worker"
cat > "$TMP/services/api/package.json" <<'EOF'
{"name":"api","private":true}
EOF
cat > "$TMP/services/worker/package.json" <<'EOF'
{"name":"worker","private":true}
EOF
echo '{}' > "$TMP/services/worker/package-lock.json"
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "fails when one nested package.json misses lockfile" 1 "$LAST_EXIT"
assert_output_contains "reports nested path for missing lockfile" "services/api/package.json"
teardown

echo ""
echo "▶ cicd_sec_03.sh passes for locked js monorepo"
setup
mkdir -p "$TMP/apps/web" "$TMP/apps/docs"
cat > "$TMP/apps/web/package.json" <<'EOF'
{"name":"web","private":true}
EOF
echo '{}' > "$TMP/apps/web/yarn.lock"
cat > "$TMP/apps/docs/package.json" <<'EOF'
{"name":"docs","private":true}
EOF
echo '{}' > "$TMP/apps/docs/pnpm-lock.yaml"
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "passes when nested npm manifests have lockfiles" 0 "$LAST_EXIT"
teardown

echo ""
echo "▶ cicd_sec_03.sh fails for python pyproject without lockfile"
setup
mkdir -p "$TMP/services/py"
cat > "$TMP/services/py/pyproject.toml" <<'EOF'
[project]
name = "py-service"
version = "0.1.0"
EOF
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "fails when pyproject has no poetry or uv lockfile" 1 "$LAST_EXIT"
assert_output_contains "reports missing pyproject lockfile" "Missing poetry or uv lockfile next to pyproject.toml."
teardown

echo ""
echo "▶ cicd_sec_03.sh fails for unpinned python requirements"
setup
mkdir -p "$TMP/services/py"
cat > "$TMP/services/py/requirements.txt" <<'EOF'
requests
flask==3.0.3
EOF
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "fails for non pinned requirements entry" 1 "$LAST_EXIT"
assert_output_contains "reports unpinned dependency name" "Unpinned python dependency 'requests'."
teardown

echo ""
echo "▶ cicd_sec_03.sh passes for pinned python dependencies"
setup
mkdir -p "$TMP/services/py"
cat > "$TMP/services/py/pyproject.toml" <<'EOF'
[project]
name = "py-service"
version = "0.1.0"
EOF
echo '# lock' > "$TMP/services/py/poetry.lock"
cat > "$TMP/services/py/requirements-dev.txt" <<'EOF'
pytest==8.3.2
ruff==0.5.7
EOF
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "passes for pyproject lockfile and pinned requirements" 0 "$LAST_EXIT"
teardown

echo ""
echo "▶ cicd_sec_03.sh fails for missing go lockfile"
setup
mkdir -p "$TMP/services/go-api"
cat > "$TMP/services/go-api/go.mod" <<'EOF'
module example.com/go-api

go 1.22
EOF
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "fails when go.mod has no go.sum" 1 "$LAST_EXIT"
assert_output_contains "reports missing go lockfile" "Missing go.sum next to go.mod."
teardown

echo ""
echo "▶ cicd_sec_03.sh fails for missing rust lockfile"
setup
mkdir -p "$TMP/services/rust-worker"
cat > "$TMP/services/rust-worker/Cargo.toml" <<'EOF'
[package]
name = "rust-worker"
version = "0.1.0"
edition = "2021"
EOF
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "fails when Cargo.toml has no Cargo.lock" 1 "$LAST_EXIT"
assert_output_contains "reports missing rust lockfile" "Missing Cargo.lock next to Cargo.toml."
teardown

echo ""
echo "▶ cicd_sec_03.sh fails for missing ruby and php lockfiles"
setup
mkdir -p "$TMP/services/ruby-app" "$TMP/services/php-app"
cat > "$TMP/services/ruby-app/Gemfile" <<'EOF'
source "https://rubygems.org"
EOF
cat > "$TMP/services/php-app/composer.json" <<'EOF'
{"name":"acme/php-app"}
EOF
run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
assert_exit "fails when Gemfile or composer.json has no lockfile" 1 "$LAST_EXIT"
assert_output_contains "reports missing ruby lockfile" "Missing Gemfile.lock next to Gemfile."
assert_output_contains "reports missing php lockfile" "Missing composer.lock next to composer.json."
teardown

echo ""
echo "▶ cicd_sec_05_runner_access.sh"
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
PATH="$TMP/bin:$PATH" run_check "$DOMAIN_DIR/cicd_sec_05_runner_access.sh" "$TMP"
assert_exit "warns about generic self-hosted labels" 0 "$LAST_EXIT"
assert_output_contains "uses SEC-05 runner access designation" "CICD-SEC-05-RUNNER-ACCESS"
teardown

echo ""
echo "▶ cicd_sec_07_runner_hardening.sh"
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
PATH="$TMP/bin:$PATH" run_check "$DOMAIN_DIR/cicd_sec_07_runner_hardening.sh" "$TMP"
assert_exit "fails on privileged runner configuration" 1 "$LAST_EXIT"
assert_output_contains "uses SEC-07 hardening designation" "CICD-SEC-07-RUNNER-HARDENING"
teardown

echo ""
echo "▶ cicd_sec_01_flow.sh"
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
PATH="$TMP/bin:$PATH" GITHUB_REPOSITORY="example/repo" run_check "$DOMAIN_DIR/cicd_sec_01_flow.sh"
assert_exit "fails on weak flow controls" 1 "$LAST_EXIT"
assert_output_contains "uses SEC-01 flow designation" "CICD-SEC-01-FLOW"
teardown

echo ""
echo "▶ cicd_sec_05_branch.sh"
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
PATH="$TMP/bin:$PATH" GITHUB_REPOSITORY="example/repo" run_check "$DOMAIN_DIR/cicd_sec_05_branch.sh"
assert_exit "reports branch policy findings with deterministic designation" 1 "$LAST_EXIT"
assert_output_contains "uses SEC-05 branch designation" "CICD-SEC-05-BRANCH"
teardown

# ── Per-check severity override (mode warn / off) ─────────────────────────
if command -v yq >/dev/null 2>&1; then
  echo ""
  echo "▶ cicd_sec_03.sh with mode=warn"
  setup
  echo '{"name":"demo"}' > "$TMP/package.json"
  write_guardrails_yml "$TMP" "warn" "CICD-SEC-03"
  run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
  assert_exit "warn override keeps job green" 0 "$LAST_EXIT"
  assert_output_contains "renders Mode warn" "Mode: **warn**"
  assert_output_contains "renders WARN status" "Status: **WARN**"
  teardown

  echo ""
  echo "▶ cicd_sec_03.sh with mode=off"
  setup
  echo '{"name":"demo"}' > "$TMP/package.json"
  write_guardrails_yml "$TMP" "off" "CICD-SEC-03"
  run_check "$DOMAIN_DIR/cicd_sec_03.sh" "$TMP"
  assert_exit "off override keeps job green" 0 "$LAST_EXIT"
  assert_output_contains "renders Mode off" "Mode: **off**"
  assert_output_contains "renders SKIPPED status" "Status: **SKIPPED**"
  teardown
else
  echo ""
  echo "▶ skipping mode override tests (yq not available)"
fi

echo ""
echo "▶ aggregate_risk_summary.sh"
setup
mkdir -p "$TMP/target" "$TMP/results"
cat > "$TMP/results/CICD-SEC-01-FLOW.json" <<'EOF'
{"check_id":"CICD-SEC-01-FLOW","title":"Flow control policy check","status":"FAIL","mode":"fail","counts":{"errors":1,"warnings":0,"notices":0},"owasp_reference":"https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-01-Insufficient-Flow-Control-Mechanisms/"}
EOF
cat > "$TMP/results/CICD-SEC-07-RUNNER-HARDENING.json" <<'EOF'
{"check_id":"CICD-SEC-07-RUNNER-HARDENING","title":"Runner hardening check","status":"FAIL","mode":"fail","counts":{"errors":1,"warnings":0,"notices":0},"owasp_reference":"https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-07-Insecure-System-Configuration/"}
EOF
run_check "$SCRIPTS_DIR/aggregate_risk_summary.sh" "$TMP/target" "$TMP/results"
assert_exit "returns exit 0 for summary output" 0 "$LAST_EXIT"
assert_output_contains "prints executive snapshot" "Executive snapshot:"
assert_output_contains "groups Critical by Code and Settings" "##### Code"
assert_output_contains "groups Critical by Code and Settings (settings bucket)" "##### Settings"
assert_aggregate_critical_scope_order "Critical: Code bucket lists runner hardening before Settings lists flow check"
assert_output_contains "includes OWASP short reference labels" "[OWASP CICD-SEC-01-FLOW]"
assert_output_contains "lists container_registry context" "container_registry:"
teardown

if command -v yq >/dev/null 2>&1; then
  echo ""
  echo "▶ aggregate_risk_summary.sh with container_registry=public"
  setup
  mkdir -p "$TMP/target" "$TMP/results"
  cat > "$TMP/target/.guardrails.yml" <<'EOF'
context:
  visibility: public
  software_type: open_source
  runner_type: github_hosted
  container_registry: public
  data_sensitivity: medium
  deployment_criticality: dev
EOF
  cat > "$TMP/results/CICD-SEC-08.json" <<'EOF'
{"check_id":"CICD-SEC-08","title":"Action pinning check","status":"FAIL","mode":"fail","counts":{"errors":1,"warnings":0,"notices":0},"owasp_reference":"https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-08-Ungoverned-Usage-of-3rd-Party-Services/"}
EOF
  run_check "$SCRIPTS_DIR/aggregate_risk_summary.sh" "$TMP/target" "$TMP/results"
  assert_exit "summary completes with public registry" 0 "$LAST_EXIT"
  assert_output_contains "shows public container_registry" "container_registry: \`public\`"
  teardown

  echo ""
  echo "▶ aggregate_risk_summary.sh shows softened-mode note"
  setup
  mkdir -p "$TMP/target" "$TMP/results"
  cat > "$TMP/results/CICD-SEC-08.json" <<'EOF'
{"check_id":"CICD-SEC-08","title":"Action pinning check","status":"WARN","mode":"warn","counts":{"errors":0,"warnings":1,"notices":0},"owasp_reference":"https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-08-Ungoverned-Usage-of-3rd-Party-Services/"}
EOF
  run_check "$SCRIPTS_DIR/aggregate_risk_summary.sh" "$TMP/target" "$TMP/results"
  assert_exit "summary completes with softened check" 0 "$LAST_EXIT"
  assert_output_contains "shows mode override note" "per-check override"
  teardown
fi

echo ""
echo "═══════════════════════════════════════"
echo "  $PASS passed  |  $FAIL failed"
echo "═══════════════════════════════════════"

[[ $FAIL -eq 0 ]] || exit 1
