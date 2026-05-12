# Reference Risk Model

## Risk summary and context model

When adjusting risk prioritization:
- Read context from target repo `.guardrails.yml` via `scripts/lib/config.sh` only; do not duplicate yq parsing in other scripts.
- Treat `.guardrails.yml` as source of truth.
- Treat `.guardrails.schema.json` as the authoritative list of allowed context values and per-check override keys.
- Keep `.guardrails.example.yml` aligned with the schema and README examples.
- Keep missing-config behavior explicit and safe (conservative defaults; missing yq → defaults; unknown override mode → `fail`).
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
  container_registry: public      # public | private_network
  data_sensitivity: high          # low | medium | high
  deployment_criticality: prod    # dev | prod | regulated

checks:                           # optional, per-check severity override
  CICD-SEC-08:
    mode: warn                    # fail (default) | warn | off
```

Allowed values are maintained in:
- `.guardrails.schema.json` (reference for valid values and IDE validation)
- `.guardrails.example.yml` (starter config for consumers)

Do not reintroduce `.guardrails.schema.yml`; JSON schema is the canonical format.

## Per-check severity override pattern

The `checks:` block lets a target repository tune severity per check without changing the caller's `strict` input. Keys are OWASP designations (matching `FB_CHECK_ID`); modes are `fail`, `warn`, `off`.

Implementation rules:
- Override application lives in `scripts/lib/feedback.sh` (`fb_set_mode`, `fb_apply_check_mode`); each check only calls `cfg_init` + `fb_set_mode "$(cfg_check_mode "$FB_CHECK_ID")"` right after `fb_init`.
- `fb_summary` applies the mode automatically before rendering, so every exit path (early SKIPPED, missing runtime, normal flow) honors the override without scattered conditionals.
- `fb_exit_code`: `mode=off` forces exit 0 even when runtime dependencies are missing (full deactivation); `mode=warn` returns exit 0 for findings but keeps exit 2 on missing runtime so infrastructure issues are still surfaced.
- JSON artifacts include the mode (`"mode": "warn"`); the aggregator surfaces a softened-mode note in the executive snapshot when at least one result has a non-`fail` mode.
- Score weighting is reused: `mode=warn` produces `WARN` status (60% weight), `mode=off` produces `SKIPPED` (0% weight). No additional scoring branches are needed.
- `skip-checks` (workflow input) and `mode: off` are complementary, not equivalent: the former skips the whole job at the caller level; the latter runs the check, records SKIPPED status, and keeps annotations in logs for traceability.

When adding a new check, register its designation as a property in the schema's `checks` block so IDE validation accepts overrides for it.
