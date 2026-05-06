# Reference Policies

## Exit semantics

- `0`: PASS or SKIPPED
- `1`: actionable failure
- `2`: missing runtime dependency

## Engineering principles

- Keep domain logic and technical execution separate:
  - Domain checks define security intent, policy rules, and OWASP designation.
  - Technical adapters encapsulate API calls, CLI invocation, parsing, and runtime dependency handling.
- Keep one primary security responsibility per check.
- Prefer clear single designations per check over mixed composite identifiers.
- Keep reporting contract stable and centralized through feedback helpers.
- Apply changes end-to-end:
  - check logic
  - workflow wiring
  - aggregation/scoring
  - tests
  - README and workspace:Main documentation
  - consumer workflow pinning and migration notes
- Keep breaking changes explicit and synchronized across producer and consumer repositories.
- Keep tests focused on behavior contracts:
  - designation values
  - exit semantics
  - summary structure
  - artifact compatibility with risk aggregation

## Output contract for checks

Each check should produce:
- GitHub annotations (`error`/`warning`/`notice`) for findings
- Step summary with designation, OWASP reference, status counts
- JSON result artifact (when `GUARDRAILS_RESULT_DIR` is set) for final aggregation

## GitHub Actions runtime policy

For JavaScript-based GitHub Actions in this repository:
- Use only action revisions that run on `node24`.
- Do not introduce or keep action revisions that run on `node20`.
- Keep full commit SHA pinning after version updates.
- Validate the affected workflows, tests, and fixtures together after pin changes.
