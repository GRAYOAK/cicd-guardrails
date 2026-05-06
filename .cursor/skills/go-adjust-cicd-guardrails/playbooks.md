# Playbooks

## Add a new check

1. Create `scripts/check_<name>.sh` using `feedback.sh` helpers.
2. Set `fb_init` with check ID, title, OWASP URL.
3. Add to `full-scan.yml` job list and artifact upload.
4. Include in final summary dependencies and prioritization rules.
5. Add tests in `tests/test_checks.sh` and fixture updates.
6. Update README check table and usage notes.

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
