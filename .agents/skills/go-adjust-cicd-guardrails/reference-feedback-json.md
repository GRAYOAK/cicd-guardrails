# Per-check JSON and scan coverage contract

This note stabilizes the machine-readable results written when `GUARDRAILS_RESULT_DIR` is set and how they relate to human-readable job summaries.

## Purpose

Downstream jobs (for example risk aggregation) read one JSON file per check. The contract must stay backward compatible: new fields are optional; parsers must ignore unknown keys.

## Top-level fields

- `check_id`, `title`, `status`, `mode`, `counts` (errors, warnings, notices), `owasp_reference`: stable identifiers and summary metadata.
- `finding_detail_markdown`: grouped finding text when the check recorded structured rows (may be empty). Truncated before write when very large.
- `scan_coverage_markdown`: factual evidence of what was evaluated (may be empty). Same truncation policy as the job summary block for this field.

## Human summary sections (order)

When coverage is enabled, the printed report uses this order: title and counts, **Searched** (intent), **Scan coverage** (evidence), **Found** (violations only), **Remediation**.

The printed **Remediation** section deduplicates identical bullet text (first-seen order) and adds a short intro paragraph; per-finding remediation strings are still collected during the run but are not written to the JSON artifact (which has no separate remediation field).

## Environment knobs (operator-facing)

- Coverage verbosity for the markdown block: one variable with values **off**, **compact** (default), or **full**. Path samples use a numeric cap in compact mode; full mode uses a higher cap so large monorepos stay bounded.
- Optional overrides exist for path caps; prefer documenting them in the main repository README rather than duplicating numeric defaults here.

## Aggregation

The risk summary step may concatenate shortened coverage from every artifact. If the combined markdown grows too large for the hosting UI, prefer a global character budget, fewer embedded fences, or a separate downloadable artifact over dropping coverage entirely.

When a global budget or artifact fallback is **implemented** in the risk summary script, record the exact behaviour here and in the root `README.md` in the same change set (limits, env toggles, order of fallbacks) so operators have one operational picture without reading source for numbers.

## Compatibility rules

- Writers: always emit valid JSON; omit or empty-string optional fields rather than writing partial structures.
- Readers: use tolerant access for optional string fields; never require new fields for a successful parse.

## Maintenance

- When JSON field names, truncation behaviour, or the intended meaning of scan coverage text changes, update this note and the repository `README.md` section on check output in the **same** change set.
- After adding a **global** bound for aggregated coverage size in the risk summary script, extend automated tests with oversized fixture content so the cap stays covered.
