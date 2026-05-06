# Learnings

## Learning proposal protocol (mandatory)

At the end of every task, always output a compact `Learning proposals` section.
Do not ask one generic yes/no question for all learnings.
Instead, provide individually selectable items so the user can decide per learning.

Rules:
- Include only generally useful learnings, not incident-specific details.
- Compress each learning to one reusable rule in one sentence.
- Keep each item actionable and stable over time.
- Group by type when useful: behavior, storage location, stable rule.
- Maximum 5 items unless the user explicitly asks for more.
- If there are no solid learnings, explicitly output: `No learning proposals.`

Required output format:

```text
Learning proposals
1) [Type: behavior] <generalized rule>
   Apply to skill? (yes/no)
2) [Type: stable-rule] <generalized rule>
   Apply to skill? (yes/no)
```

Optional shorthand format for quick confirmation:

```text
Reply format: 1=yes, 2=no, 3=yes
```

## Accepted learnings

- Prefer passing GitHub App credentials into the reusable workflow and mint short-lived tokens inside relevant called jobs to avoid cross-job secret output warnings and fragile token propagation.
- When fixing workflow runtime deprecations, update producer and consumer wiring together so compatibility, secret contracts, and documentation remain aligned.
- For branch-policy checks, keep deterministic token precedence: explicit admin token first, then in-job GitHub App token, then repository default token.
