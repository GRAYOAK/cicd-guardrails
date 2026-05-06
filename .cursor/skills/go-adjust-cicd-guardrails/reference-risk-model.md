# Reference Risk Model

## Risk summary and context model

When adjusting risk prioritization:
- Read context from target repo `.guardrails.yml`.
- Treat `.guardrails.yml` as source of truth.
- Treat `.guardrails.schema.json` as the authoritative list of allowed context values.
- Keep `.guardrails.example.yml` aligned with the schema and README examples.
- Keep missing-config behavior explicit and safe (conservative defaults).
- Keep scoring transparent in final summary (context fields + score rationale).
- Prefer severity-grouped presentation over flat score-only ordering for faster triage.
- Keep each finding block structurally consistent with concise fields:
  - `Problem`
  - `Exploit path`
  - `Impact`
  - `Fix first`
- Describe exploitability in operational terms to improve fix prioritization.
- Use short labeled markdown links for references instead of raw URLs.
- Keep context/scoring visibility compact so findings remain the visual focus.
- Add or update summary-format assertions in tests whenever report structure changes.
- Keep README summary examples aligned with the current runtime output format.
- Keep schema linkage explicit in consumer config using:
  - `# yaml-language-server: $schema=https://raw.githubusercontent.com/Christopher-Rust/cicd-guardrails/main/.guardrails.schema.json`

## Expected `.guardrails.yml` fields

```yaml
context:
  visibility: public              # public | private | internal
  software_type: open_source      # open_source | private_software
  runner_type: self_hosted        # self_hosted | github_hosted
  data_sensitivity: high          # low | medium | high
  deployment_criticality: prod    # dev | prod | regulated
```

Allowed values are maintained in:
- `.guardrails.schema.json` (reference for valid values and IDE validation)
- `.guardrails.example.yml` (starter config for consumers)

Do not reintroduce `.guardrails.schema.yml`; JSON schema is the canonical format.
