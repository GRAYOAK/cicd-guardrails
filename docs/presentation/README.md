# Interne Präsentation — cicd-guardrails

Kurz-Outline für **Onboarding bei Grayoak** (kein Sales-Pitch). Live-Ablauf: [demo-script.md](demo-script.md).

**Stand-Snapshot:** `origin/dev` = [`dc65e0bdb640227bd8e3eb9db03ab5f6fe5a4502`](https://github.com/GRAYOAK/cicd-guardrails/commit/dc65e0bdb640227bd8e3eb9db03ab5f6fe5a4502) (`dc65e0b`, 2026-08-31). Das release-please-Manifest auf diesem Commit ist **`0.4.0`**. Gezeigtes Produkt ≠ released 0.6. Folie bei Bedarf an den aktuellen `dev`-HEAD anpassen.

Vier Blöcke: [Ziel](#1-ziel) · [Stand](#2-stand) · [Nutzung](#3-benutzen--einstellen) · [Melden](#4-probleme-melden).

---

## 1) Ziel

Wiederverwendbare CI/CD-Sicherheitsprüfungen als GitHub Actions ([`.github/workflows/full-scan.yml`](../../.github/workflows/full-scan.yml)), pre-commit ([`.pre-commit-hooks.yaml`](../../.pre-commit-hooks.yaml)) und Shell unter [`scripts/checks/domain/`](../../scripts/checks/domain/). Orientierung: [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/).

**Geliefert** sind die neun Designations in der [README-Check-Tabelle](../../README.md#was-wird-geprüft) (`CICD-SEC-01-FLOW` … `CICD-SEC-08-ACTION-PINNING`). **Nicht** im Produkt: SEC-02 / 09 / 10. **Kein** App-SAST/DAST.

Die **Implementierung** liegt nur in `cicd-guardrails`. **Geprüft** wird immer ein **Ziel-Repository**. Consumer pinnen eine feste Version; sie kopieren die Check-Skripte nicht ins Ziel-Repo.

**Pin (essentiell):** dieselbe **40-Zeichen-Commit-SHA** für Clone, `uses: …/full-scan.yml@<SHA>` und pre-commit `rev`. Nie `@main`, `@master` oder bewegliche Tags als einzige Referenz. CI und pre-commit im Ziel-Repo teilen denselben Pin.

Publikum: intern / Onboarding — Leute, die Guardrails in Ziel-Repos pinnen. Keine Engine-Internals als Hauptthema.

---

## 2) Stand

Ampel: **grün** = auf `origin/dev` (`dc65e0b`); **gelb** = offene Issues oder bekanntes Demo-Caveat. Offene Tickets nicht als „Produkt fehlt“ erzählen.

| Bereich | Ampel | Beleg |
|---|---|---|
| Domain-Checks / OWASP-Mapping | **Grün** | README-Tabelle; Job-IDs `cicd-sec-01-flow` … `cicd-sec-08-action-pinning` |
| JS/TS-Policy SEC-03 | **Grün** | [PR #11](https://github.com/GRAYOAK/cicd-guardrails/pull/11) (`c1ce141`) |
| Full-Scan-Performance | **Grün** | [PR #12](https://github.com/GRAYOAK/cicd-guardrails/pull/12) (`54d8816`) |
| SEC-03-Engine (Inventur, Toggles, YAML + Named Validators, Dart) | **Grün** | [#14](https://github.com/GRAYOAK/cicd-guardrails/issues/14)/[#19](https://github.com/GRAYOAK/cicd-guardrails/pull/19), [#16](https://github.com/GRAYOAK/cicd-guardrails/issues/16)/[#20](https://github.com/GRAYOAK/cicd-guardrails/pull/20), [#15](https://github.com/GRAYOAK/cicd-guardrails/issues/15)+[#17](https://github.com/GRAYOAK/cicd-guardrails/issues/17)/[#21](https://github.com/GRAYOAK/cicd-guardrails/pull/21), [#18](https://github.com/GRAYOAK/cicd-guardrails/issues/18)/[#25](https://github.com/GRAYOAK/cicd-guardrails/pull/25) (`9802b5a`) |
| CI reusable `full-scan.yml` | **Grün** | Kurze Job-Namen inkl. `risk-summary`; Inputs `guardrails-repository` / `guardrails-ref` (40-Zeichen-SHA, **required**) |
| pre-commit | **Grün** | Producer-Hook-IDs: `cicd-sec-04-poisoned-pipeline`, `cicd-sec-08-action-pinning`, `cicd-sec-05-permissions`, `cicd-sec-05-runner-access`, `cicd-sec-07-runner-hardening`, `cicd-sec-03-dependency-chain`, `cicd-sec-06-secret-scan` (`stages: [manual]`) |
| Lokal | **Grün** | `bash scripts/checks/domain/cicd_sec_*.sh <repo-root>` |
| Demos well / errors | **Grün** | [#10](https://github.com/GRAYOAK/cicd-guardrails/issues/10) zu, Producer [#26](https://github.com/GRAYOAK/cicd-guardrails/pull/26); [`cicd-guardrails-demo-well`](https://github.com/GRAYOAK/cicd-guardrails-demo-well), [`cicd-guardrails-demo-errors`](https://github.com/GRAYOAK/cicd-guardrails-demo-errors); `task test:demos` |
| Config `.guardrails.yml` | **Grün** | Context, `checks.*.mode`, SEC-03 `ecosystems` |
| Epic Engine Follow-ups | **Gelb** | [#13](https://github.com/GRAYOAK/cicd-guardrails/issues/13) offen; Proof auf `dev`; Rest [#23](https://github.com/GRAYOAK/cicd-guardrails/issues/23) (Dart-Lock-Heuristik), [#24](https://github.com/GRAYOAK/cicd-guardrails/issues/24) (Allowlist/Coverage aus YAML) |
| Check-Namen in GitHub-UI | **Gelb** | [#22](https://github.com/GRAYOAK/cicd-guardrails/issues/22): kurze Called-Job-Namen (`01-flow` … `08-action-pinning`) vorbereitet; bleibt gelb bis Merge und Consumer-Migration |
| Demo well FLOW/BRANCH in CI | **Gelb** | well `main` ohne `admin-token`; Token-Verdrahtung = well [PR #2](https://github.com/GRAYOAK/cicd-guardrails-demo-well/pull/2) (Secrets/Protection, **nicht** dieses Doc) |

Demo-Pin auf well/errors `main` (Stand dieses Snapshots): `9802b5afffeb9e9097a2c73eae480ed62eab76be` (`9802b5a`). Das ist **nicht** `dev`-HEAD (`dc65e0b`, Harness/Docs). Für Check-Verhalten den **Demo-Pin** nutzen; für „was ist das Produkt“ `origin/dev`.

---

## 3) Benutzen & einstellen

Quellen: [README Quick Start](../../README.md#quick-start), [AGENTS.md](../../AGENTS.md), [migrations/README.md](../../migrations/README.md), [`.guardrails.example.yml`](../../.guardrails.example.yml). In der Live-Demo `GRAYOAK` statt `YOUR_ORG`.

SHA ermitteln und Clone auf denselben Pin wie CI/pre-commit:

```bash
git ls-remote https://github.com/GRAYOAK/cicd-guardrails HEAD
git checkout <SHA>
```

**Voraussetzungen:** `bash`; `yq` empfohlen (mehrere Checks und `.guardrails.yml`); `CICD-SEC-06-SECRET-SCAN` braucht `gitleaks` und `jq`; API-Checks (`CICD-SEC-01-FLOW`, `CICD-SEC-05-BRANCH`) brauchen `GH_TOKEN` und `GITHUB_REPOSITORY`. Lokal: `brew install yq`. Fehlt `yq`, fallen Werte auf konservative Defaults (`mode=fail`).

### Lokal (ein Check gegen das Ziel-Repo)

Pfad = Repository-Root des Ziels. README-Beispiele:

```bash
bash scripts/checks/domain/cicd_sec_04_poisoned_pipeline.sh /pfad/zum/ziel-repo
bash scripts/checks/domain/cicd_sec_03_dependency_chain.sh /pfad/zum/ziel-repo
```

API-Checks nur mit Token:

```bash
GH_TOKEN=<token> GITHUB_REPOSITORY=owner/repo \
  bash scripts/checks/domain/cicd_sec_01_flow.sh /pfad/zum/ziel-repo
GH_TOKEN=<token> GITHUB_REPOSITORY=owner/repo \
  bash scripts/checks/domain/cicd_sec_05_branch.sh /pfad/zum/ziel-repo
```

SEC-06 erwartet lokal oft `./gitleaks` im **cwd** (der Harness `tests/test_demo_repos.sh` verlinkt das).

### CI (GitHub Actions)

README-Minimal (Platzhalter):

```yaml
uses: YOUR_ORG/cicd-guardrails/.github/workflows/full-scan.yml@<SHA>
with:
  strict: true
```

**Laufende Caller-Wahrheit** (Demos auf `main`): `full-scan.yml` auf `dev` verlangt **required** `guardrails-repository` und `guardrails-ref` (40-Zeichen-SHA). Siehe [migrations/v0.3.2.md](../../migrations/v0.3.2.md) und [demo-well `security.yml`](https://github.com/GRAYOAK/cicd-guardrails-demo-well/blob/main/.github/workflows/security.yml):

```yaml
name: scan
uses: GRAYOAK/cicd-guardrails/.github/workflows/full-scan.yml@9802b5afffeb9e9097a2c73eae480ed62eab76be
with:
  guardrails-repository: GRAYOAK/cicd-guardrails
  guardrails-ref: 9802b5afffeb9e9097a2c73eae480ed62eab76be
  strict: true
```

Ohne Admin-Token laufen dateibasierte Checks; `cicd-sec-01-flow` und `cicd-sec-05-branch` können eingeschränkt oder übersprungen sein.

### pre-commit

Im Ziel-Repo `.pre-commit-config.yaml`: `rev` = **dieselbe SHA** wie `full-scan.yml@SHA`. Producer-Hook-IDs wie README. Beispiel: [demo-well `.pre-commit-config.yaml`](https://github.com/GRAYOAK/cicd-guardrails-demo-well/blob/main/.pre-commit-config.yaml). Demo-`main` kann noch **Legacy-IDs** (`cicd-sec-04`, `cicd-sec-03`, …) haben — Parität gilt für die SHA, nicht für den ID-String in der Live-Minute.

### Maintainer / Demos

```bash
task test          # bash tests/test_checks.sh
task test:demos    # bash tests/test_demo_repos.sh
```

Geschwisterpfade `../cicd-guardrails-demo-well` und `../cicd-guardrails-demo-errors`, Override `GUARDRAILS_DEMO_WELL_PATH` / `GUARDRAILS_DEMO_ERRORS_PATH`. Der Harness **skippt** FLOW/BRANCH. well: file-based Exit **0**; errors insgesamt **≠ 0** (SEC-03 reicht). Exit **2** = Infra (`yq`/`gitleaks`/`jq`), kein erwartetes errors-Rot. **Nicht** Required-Check auf Producer-PRs.

Branch Protection Required-Checks (exakt README), z. B. `scan / 04-poisoned-pipeline` und `scan / 01-flow` (FLOW/BRANCH nur mit Admin-Token sinnvoll).

---

## 4) Probleme melden

**Neues Issue:** [https://github.com/GRAYOAK/cicd-guardrails/issues/new](https://github.com/GRAYOAK/cicd-guardrails/issues/new)

Mitgeben:

- Ziel-Repo `owner/name`
- gepinnte **40-Zeichen-SHA**
- Weg: CI / pre-commit / lokales Skript
- Check-ID (`CICD-SEC-08-ACTION-PINNING` oder Job-ID `cicd-sec-08-action-pinning`)
- erwartet vs. tatsächlich
- Logs **ohne** Secrets/Tokens

Labels: Bug vs. Enhancement vs. Documentation.

Unterscheiden: False Positive im Ziel-Repo vs. Bug in Guardrails vs. Docs-Lücke.

Integration (Maintainer): Feature-Branch von `dev` → PR nach `dev` ([AGENTS.md](../../AGENTS.md)). Issues schließen über `dev` oft **nicht** automatisch (Default-Branch `main`).
