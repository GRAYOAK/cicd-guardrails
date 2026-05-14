---
target_version: NEXT
since_version: any
severity: non-breaking
category: script
affected_consumers: [reusable-workflow, pre-commit, cli]
---

## What changed

Each check summary now includes a **Scan coverage** section describing what the check actually evaluated (counts, samples, and API scope where applicable). Per-check JSON artifacts include an optional `scan_coverage_markdown` field. The aggregated risk summary job prints a **Per-check scan coverage** section assembled from those JSON files.

## Why

Operators need to trace how a PASS or FAIL was produced without inferring intent from static “Searched” bullets alone.

## Required action for consumer repos

- None required. Downstream parsers should treat `scan_coverage_markdown` as optional and ignore unknown JSON keys.
- To reduce verbosity in very large repositories, set `GUARDRAILS_COVERAGE=off` to omit per-check scan coverage sections, or `GUARDRAILS_COVERAGE=full` for deeper path listings (default remains `compact`, capped even in `full` via `GUARDRAILS_COVERAGE_FULL_MAX_PATHS`).

## Detection

```bash
grep -q '### Scan coverage' <<<"$(bash scripts/checks/domain/cicd_sec_04.sh . 2>&1)" || true
```

## Code examples

### Before

```json
{
  "check_id": "CICD-SEC-04",
  "finding_detail_markdown": ""
}
```

### After

```json
{
  "check_id": "CICD-SEC-04",
  "finding_detail_markdown": "",
  "scan_coverage_markdown": "- Example line\n"
}
```
