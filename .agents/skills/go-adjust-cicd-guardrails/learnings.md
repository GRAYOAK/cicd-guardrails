# Learnings

## Learning proposal protocol (mandatory)

At the end of every task, always output a compact `Lernvorschlaege` section in German.
Do not ask one generic yes/no question for all learnings.
Instead, provide individually selectable items so the user can decide per learning.

Rules:
- Include only generally useful learnings, not incident-specific details.
- Compress each learning to one reusable rule in one sentence.
- Keep each item actionable and stable over time.
- Group by type when useful: behavior, storage location, stable rule.
- Maximum 5 items unless the user explicitly asks for more.
- If there are no solid learnings, explicitly output: `Keine Lernvorschlaege.`

Required output format:

```text
Lernvorschlaege
1) [Typ: Verhalten] <verallgemeinerte Regel>
   In Skill uebernehmen? (ja/nein)
2) [Typ: Stabile-Regel] <verallgemeinerte Regel>
   In Skill uebernehmen? (ja/nein)
```

Optional shorthand format for quick confirmation:

```text
Antwortformat: 1=ja, 2=nein, 3=ja
```

## Accepted learnings

- Prefer passing GitHub App credentials into the reusable workflow and mint short-lived tokens inside relevant called jobs to avoid cross-job secret output warnings and fragile token propagation.
- When fixing workflow runtime deprecations, update producer and consumer wiring together so compatibility, secret contracts, and documentation remain aligned.
- For branch-policy checks, keep deterministic token precedence: explicit admin token first, then in-job GitHub App token, then repository default token.
- For domain checks that read repository-level policy context, always checkout the caller repository to a stable `target` path in the reusable workflow job and pass that path into the check script.
- In risk aggregation pattern matching, place specific designation clauses before generic family catch-alls so scoring and explanation logic remain deterministic as new sub-designations are added.
- Validate remote-derived workflow SHAs with a strict 40-character hexadecimal check before automation rewrites pinned workflow references.
- Keep positive and negative fixture repositories pinned to the same reusable-workflow revision to detect regressions and false positives consistently.
- Separate local verification into file-based checks and API-context checks, and document required token and policy prerequisites explicitly.
- Classify every check that depends primarily on **GitHub API repository policy** (for example branch protection) as **Settings** in workflow job display names, the README scope column, and `check_scope()` in `aggregate_risk_summary.sh`; keep file- and checkout-based checks as **Code**, and keep these three places aligned when adding checks.
- When **job display names** (`name:`) change, update the README required-status-check list and consumer branch protection rules; `skip-checks` and `.guardrails.yml` stay keyed by workflow job ID and `FB_CHECK_ID` only.
- When introducing new Settings-class checks or changing scope rules, extend `check_scope()` and add or adjust tests, or add an optional `scope` field to per-check result JSON and teach the aggregator to prefer it over the allowlist.
- Keep a single reference note for per-check JSON and scan-coverage fields so implementers and consumers share one contract (`reference-feedback-json.md` in this skill folder).
- When assembling markdown for many checks in one summary step, cap total size or publish a separate artifact if Step Summary or log limits are at risk; do not rely on unbounded concatenation.
- When changing per-check JSON field names, truncation limits, or the semantics of scan coverage strings, update `reference-feedback-json.md` (this folder) and the repository `README.md` in the **same** change set so operators, parsers, and docs stay aligned.
- When implementing a global size cap (or equivalent guardrail) for aggregated scan coverage in the risk summary job, add regression tests under `tests/test_checks.sh` using **artificially large** `scan_coverage_markdown` fixture strings so truncation or alternate artifact paths cannot regress silently.
- Once a **global** aggregator budget (or alternate artifact path) for combined scan coverage exists, document the **concrete** limits, any operator knobs, and the **fallback order** (for example truncate then omit versus upload separate artifact) in both the repository `README.md` and `reference-feedback-json.md` in the same change set.
- Pull requests that touch **only** files under `.agents/skills/go-adjust-cicd-guardrails/` (skill text, learnings, local reference notes) should use a Conventional Commit prefix that signals non-shipped product change (for example `docs(skill):` or `chore(skill):`) and should **not** add `migrations/.unreleased` entries unless repository consumers of scripts or workflows are actually affected; release-please then stays aligned with real product surface changes.
- **`release-please-config.json`** maps `docs` commits to the **Documentation** changelog section and keeps **`chore` hidden**; use `docs(skill):` when skill edits should appear in the release notes, and `chore(skill):` when they should stay out of the visible changelog while still following Conventional Commits.
