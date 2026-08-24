---
target_version: NEXT
since_version: any
severity: breaking
category: script
affected_consumers: [reusable-workflow, pre-commit, cli]
---

## What changed

`CICD-SEC-03-DEPENDENCY-CHAIN` now fails JavaScript and TypeScript projects that use mutable dependency specs, have no same-directory lockfile, mix lockfile families, or lack package-manager integrity evidence.

## Why

Exact manifest specs and integrity-bearing npm, Yarn, or pnpm lockfiles make dependency resolution reproducible and reduce dependency-chain substitution risk.

## Required action for consumer repos

- Choose npm, Yarn, or pnpm for every `package.json` directory and keep exactly that lockfile beside the manifest.
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
