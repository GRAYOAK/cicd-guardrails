---
target_version: NEXT
since_version: any
severity: breaking
category: script|config
affected_consumers: [reusable-workflow, pre-commit, cli]
---

## What changed

CICD-SEC-03 no longer validates Python dependencies only through isolated per-file hooks. Python is evaluated per directory using a shipped default policy file plus optional `package_policy.python` overrides in `.guardrails.file-patterns.yml`. Trigger files, satisfier lock or requirements files, whitelisted multi-trigger combinations, and per-file hash validators are configurable. Pip-style requirements files must use pip hash lines for pinned entries; Poetry and uv lockfiles must show integrity metadata per package block.

## Why

Supply-chain pinning is easier to reason about when discovery, satisfier presence, ambiguity rules, and hash checks share one explicit policy model that consumer repositories can narrow or extend without forking check scripts.

## Required action for consumer repositories

- Add `validation_skip_paths` entries for directories that contain a `pyproject.toml` or other trigger files but are not installable Python projects.
- Ensure each Python project directory has at least one configured satisfier file with valid hashes (see defaults under `scripts/config/package_policy.defaults.yml` in cicd-guardrails).
- If multiple trigger files intentionally live beside each other, extend `allowed_trigger_combinations` in `package_policy.python` so the exact basename set matches one allowed group.
- Regenerate `requirements*.txt` with hash output (for example pip-compile with hash generation) where those files are satisfiers.

## Detection

```bash
bash guardrails/scripts/checks/domain/cicd_sec_03.sh /path/to/repo 2>&1 | rg 'Python project directory|Ambiguous Python|pip --hash|poetry.lock|uv.lock'
```

## Code examples

### Before

```text
# pyproject.toml only; only poetry.lock or uv.lock was required next to it.
# requirements*.txt were checked for == pins without mandatory hashes.
```

### After

```yaml
# .guardrails.file-patterns.yml (optional)
validation_skip_paths:
  - "tools/no-deps-pyproject/**"
# package_policy:
#   python:
#     triggers: [...]
```
