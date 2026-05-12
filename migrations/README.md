# Migration Notes

This directory holds **per-version migration notes** for consumer repositories
(both human operators and automated agents).

## Layout

```
migrations/
  README.md              # this file
  TEMPLATE.md            # snippet template; copy when adding a new entry
  .unreleased/           # PR-time snippets that have not been released yet
    <pr-slug>.md
  v0.1.0.md              # consolidated notes for tag v0.1.0
  v0.2.0.md
  ...
```

## Lifecycle

1. While preparing a change in a feature branch, the author runs:
   ```bash
   cp migrations/TEMPLATE.md migrations/.unreleased/<short-pr-slug>.md
   ```
   and fills in the placeholders.

2. The `migration-guard` workflow enforces that every commit carrying a
   `BREAKING CHANGE:` footer or a `feat!:` / `fix!:` type also adds a snippet
   under `.unreleased/`.

3. When release-please cuts a new release on `main`, the `release.yml`
   workflow consolidates every `.unreleased/*.md` into a single
   `migrations/v<X.Y.Z>.md`, removes the snippets, commits the result back to
   `main`, and uploads the file as a GitHub Release asset together with
   `CHANGELOG.md`.

## Contract for consumers (including AI agents)

For any release `vX.Y.Z`, the file `migrations/v<X.Y.Z>.md` exists and is the
single source of truth for migration steps from the previous version. The
front-matter block is stable and machine-parseable:

```yaml
version: X.Y.Z
previous_version: X.Y.W
released_at: 2026-01-31T12:00:00Z
severity: none|see-snippets
```

When `severity: none`, no migration is required. Otherwise each `## Change:`
section carries its own snippet with structured `What changed`, `Required
action`, `Detection`, and `Code examples` headings. Agents should parse those
sections deterministically rather than relying on prose.

## Why a separate file from CHANGELOG.md

`CHANGELOG.md` is a human-oriented log of what changed. The migration file is
an action-oriented playbook for the next release. Keeping them separate avoids
mixing narrative entries with executable upgrade steps and keeps the migration
file small enough for an agent to read in one pass.
