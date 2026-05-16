# Reusable workflow: explicit guardrails-repository and guardrails-ref inputs

## Who is affected

All consumer repositories that call `full-scan.yml` via cross-repo `workflow_call`.

## What changed

`full-scan.yml` requires two new inputs on every caller:

- `guardrails-repository` — e.g. `GRAYOAK/cicd-guardrails`
- `guardrails-ref` — the same 40-character SHA as in `uses: ...@<SHA>`

Setup validates inputs, probes a shallow checkout, and fails fast if scripts are missing.
`GITHUB_WORKFLOW_REF` points at the **caller** workflow in cross-repo calls and must not be used for script checkout.

## Action required

Bump the pinned SHA and extend caller `security.yml`:

```yaml
uses: GRAYOAK/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
with:
  guardrails-repository: GRAYOAK/cicd-guardrails
  guardrails-ref: <SHA>
  strict: true
```

## Symptoms before fix

- Setup prints `Guardrails-Repository: axpogroup/<consumer>` and `Guardrails-Ref: refs/pull/<N>/merge`.
- `bash: guardrails/scripts/checks/domain/cicd_sec_03.sh: No such file or directory`.
