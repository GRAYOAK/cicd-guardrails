# Learnings

## Learning proposal protocol (mandatory)

At the end of every task, always output a compact `Lernvorschlaege` section in German.
Do not ask one generic yes/no question for all learnings.
Instead, provide individually selectable items so the user can decide per learning.

Rules:
- Include only generally useful learnings, not incident-specific details.
- Compress each learning to one reusable rule in one sentence.
- Keep each item actionable and stable over time.
- Group by type when useful: behavior, storage location, stable rule.
- Maximum 5 items unless the user explicitly asks for more.
- If there are no solid learnings, explicitly output: `Keine Lernvorschlaege.`

Required output format:

```text
Lernvorschlaege
1) [Typ: Verhalten] <verallgemeinerte Regel>
   In Skill uebernehmen? (ja/nein)
2) [Typ: Stabile-Regel] <verallgemeinerte Regel>
   In Skill uebernehmen? (ja/nein)
```

Optional shorthand format for quick confirmation:

```text
Antwortformat: 1=ja, 2=nein, 3=ja
```

## Accepted learnings

- Prefer passing GitHub App credentials into the reusable workflow and mint short-lived tokens inside relevant called jobs to avoid cross-job secret output warnings and fragile token propagation.
- When fixing workflow runtime deprecations, update producer and consumer wiring together so compatibility, secret contracts, and documentation remain aligned.
- For branch-policy checks, keep deterministic token precedence: explicit admin token first, then in-job GitHub App token, then repository default token.
- For domain checks that read repository-level policy context, always checkout the caller repository to a stable `target` path in the reusable workflow job and pass that path into the check script.
- In risk aggregation pattern matching, place specific designation clauses before generic family catch-alls so scoring and explanation logic remain deterministic as new sub-designations are added.
- Validate remote-derived workflow SHAs with a strict 40-character hexadecimal check before automation rewrites pinned workflow references.
- Keep positive and negative fixture repositories pinned to the same reusable-workflow revision to detect regressions and false positives consistently.
- Separate local verification into file-based checks and API-context checks, and document required token and policy prerequisites explicitly.
