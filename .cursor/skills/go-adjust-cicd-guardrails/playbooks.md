# Playbooks

## Add a new check

1. Create `scripts/checks/domain/cicd_sec_<NR>[_<aspect>].sh` using `feedback.sh` and `config.sh` helpers. Source pattern:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   ROOT_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
   source "${ROOT_SCRIPTS_DIR}/lib/feedback.sh"
   source "${ROOT_SCRIPTS_DIR}/lib/config.sh"
   ```
2. After `fb_init "<DESIGNATION>" ...`, always wire the override:
   ```bash
   cfg_init "$PATH_ROOT"
   fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"
   ```
3. Add a job to `full-scan.yml` with the matching kebab-case ID (`cicd-sec-<nr>[-aspect]`) and a designation-led display name. Include the target checkout, the script invocation, and the artifact upload.
4. Add the new job to the `summarize` job's `needs:` list and to the `skip-checks` description so consumers can disable it.
5. Register the new designation as a property under `checks` in `.guardrails.schema.json` so IDE validation accepts overrides for it.
6. Extend `aggregate_risk_summary.sh` (`base_score`, `context_multiplier_pct`, `derive_*`) with deterministic patterns; place specific designations before generic catch-alls.
7. Add tests in `tests/test_checks.sh` covering designation, exit semantics, and at least one mode override case where realistic.
8. Update README check table and usage notes; mirror in the consumer demo `.guardrails.yml` if behavior is user-facing.

## Modify summary format

1. Change `scripts/lib/feedback.sh` once.
2. Verify all checks still pass tests.
3. Ensure final `aggregate_risk_summary.sh` remains compatible.
4. Update README examples/notes if user-facing output changed.

## Modify scoring/prioritization

1. Adjust weights and context multipliers in `scripts/aggregate_risk_summary.sh`.
2. Keep reasons and fix-order text deterministic and explicit.
3. Validate with at least one failing fixture and one passing fixture.

## Keep consumer demo wiring up to date

When changes affect reusable workflow usage in `cicd-demo-errors`:
1. Keep `Taskfile.dist.yml` paths relative.
2. Prefer remote SHA resolution over local directory SHA:
   - `git ls-remote <guardrails-remote> HEAD | awk '{print $1}'`
3. Update `.github/workflows/security.yml` to pin `full-scan.yml@<SHA>`.
4. Ensure consumer `.guardrails.yml` remains valid against schema values.
5. Ensure consumer `.guardrails.yml` keeps the `yaml-language-server` schema header.
