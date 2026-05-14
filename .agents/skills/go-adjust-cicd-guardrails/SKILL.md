---
name: go-adjust-cicd-guardrails
description: Adjusts cicd-guardrails checks, workflows, summaries, and risk prioritization. Use when changing check scripts, standardizing output (Searched/Found/Remediation), adding OWASP references, tuning risk scoring, or integrating .guardrails.yml context and final summary behavior.
disable-model-invocation: true
---

# Adjust CI/CD Guardrails

## Scope

Use this skill for changes in:
- `scripts/checks/domain/cicd_sec_*.sh` (domain checks)
- `scripts/checks/domain/package/*.sh` (CICD-SEC-03 ecosystem audits)
- `scripts/checks/tech/*.sh` (technical adapters)
- `scripts/lib/feedback.sh`
- `scripts/lib/config.sh`
- `scripts/lib/file_patterns.sh`
- `scripts/lib/package_policy.sh`
- `scripts/config/package_policy.defaults.yml` (shipped Python CICD-SEC-03 defaults merged with overlay `package_policy.python`)
- `scripts/lib/action_pin_audit.sh`
- `scripts/lib/dockerfile_pin_audit.sh`
- `scripts/aggregate_risk_summary.sh`
- `.guardrails.schema.json`
- `.guardrails.example.yml`
- `.guardrails.file-patterns.schema.json`
- `.guardrails.file-patterns.reference.yml`
- `.github/workflows/full-scan.yml`
- `.github/workflows/self-test.yml`
- `.github/workflows/release.yml` and `release-please-config.json` (when release or changelog behaviour is touched)
- `migrations/README.md`, `migrations/TEMPLATE.md`, `migrations/.unreleased/*.md` (consumer migration snippets)
- `CHANGELOG.md` (only when repository policy allows manual edits; otherwise rely on Conventional Commits and release-please)
- `tests/test_checks.sh`
- `README.md`
- `.agents/skills/go-adjust-cicd-guardrails/reference-feedback-json.md` (JSON and scan-coverage contract for implementers)

## Invariants

- Keep all runtime output in English.
- Learnings added to this skill must be generalized.
- Do not store one-off incident details or transient version timelines.
- Exception: keep repository-specific facts when they are structural and stable (tasks, folders, files, and required packages).
- Proactively propose better alternative implementation concepts when they materially improve reliability, security, maintainability, or operability.
- Keep per-check summary blocks consistent:
  - `Searched`
  - `Scan coverage` (evidence of what ran; omit when coverage is turned off)
  - `Found`
  - `Remediation`
- **Module design** (domain checks, shared libraries, and focused `scripts/lib` helpers):
  - **Inputs and configuration**: expose operator-tunable behavior through documented environment variables, schema-driven config files, or small flags so new behavior is discoverable without reading implementation line-by-line.
  - **Processing structure**: prefer phased or library-delegated flows (clear stages, shared helpers) so new ecosystems or policies can attach without rewriting the whole script when reasonable.
  - **Observable output**: every run must make it obvious **what was evaluated** (paths, counts, API scope without secrets) and therefore what was **not** in scope or skipped; violations stay in **Found**, intent stays in **Searched**, evidence stays in **Scan coverage**.
- Include check designation and OWASP reference in summaries.

## Naming convention (single source of truth)

The OWASP designation is the identity for every check. Keep all four layers in sync when adding or renaming checks:

- **Skript filename**: `scripts/checks/domain/cicd_sec_<NR>[_<aspect>].sh` in snake_case lowercase (e.g. `cicd_sec_05_runner_access.sh`).
- **Workflow job ID**: kebab-case mirror of the filename (e.g. `cicd-sec-05-runner-access`). Used by `skip-checks` input.
- **Display name**: GitHub job `name:` in the Actions UI. Use a **scope emoji** (`🧩` = Code / checkout content, `⚙️` = Settings / GitHub API policy), then the text `Code |` or `Settings |`, then a **theme emoji** for the check topic, compact slug, and short title — e.g. `'🧩 Code | 🖥️ 05-runner-access — Runner access'` or `'⚙️ Settings | 🧭 01-flow — Flow control'`. The OWASP designation stays in `FB_CHECK_ID` and JSON, not necessarily in the display string verbatim.
- **FB_CHECK_ID**: the designation in upper case, identical to the keys allowed in `.guardrails.yml` `checks:` block (e.g. `CICD-SEC-05-RUNNER-ACCESS`).

When several checks belong to the same OWASP family, use a clear suffix (e.g. `CICD-SEC-05-PERMISSIONS`, `CICD-SEC-05-BRANCH`, `CICD-SEC-05-RUNNER-ACCESS`); avoid the bare family ID for a single sub-aspect.

Renaming **workflow job IDs** or **`FB_CHECK_ID`** is a breaking change for `skip-checks` and `.guardrails.yml` keys. Changing **job display names** (`name:`) is a breaking change for branch-protection required checks that match that string. Document any rename in `README.md` and propagate to consumer repos when relevant.

### Code vs Settings (display names and risk summary)

- **Settings**: checks driven mainly by **live GitHub repository policy via API** (today: branch protection / flow). Use `⚙️ Settings | …` in job `name:`, mark **Settings** in the README scope column, and include the designation in `check_scope()` in `scripts/aggregate_risk_summary.sh` so grouped markdown stays correct.
- **Code**: checks over **checked-out repository content**. Use `🧩 Code | …` and keep them out of the Settings allowlist unless the implementation changes.
- When adding or reclassifying checks, update workflow names, README, and aggregator together; longer term, an optional `scope` field in per-check result JSON can become the source of truth so the aggregator does not rely only on a growing `check_scope` allowlist.

## Why this matters

- Keep caller-repository checkout explicit (`path: target`) for context-aware checks so `.guardrails.yml` is read from a deterministic location and not from guardrails source checkout paths.
- Keep aggregator match-order explicit (specific designation clauses before family catch-alls) so scoring and remediation text remain deterministic when new sub-designations are introduced.
- Keep reusable-workflow secret contracts explicit and stable: a caller may only pass secrets that are declared under `on.workflow_call.secrets` in the referenced workflow.
- When a repository uses GitHub App credentials (`APP_ID`, `APP_PRIVATE_KEY`), mint a short-lived token in the caller workflow and pass only the resulting token (for example as `admin-token`) to the reusable workflow.

## Required workflow for changes

1. Inspect affected scripts and workflow wiring.
2. Evaluate at least one viable alternative approach and explicitly recommend the better option when trade-offs are meaningful.
3. Update shared behavior in `scripts/lib/feedback.sh` first when possible.
4. Propagate to check scripts with minimal duplication.
5. Ensure reusable workflow still uploads/downstreams artifacts expected by summary jobs.
6. Update docs for any behavior change (`README.md`); when per-check JSON fields or scan-coverage semantics change, update `reference-feedback-json.md` in the same change set (see accepted learnings).
7. **Release and consumer hygiene** (always; see subsection below).
8. Optionally record release-relevant state outside this repository when the team maintains such notes (not required for every change).
9. Run tests and sanity checks:
   - `bash ./tests/test_checks.sh`
   - lints/diagnostics for edited files
10. Run a bash-and-workflow quality review with a dedicated subagent after tests pass:
   - Specialist scope: bash scripting and GitHub Actions workflow design.
   - Review focus: best practices, security weaknesses, reliability risks, and maintainability issues.
   - Required output: prioritized findings with severity, concrete remediation guidance, and whether changes are blocking.
   - If findings are actionable, apply fixes and rerun tests/sanity checks before continuing.
11. Run a skill-structure review with a dedicated skill-specialist subagent before finalizing:
   - Goal: decide whether this skill should be split into multiple files and/or multiple focused skills.
   - Scope: responsibilities, section size, coupling, reuse potential, and maintenance overhead.
   - Output: explicit recommendation with rationale:
     - keep as one skill
     - split into multiple files within one skill
     - split into multiple standalone skills
   - If split is recommended, include a proposed target structure and migration order.
12. Always finish with a learning proposal block that the user can accept or reject per item.

### Release, changelog, and migrations (mandatory)

- **`CHANGELOG.md`**: this repository uses **release-please** (`release.yml` + `release-please-config.json`). Do **not** hand-edit the changelog when the file header states automation ownership. Ship user-visible history through **Conventional Commits** (`feat:`, `fix:`, `perf:`, …) so the release PR updates `CHANGELOG.md`.
- **Commit types vs changelog**: `release-please-config.json` maps **`docs`** to the visible **Documentation** section and marks **`chore` as hidden**, so `docs(skill): …` appears in release notes under Documentation while `chore(skill): …` does not surface in the generated changelog body (still a valid conventional commit).
- **Breaking changes** (`feat!:`, `fix!:`, or `BREAKING CHANGE:` footer): add at least one new snippet under `migrations/.unreleased/<short-slug>.md` copied from `migrations/TEMPLATE.md` so **migration-guard** passes and `release.yml` can assemble `migrations/vX.Y.Z.md` on cut.
- **Non-breaking but consumer-visible** scan surface, job expectations, or hook `files` filters: still add an `.unreleased` snippet when operators or pinned callers must act; otherwise update `README.md` and demo repos clearly.
- **Skill-only edits** (files under `.agents/skills/go-adjust-cicd-guardrails/` with no change to shipped scripts, workflows, or hooks): use a commit prefix such as `docs(skill):` or `chore(skill):` and skip new `migrations/.unreleased` snippets unless product consumers are genuinely impacted; keep release-please noise aligned with the real product surface.
- **Demo repositories** (`cicd-demo-errors`, `cicd-demo-well`): keep them aligned with reusable-workflow behavior and local hook patterns whenever checks change what they exercise.
- After a version exists, consumers should read `migrations/vX.Y.Z.md` from the GitHub Release assets together with `CHANGELOG.md`.

## Reference files

- `.guardrails.file-patterns.reference.yml` (repository root): documents effective file-scan defaults for operators; the `package_policy.python` subtree must remain identical to `scripts/config/package_policy.defaults.yml`. The test suite compares both when `yq` is available — update the reference mirror in the same change set whenever the shipped defaults file changes.
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
- `reference-feedback-json.md` (this folder):
  - per-check JSON fields, scan coverage semantics, aggregation size expectations, backward-compatibility rules for parsers
- `learnings.md`:
  - learning proposal protocol
  - accepted learnings

Load-on-demand triggers:
- For runtime policy, output format, or exit code changes, read `reference-policies.md`.
- For scoring, context-weighting, or per-check override changes, read `reference-risk-model.md`.
- For implementation path decisions, read `playbooks.md`.
- For final chat output and skill updates based on learnings, read `learnings.md`.
- For JSON result files, scan coverage markdown, or aggregator consumption of those fields, read `reference-feedback-json.md`.

## Test repositories

Use two complementary demo repositories to validate changes end-to-end:

- `cicd-demo-errors` (`/Users/rust/Projects/try/CICD Security/cicd-demo-errors`)
  - Purpose: negative fixture with intentional violations.
  - Expected outcome: relevant checks report findings and fail in strict mode.
  - Use it to validate detection quality, annotation clarity, and remediation text.

- `cicd-demo-well` (`/Users/rust/Projects/try/CICD Security/cicd-demo-well`)
  - Purpose: positive fixture with compliant workflows and multi-language lockfile coverage.
  - Expected outcome: file-based checks pass; API-context checks require repository policy context and valid token permissions.
  - Use it to catch false positives and verify stable pass behavior across JS/TS, Python, Go, Rust, Ruby, and PHP package patterns.

When behavior changes are user-facing, update both repositories and keep their workflow pins aligned with the reusable workflow revision.

## Definition of done

- Tests pass: `bash ./tests/test_checks.sh`
- No new diagnostics in edited files.
- Workflow wiring still consistent for artifacts and final summary job.
- README reflects behavior for users of reusable workflow (including migration and changelog policy when relevant).
- Schema, example docs, and consumer config examples are consistent.
- **Changelog policy**: no forbidden manual edits to `CHANGELOG.md`; commits follow Conventional Commits so release-please can update the changelog.
- **Migrations**: breaking PRs include new `migrations/.unreleased/*.md`; consumer-visible changes either add snippets or clearly update README and demo repos.
- **Demo repositories** (`cicd-demo-errors`, `cicd-demo-well`) updated when check behaviour or fixtures change.
- External release notes (for example in a team wiki) updated only when the change set explicitly requires communicating outside this repository.
