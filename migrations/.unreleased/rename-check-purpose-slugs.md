---
target_version: NEXT
since_version: "0.4.0"
severity: breaking
category: workflow
affected_consumers: [reusable-workflow, pre-commit, config]
---

## What changed

Check designations for SEC-03, SEC-04, SEC-06, and SEC-08 now include explicit purpose slugs on all four layers (script filename, workflow job ID, `FB_CHECK_ID`, and Actions display name). Legacy short IDs remain accepted for `skip-checks` and `.guardrails.yml` mode lookup for one release cycle via runtime aliasing in `scripts/lib/config.sh`.

## Why

Bare OWASP numbers (`CICD-SEC-03`) did not convey what each check does. Purpose slugs align with the existing SEC-05 sub-check pattern and make agent and operator navigation unambiguous.

## Required action for consumer repos

- Bump the reusable workflow pin to the release tag commit SHA.
- Rename keys in `.guardrails.yml` (see mapping below). Legacy keys still work until you migrate.
- Update `skip-checks` tokens to the new job IDs (legacy `cicd-sec-03`, `cicd-sec-04`, `cicd-sec-06`, `cicd-sec-08` still skip the matching jobs).
- Update pre-commit hook `id` values in `.pre-commit-config.yaml` and bump `rev` to the new SHA.
- Update GitHub Branch Protection required status checks to match the new job **display names** (see README Branch Protection section).

### ID mapping

| Legacy `FB_CHECK_ID` / hook / skip token | New designation | New job ID |
|------------------------------------------|-----------------|------------|
| `CICD-SEC-03` / `cicd-sec-03` | `CICD-SEC-03-DEPENDENCY-CHAIN` | `cicd-sec-03-dependency-chain` |
| `CICD-SEC-04` / `cicd-sec-04` | `CICD-SEC-04-POISONED-PIPELINE` | `cicd-sec-04-poisoned-pipeline` |
| `CICD-SEC-06` / `cicd-sec-06` | `CICD-SEC-06-SECRET-SCAN` | `cicd-sec-06-secret-scan` |
| `CICD-SEC-08` / `cicd-sec-08` | `CICD-SEC-08-ACTION-PINNING` | `cicd-sec-08-action-pinning` |

## Detection

```bash
rg 'CICD-SEC-0[3468]"?:|cicd-sec-0[3468][^-]|cicd_sec_0[3468]\.sh' \
  .github .pre-commit-config.yaml .guardrails.yml 2>/dev/null || true
```

## Code examples

### Before

```yaml
# .guardrails.yml
checks:
  CICD-SEC-03:
    mode: warn
  CICD-SEC-06:
    mode: off
```

```yaml
# .pre-commit-config.yaml
hooks:
  - id: cicd-sec-03
  - id: cicd-sec-08
```

### After

```yaml
# .guardrails.yml
checks:
  CICD-SEC-03-DEPENDENCY-CHAIN:
    mode: warn
  CICD-SEC-06-SECRET-SCAN:
    mode: off
```

```yaml
# .pre-commit-config.yaml
hooks:
  - id: cicd-sec-03-dependency-chain
  - id: cicd-sec-08-action-pinning
```
