---
target_version: NEXT
since_version: any
severity: breaking
category: script
affected_consumers: [reusable-workflow, pre-commit, cli]
---

## What changed

`CICD-SEC-03-DEPENDENCY-CHAIN` now detects project directories through exact `package.json`, `tsconfig.json`, and `jsconfig.json` basenames. A lone TypeScript or JavaScript config fails until `package.json` and one same-directory lockfile family exist; configured directories then receive the existing immutable-spec and lock-integrity checks once.

## Why

Config-only TypeScript and JavaScript directories previously escaped dependency validation. Detecting their standard project configs closes that gap, while exact basenames avoid treating specialized files such as `tsconfig.app.json` as separate projects.

## Required action for consumer repos

- Choose npm, Yarn, or pnpm for every `package.json` directory and keep exactly that lockfile beside the manifest.
- Add `package.json` and one supported lockfile beside every `tsconfig.json` or `jsconfig.json`, or remove configs that do not represent a project.
- If `.guardrails.file-patterns.yml` overrides `package_policy.javascript.allowed_trigger_combinations` (including the former default `[]`), remove that override to inherit the new defaults or replace it with the complete combinations your repository permits.
- Replace dependency ranges with exact versions and regenerate the lockfile with the selected package manager.

## Detection

```bash
bash scripts/checks/domain/cicd_sec_03_dependency_chain.sh /path/to/consumer-repo
```

## Code examples

### Before

```json
{"dependencies":{"lodash":"^4.17.21"}}
```

### After

```json
{"dependencies":{"lodash":"4.17.21"}}
```

Regenerate and commit exactly one same-directory lockfile:

```bash
npm install --package-lock-only
# or: yarn install
# or: pnpm install --lockfile-only
```
