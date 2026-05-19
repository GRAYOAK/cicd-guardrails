# Agent guide — cicd-guardrails

This repository ships OWASP CI/CD security checks as bash scripts and a reusable GitHub Actions workflow. Read this file before changing checks, workflows, or release-related files.

## Branch and release policy (mandatory)

### Integration branch: `dev`

- **Push only to `dev`** (or feature branches opened from `dev`).
- **Never push directly to `main`** and never force-push protected branches.
- Land changes on `main` **only via pull request** (typically `dev` → `main`).

### Releases: release-please on `main`

This project uses **[release-please](https://github.com/googleapis/release-please)** (see `.github/workflows/release.yml`, `release-please-config.json`, `.release-please-manifest.json`).

| Step | What happens |
|------|----------------|
| Conventional Commits merge to `main` | release-please opens or updates a **Release PR** (version bump + `CHANGELOG.md`) |
| Release PR merges | GitHub Release `vX.Y.Z`, git tag `vX.Y.Z`, migration assembly job runs |
| After cut | `migrations/vX.Y.Z.md` + `CHANGELOG.md` attached to the release; consumers pin the **40-char commit SHA** of that tag |

**Do not hand-edit `CHANGELOG.md`** when the file header says it is owned by release-please. Ship user-visible history via **Conventional Commits** (`feat:`, `fix:`, `perf:`, `docs:`, …).

**Breaking changes** (`feat!:`, `fix!:`, or `BREAKING CHANGE:` footer): add at least one snippet under `migrations/.unreleased/<slug>.md` (from `migrations/TEMPLATE.md`). The `migration-guard` workflow enforces this on PRs targeting `main`.

Skill-only edits under `.agents/skills/go-adjust-cicd-guardrails/` with no script/workflow changes: prefer `docs(skill):` or `chore(skill):`; skip new `.unreleased` snippets unless consumers are affected.

## Check naming: OWASP number + purpose slug

Every check uses four aligned layers. The purpose slug answers *what* the check does, not only the OWASP family number.

| Purpose slug | `FB_CHECK_ID` | Script | Job ID |
|--------------|---------------|--------|--------|
| `flow` | `CICD-SEC-01-FLOW` | `cicd_sec_01_flow.sh` | `cicd-sec-01-flow` |
| `dependency_chain` | `CICD-SEC-03-DEPENDENCY-CHAIN` | `cicd_sec_03_dependency_chain.sh` | `cicd-sec-03-dependency-chain` |
| `poisoned_pipeline` | `CICD-SEC-04-POISONED-PIPELINE` | `cicd_sec_04_poisoned_pipeline.sh` | `cicd-sec-04-poisoned-pipeline` |
| `permissions` | `CICD-SEC-05-PERMISSIONS` | `cicd_sec_05_permissions.sh` | `cicd-sec-05-permissions` |
| `branch` | `CICD-SEC-05-BRANCH` | `cicd_sec_05_branch.sh` | `cicd-sec-05-branch` |
| `runner_access` | `CICD-SEC-05-RUNNER-ACCESS` | `cicd_sec_05_runner_access.sh` | `cicd-sec-05-runner-access` |
| `secret_scan` | `CICD-SEC-06-SECRET-SCAN` | `cicd_sec_06_secret_scan.sh` | `cicd-sec-06-secret-scan` |
| `runner_hardening` | `CICD-SEC-07-RUNNER-HARDENING` | `cicd_sec_07_runner_hardening.sh` | `cicd-sec-07-runner-hardening` |
| `action_pinning` | `CICD-SEC-08-ACTION-PINNING` | `cicd_sec_08_action_pinning.sh` | `cicd-sec-08-action-pinning` |

Rules:

- Filename: `cicd_sec_<NN>_<purpose_slug>.sh` (snake_case).
- Never add a bare `cicd_sec_<NN>.sh` without a purpose slug.
- `FB_CHECK_ID` uses UPPER kebab: `CICD-SEC-03-DEPENDENCY-CHAIN`.
- Legacy `.guardrails.yml` keys (`CICD-SEC-03`, …) are resolved at runtime for one release via `scripts/lib/config.sh`; prefer new keys in consumer repos.

## Typical contributor flow

```text
feature branch (from dev) → push → PR into dev
dev (integrated)          → PR into main  (Conventional Commits)
main                      → release-please Release PR → merge → tag vX.Y.Z
```

## Repository map (entry points)

### Workflows (`.github/workflows/`)

| File | Role |
|------|------|
| `full-scan.yml` | **Reusable orchestrator** — consumer repos call `uses: …/full-scan.yml@<40-char-SHA>` |
| `self-test.yml` | Dogfooding: unit tests + selected checks on this repo |
| `release.yml` | release-please + migration assembly + optional demo-repo dispatch |
| `migration-guard.yml` | Fails PRs to `main` with breaking commits but no `.unreleased` snippet |

### Domain checks (run locally against a repo root)

```bash
bash scripts/checks/domain/cicd_sec_03_dependency_chain.sh <repo-root>
bash scripts/checks/domain/cicd_sec_04_poisoned_pipeline.sh <repo-root>
# … see README check table for all designations
```

### Shared libraries (`scripts/lib/`)

| Module | Purpose |
|--------|---------|
| `feedback.sh` | Reporting, modes, summary blocks |
| `config.sh` | Reads `.guardrails.yml` (context + per-check `mode`) |
| `file_patterns.sh` | `find` helpers, exclude overlays |
| `package_policy.sh` | Python policy merge |
| `action_pin_audit.sh` / `dockerfile_pin_audit.sh` | Pinning audits |

### Tests

```bash
bash tests/test_checks.sh
```

### Configuration

| File | Purpose |
|------|---------|
| `.guardrails.yml` | Per-repo context + check severity overrides |
| `.guardrails.schema.json` | JSON schema |
| `.pre-commit-hooks.yaml` | Local hooks mirroring selected checks |

## Deeper agent skill

For non-trivial changes to checks or workflows, follow `.agents/skills/go-adjust-cicd-guardrails/SKILL.md`.

## Human-oriented docs

- `README.md` — integration, pinning, check table
- `CHANGELOG.md` — release-please output (do not edit manually)
