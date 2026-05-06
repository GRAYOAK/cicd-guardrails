---
name: go-adjust-cicd-guardrails
description: Adjusts cicd-guardrails checks, workflows, summaries, and risk prioritization. Use when changing check scripts, standardizing output (Searched/Found/Remediation), adding OWASP references, tuning risk scoring, or integrating .guardrails.yml context and final summary behavior.
disable-model-invocation: true
---

# Adjust CI/CD Guardrails

## Scope

Use this skill for changes in:
- `scripts/checks/domain/cicd_sec_*.sh` (domain checks)
- `scripts/checks/tech/*.sh` (technical adapters)
- `scripts/lib/feedback.sh`
- `scripts/lib/config.sh`
- `scripts/aggregate_risk_summary.sh`
- `.guardrails.schema.json`
- `.guardrails.example.yml`
- `.github/workflows/full-scan.yml`
- `.github/workflows/self-test.yml`
- `tests/test_checks.sh`
- `README.md`

## Invariants

- Keep all runtime output in English.
- Learnings added to this skill must be generalized.
- Do not store one-off incident details or transient version timelines.
- Exception: keep repository-specific facts when they are structural and stable (tasks, folders, files, and required packages).
- Keep per-check summary blocks consistent:
  - `Searched`
  - `Found`
  - `Remediation`
- Include check designation and OWASP reference in summaries.

## Naming convention (single source of truth)

The OWASP designation is the identity for every check. Keep all four layers in sync when adding or renaming checks:

- **Skript filename**: `scripts/checks/domain/cicd_sec_<NR>[_<aspect>].sh` in snake_case lowercase (e.g. `cicd_sec_05_runner_access.sh`).
- **Workflow job ID**: kebab-case mirror of the filename (e.g. `cicd-sec-05-runner-access`). Used by `skip-checks` input.
- **Display name**: leads with the designation, e.g. `'🖥️ CICD-SEC-05-RUNNER-ACCESS (Runner access policy)'`. Used as required-status-check name on the consumer side.
- **FB_CHECK_ID**: the designation in upper case, identical to the keys allowed in `.guardrails.yml` `checks:` block (e.g. `CICD-SEC-05-RUNNER-ACCESS`).

When several checks belong to the same OWASP family, use a clear suffix (e.g. `CICD-SEC-05-PERMISSIONS`, `CICD-SEC-05-BRANCH`, `CICD-SEC-05-RUNNER-ACCESS`); avoid the bare family ID for a single sub-aspect.

Renaming any of these layers is a breaking change for consumers (status checks, `skip-checks` inputs). Document the mapping in `README.md` and propagate to the demo repo's `.guardrails.yml` if relevant.

## Required workflow for changes

1. Inspect affected scripts and workflow wiring.
2. Update shared behavior in `scripts/lib/feedback.sh` first when possible.
3. Propagate to check scripts with minimal duplication.
4. Ensure reusable workflow still uploads/downstreams artifacts expected by summary jobs.
5. Update docs for any behavior change (`README.md`).
6. Document the current software state in `workspace:Main`.
7. Run tests and sanity checks:
   - `bash ./tests/test_checks.sh`
   - lints/diagnostics for edited files
8. Run a bash-and-workflow quality review with a dedicated subagent after tests pass:
   - Specialist scope: bash scripting and GitHub Actions workflow design.
   - Review focus: best practices, security weaknesses, reliability risks, and maintainability issues.
   - Required output: prioritized findings with severity, concrete remediation guidance, and whether changes are blocking.
   - If findings are actionable, apply fixes and rerun tests/sanity checks before continuing.
9. Run a skill-structure review with a dedicated skill-specialist subagent before finalizing:
   - Goal: decide whether this skill should be split into multiple files and/or multiple focused skills.
   - Scope: responsibilities, section size, coupling, reuse potential, and maintenance overhead.
   - Output: explicit recommendation with rationale:
     - keep as one skill
     - split into multiple files within one skill
     - split into multiple standalone skills
   - If split is recommended, include a proposed target structure and migration order.
10. Always finish with a learning proposal block that the user can accept or reject per item.

## Reference files

- `reference-policies.md`:
  - exit semantics
  - engineering principles
  - output contract for checks
  - GitHub Actions runtime policy
- `reference-risk-model.md`:
  - risk summary and context model
  - `.guardrails.yml` expected fields and schema linkage
  - per-check severity override pattern (`checks: { <DESIGNATION>: { mode: fail|warn|off } }`)
- `playbooks.md`:
  - common change patterns and consumer wiring rules
- `learnings.md`:
  - learning proposal protocol
  - accepted learnings

Load-on-demand triggers:
- For runtime policy, output format, or exit code changes, read `reference-policies.md`.
- For scoring, context-weighting, or per-check override changes, read `reference-risk-model.md`.
- For implementation path decisions, read `playbooks.md`.
- For final chat output and skill updates based on learnings, read `learnings.md`.

## Definition of done

- Tests pass: `bash ./tests/test_checks.sh`
- No new diagnostics in edited files.
- Workflow wiring still consistent for artifacts and final summary job.
- README reflects behavior for users of reusable workflow.
- Schema/example docs and consumer config examples are consistent.
- Current software state is documented in `workspace:Main`.
