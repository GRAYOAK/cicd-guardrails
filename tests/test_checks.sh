#!/usr/bin/env bash
# Bash-Tests für alle cicd-guardrails Check-Skripte
#
# Ausführen: bash tests/test_checks.sh
# Aus Repo-Root ausführen!

set -euo pipefail

SCRIPTS_DIR="$(pwd)/scripts"
FIXTURES_DIR="$(pwd)/tests/fixtures"
PASS=0
FAIL=0
LAST_OUTPUT=""
LAST_EXIT=0

# ── Hilfsfunktionen ───────────────────────────────────────────────────────────

setup() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/.github/workflows"
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
    echo "  ❌ $description (erwartet Exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

run_check() {
  local script="$1"
  local path="$2"
  shift 2
  local output_file
  output_file="$(mktemp)"
  set +e
  bash "$SCRIPTS_DIR/$script" "$path" "$@" >"$output_file" 2>&1
  LAST_EXIT=$?
  set -e
  LAST_OUTPUT="$(cat "$output_file")"
  rm -f "$output_file"
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

# ── check_prt.sh ──────────────────────────────────────────────────────────────
echo ""
echo "▶ check_prt.sh"

setup
cp "$FIXTURES_DIR/bad-prt.yml" "$TMP/.github/workflows/ci.yml"
run_check check_prt.sh "$TMP" || true
assert_exit "erkennt pull_request_target" 1 "$LAST_EXIT"
assert_output_contains "liefert Searched Block" "### Searched"
assert_output_contains "liefert Found Block" "### Found"
assert_output_contains "liefert Remediation Block" "### Remediation"
teardown

setup
cp "$FIXTURES_DIR/good-workflow.yml" "$TMP/.github/workflows/ci.yml"
run_check check_prt.sh "$TMP" || true
assert_exit "besteht bei sauberem Workflow" 0 "$LAST_EXIT"
teardown

setup  # Leerer Ordner
run_check check_prt.sh "$TMP" || true
assert_exit "besteht bei leerem workflows-Ordner" 0 "$LAST_EXIT"
teardown

setup
# Inline-Kommentar darf nicht feuern
cat > "$TMP/.github/workflows/ci.yml" << 'EOF'
name: Test
on:
  pull_request:     # verwende pull_request statt pull_request_target
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
EOF
run_check check_prt.sh "$TMP" || true
assert_exit "ignoriert pull_request_target in Inline-Kommentar" 0 "$LAST_EXIT"
teardown

# ── check_pinning.sh ──────────────────────────────────────────────────────────
echo ""
echo "▶ check_pinning.sh"

setup
cp "$FIXTURES_DIR/bad-pinning.yml" "$TMP/.github/workflows/ci.yml"
run_check check_pinning.sh "$TMP" || true
assert_exit "erkennt @v4, @main, @latest" 1 "$LAST_EXIT"
assert_output_contains "liefert Searched Block" "### Searched"
assert_output_contains "liefert Found Block" "### Found"
assert_output_contains "liefert Remediation Block" "### Remediation"
teardown

setup
cp "$FIXTURES_DIR/good-workflow.yml" "$TMP/.github/workflows/ci.yml"
run_check check_pinning.sh "$TMP" || true
assert_exit "besteht bei SHA-gepinnten Actions" 0 "$LAST_EXIT"
teardown

setup
cat > "$TMP/.github/workflows/ci.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - uses: ./actions/my-local-action
EOF
run_check check_pinning.sh "$TMP" || true
assert_exit "ignoriert lokale Actions (./...)" 0 "$LAST_EXIT"
teardown

setup
cat > "$TMP/.github/workflows/ci.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: some-org/some-action
EOF
run_check check_pinning.sh "$TMP" || true
assert_exit "erkennt Action ohne @ " 1 "$LAST_EXIT"
teardown

# ── check_lockfiles.sh ────────────────────────────────────────────────────────
echo ""
echo "▶ check_lockfiles.sh"

setup
echo '{"name":"test"}' > "$TMP/package.json"
run_check check_lockfiles.sh "$TMP" || true
assert_exit "schlägt bei package.json ohne Lock-File" 1 "$LAST_EXIT"
assert_output_contains "liefert Searched Block" "### Searched"
assert_output_contains "liefert Found Block" "### Found"
assert_output_contains "liefert Remediation Block" "### Remediation"
teardown

setup
echo '{"name":"test"}' > "$TMP/package.json"
echo '{"lockfileVersion":3}' > "$TMP/package-lock.json"
run_check check_lockfiles.sh "$TMP" || true
assert_exit "besteht bei package.json + package-lock.json" 0 "$LAST_EXIT"
teardown

setup
echo '{"name":"test"}' > "$TMP/package.json"
echo "# yarn lockfile v1" > "$TMP/yarn.lock"
run_check check_lockfiles.sh "$TMP" || true
assert_exit "besteht bei package.json + yarn.lock" 0 "$LAST_EXIT"
teardown

setup
printf "requests>=2.28.0\nflask\n" > "$TMP/requirements.txt"
run_check check_lockfiles.sh "$TMP" || true
assert_exit "schlägt bei unpinnden requirements.txt" 1 "$LAST_EXIT"
teardown

setup
printf "requests==2.31.0\nflask==3.0.0\n" > "$TMP/requirements.txt"
run_check check_lockfiles.sh "$TMP" || true
assert_exit "besteht bei gepinnten requirements.txt" 0 "$LAST_EXIT"
teardown

setup  # Kein Manifest = kein Fehler
run_check check_lockfiles.sh "$TMP" || true
assert_exit "besteht bei Repo ohne Manifeste" 0 "$LAST_EXIT"
teardown

# ── check_permissions.sh ──────────────────────────────────────────────────────
echo ""
echo "▶ check_permissions.sh"

setup
cp "$FIXTURES_DIR/good-workflow.yml" "$TMP/.github/workflows/ci.yml"
run_check check_permissions.sh "$TMP" || true
assert_exit "besteht bei korrekten permissions" 0 "$LAST_EXIT"
teardown

setup
cat > "$TMP/.github/workflows/ci.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
EOF
run_check check_permissions.sh "$TMP" || true
assert_exit "schlägt bei fehlendem top-level permissions" 1 "$LAST_EXIT"
assert_output_contains "liefert Searched Block" "### Searched"
assert_output_contains "liefert Found Block" "### Found"
assert_output_contains "liefert Remediation Block" "### Remediation"
teardown

setup
cat > "$TMP/.github/workflows/ci.yml" << 'EOF'
name: Test
on: push
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
EOF
run_check check_permissions.sh "$TMP" || true
assert_exit "schlägt bei fehlendem job-level permissions" 1 "$LAST_EXIT"
teardown

# ── Ergebnis ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  $PASS bestanden  |  $FAIL fehlgeschlagen"
echo "═══════════════════════════════════════"

[[ $FAIL -eq 0 ]] || exit 1
