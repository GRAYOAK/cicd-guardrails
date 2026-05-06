---
name: adjust-cicd-guardrails
description: Adjusts cicd-guardrails checks, workflows, summaries, and risk prioritization. Use when changing check scripts, standardizing output (Searched/Found/Remediation), adding OWASP references, tuning risk scoring, or integrating .guardrails.yml context and final summary behavior.
disable-model-invocation: true
---

# Adjust CI/CD Guardrails

## Scope

Use this skill for changes in:
- `scripts/check_*.sh`
- `scripts/lib/feedback.sh`
- `scripts/aggregate_risk_summary.sh`
- `.guardrails.schema.json`
- `.guardrails.example.yml`
- `.github/workflows/full-scan.yml`
- `.github/workflows/self-test.yml`
- `tests/test_checks.sh`
- `README.md`

## Invariants

- Keep all runtime output in English.
- Keep per-check summary blocks consistent:
  - `Searched`
  - `Found`
  - `Remediation`
- Include check designation and OWASP reference in summaries.
- Preserve exit semantics:
  - `0`: PASS or SKIPPED
  - `1`: actionable failure
  - `2`: missing runtime dependency

## Required workflow for changes

1. Inspect affected scripts and workflow wiring.
2. Update shared behavior in `scripts/lib/feedback.sh` first when possible.
3. Propagate to check scripts with minimal duplication.
4. Ensure reusable workflow still uploads/downstreams artifacts expected by summary jobs.
5. Update docs for any behavior change (`README.md`).
6. Run tests and sanity checks:
   - `bash ./tests/test_checks.sh`
   - lints/diagnostics for edited files

## Risk summary and context model

When adjusting risk prioritization:
- Read context from target repo `.guardrails.yml`.
- Treat `.guardrails.yml` as source of truth.
- Treat `.guardrails.schema.json` as the authoritative list of allowed context values.
- Keep `.guardrails.example.yml` aligned with the schema and README examples.
- Keep missing-config behavior explicit and safe (conservative defaults).
- Keep scoring transparent in final summary (context fields + score rationale).
- Keep schema linkage explicit in consumer config using:
  - `# yaml-language-server: $schema=https://raw.githubusercontent.com/Christopher-Rust/cicd-guardrails/main/.guardrails.schema.json`

Expected `.guardrails.yml` fields:

```yaml
context:
  visibility: public              # public | private | internal
  software_type: open_source      # open_source | private_software
  runner_type: self_hosted        # self_hosted | github_hosted
  data_sensitivity: high          # low | medium | high
  deployment_criticality: prod    # dev | prod | regulated
```

Allowed values are maintained in:
- `.guardrails.schema.json` (reference for valid values and IDE validation)
- `.guardrails.example.yml` (starter config for consumers)

Do not reintroduce `.guardrails.schema.yml`; JSON schema is the canonical format.

## Output contract for checks

Each check should produce:
- GitHub annotations (`error`/`warning`/`notice`) for findings
- Step summary with designation, OWASP reference, status counts
- JSON result artifact (when `GUARDRAILS_RESULT_DIR` is set) for final aggregation

## Common change patterns

### Add a new check

1. Create `scripts/check_<name>.sh` using `feedback.sh` helpers.
2. Set `fb_init` with check ID, title, OWASP URL.
3. Add to `full-scan.yml` job list and artifact upload.
4. Include in final summary dependencies and prioritization rules.
5. Add tests in `tests/test_checks.sh` and fixture updates.
6. Update README check table and usage notes.

### Modify summary format

1. Change `scripts/lib/feedback.sh` once.
2. Verify all checks still pass tests.
3. Ensure final `aggregate_risk_summary.sh` remains compatible.
4. Update README examples/notes if user-facing output changed.

### Modify scoring/prioritization

1. Adjust weights and context multipliers in `scripts/aggregate_risk_summary.sh`.
2. Keep reasons and fix-order text deterministic and explicit.
3. Validate with at least one failing fixture and one passing fixture.

### Keep consumer demo wiring up to date

When changes affect reusable workflow usage in `cicd-demo-errors`:
1. Keep `Taskfile.dist.yml` paths relative.
2. Prefer remote SHA resolution over local directory SHA:
   - `git ls-remote <guardrails-remote> HEAD | awk '{print $1}'`
3. Update `.github/workflows/security.yml` to pin `full-scan.yml@<SHA>`.
4. Ensure consumer `.guardrails.yml` remains valid against schema values.
5. Ensure consumer `.guardrails.yml` keeps the `yaml-language-server` schema header.

## Definition of done

- Tests pass: `bash ./tests/test_checks.sh`
- No new diagnostics in edited files.
- Workflow wiring still consistent for artifacts and final summary job.
- README reflects behavior for users of reusable workflow.
- Schema/example docs and consumer config examples are consistent.
