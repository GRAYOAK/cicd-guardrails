---
target_version: NEXT
since_version: any
severity: additive
category: config
affected_consumers: [reusable-workflow, pre-commit, cli]
---

## What changed

`CICD-SEC-03-DEPENDENCY-CHAIN` now accepts optional `ecosystems.<id>: fail|off` gates for JavaScript, Python, Go, Rust, Ruby, and PHP, plus `unsupported_ecosystems: notice|off`. Omitted settings preserve the existing audits and unsupported-ecosystem notices.

## Why

Repositories can disable an inapplicable language policy without disabling SEC-03 inventory, workflow action pinning, Dockerfile digest checks, or other detected language audits.

## Required action for consumer repos

No action is required. Add only the switches needed by the repository; all defaults preserve previous behavior.

## Detection

```bash
bash scripts/checks/domain/cicd_sec_03_dependency_chain.sh /path/to/consumer-repo
```

## Code examples

### Before

```yaml
checks:
  CICD-SEC-03-DEPENDENCY-CHAIN:
    mode: fail
```

### After

```yaml
checks:
  CICD-SEC-03-DEPENDENCY-CHAIN:
    mode: fail
    ecosystems:
      go: off
    unsupported_ecosystems: off
```
