---
target_version: NEXT
since_version: "0.4.0"
severity: breaking
category: workflow
affected_consumers: [reusable-workflow, branch-protection]
---

## What changed

Reusable-workflow job display names are now short purpose slugs. GitHub composes the PR Checks label from the caller workflow name, caller job name, and called job name; removing decorative scope prefixes and long titles keeps the identifying slug visible.

Workflow job IDs and `skip-checks` tokens are unchanged.

## Display-name mapping

| Job ID | Previous display name | New display name |
|---|---|---|
| `setup` | `Setup` | `setup` |
| `summarize` | `📊 Risk summary` | `risk-summary` |
| `cicd-sec-01-flow` | `⚙️ Settings \| 🧭 01-flow — Flow control` | `01-flow` |
| `cicd-sec-03-dependency-chain` | `🧩 Code \| 🔒 03-dependency-chain — Dependency chain` | `03-dependency-chain` |
| `cicd-sec-04-poisoned-pipeline` | `🧩 Code \| 🚨 04-poisoned-pipeline — Poisoned pipeline` | `04-poisoned-pipeline` |
| `cicd-sec-05-permissions` | `🧩 Code \| 🔐 05-permissions — Workflow permissions` | `05-permissions` |
| `cicd-sec-05-branch` | `⚙️ Settings \| 🛂 05-branch — Branch governance` | `05-branch` |
| `cicd-sec-05-runner-access` | `🧩 Code \| 🖥️ 05-runner-access — Runner access` | `05-runner-access` |
| `cicd-sec-06-secret-scan` | `🧩 Code \| 🕵️ 06-secret-scan — Secret scanning` | `06-secret-scan` |
| `cicd-sec-07-runner-hardening` | `🧩 Code \| 🧱 07-runner-hardening — Runner hardening` | `07-runner-hardening` |
| `cicd-sec-08-action-pinning` | `🧩 Code \| 📌 08-action-pinning — Action SHA pinning` | `08-action-pinning` |

## Required action for consumer repos

1. Bump the reusable workflow pin to the release commit SHA.
2. Give the caller job a short stable name such as `name: scan`, or omit `name:` and keep its job ID stable.
3. Run the updated workflow once so GitHub registers the new check contexts.
4. Replace Branch Protection required checks with the new contexts. With `jobs.guardrails.name: scan`, select `scan / 01-flow`, `scan / 03-dependency-chain`, and the corresponding `scan / <purpose-slug>` entries listed in the README.
5. Remove the previous long required-check contexts only after the replacements are registered and required.

Do not rename workflow job IDs and do not change `skip-checks`; those interfaces are unaffected.
